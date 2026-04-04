//! Real OpenVR IVROverlay implementation.
//!
//! Enabled only when the crate is built with `--features steamvr`.

use std::os::raw::{c_char, c_void};
use std::sync::{
    Mutex,
    atomic::{AtomicBool, Ordering},
};

use openvr_sys as sys;

use crate::vulkan;

// ─── Background frame-sync thread ───────────────────────────────────────────
//
// wayvr calls WaitFrameSync once per main loop iteration to keep the SteamVR
// compositor watchdog alive.  Because mixtape_vr drives its frame loop from
// Flutter timers (not a blocking render thread), we run WaitFrameSync in a
// dedicated background thread so SteamVR never sees a silent app.

static FRAME_SYNC_STOP: AtomicBool = AtomicBool::new(false);
static FRAME_SYNC_HANDLE: Mutex<Option<std::thread::JoinHandle<()>>> = Mutex::new(None);

fn start_frame_sync_thread() {
    FRAME_SYNC_STOP.store(false, Ordering::Relaxed);
    let handle = std::thread::Builder::new()
        .name("mvr-frame-sync".into())
        .spawn(|| {
            loop {
                if FRAME_SYNC_STOP.load(Ordering::Relaxed) {
                    break;
                }
                // WaitFrameSync blocks up to `nTimeoutMs` ms, then returns
                // regardless.  16 ms gives ~60 Hz – enough to satisfy the
                // watchdog without busy-spinning.
                unsafe {
                    let ot = overlay_table();
                    if !ot.is_null() {
                        if let Some(f) = (*ot).WaitFrameSync {
                            f(16);
                        }
                    } else {
                        std::thread::sleep(std::time::Duration::from_millis(16));
                    }
                }
            }
        });
    match handle {
        Ok(h) => *FRAME_SYNC_HANDLE.lock().unwrap() = Some(h),
        Err(e) => eprintln!("[mvr] start_frame_sync_thread: spawn failed: {}", e),
    }
}

fn stop_frame_sync_thread() {
    FRAME_SYNC_STOP.store(true, Ordering::Relaxed);
    if let Some(h) = FRAME_SYNC_HANDLE.lock().unwrap().take() {
        // Give the thread time to wake from WaitFrameSync and notice the flag.
        let _ = h.join();
    }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Return the IVROverlay function-pointer table via `VR_GetGenericInterface`.
#[inline]
unsafe fn overlay_table() -> *mut sys::VR_IVROverlay_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        b"FnTable:IVROverlay_028\0".as_ptr() as *const c_char,
        &mut err,
    );
    let ptr = iface as *mut sys::VR_IVROverlay_FnTable;
    if ptr.is_null() {
        eprintln!("[mvr] overlay_table: VR_GetGenericInterface returned null (err={})", err);
    }
    ptr
}

/// Return the IVRSystem function-pointer table via `VR_GetGenericInterface`.
#[inline]
unsafe fn system_table() -> *mut sys::VR_IVRSystem_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        b"FnTable:IVRSystem_022\0".as_ptr() as *const c_char,
        &mut err,
    );
    iface as *mut sys::VR_IVRSystem_FnTable
}

/// Return the IVRApplications function-pointer table.
#[inline]
unsafe fn applications_table() -> *mut sys::VR_IVRApplications_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        b"FnTable:IVRApplications_007\0".as_ptr() as *const c_char,
        &mut err,
    );
    iface as *mut sys::VR_IVRApplications_FnTable
}

/// Convert a raw 12-element `f32` slice (row-major 3×4) into `HmdMatrix34_t`.
unsafe fn to_hmd_matrix(matrix: *const f32) -> sys::HmdMatrix34_t {
    let s = std::slice::from_raw_parts(matrix, 12);
    sys::HmdMatrix34_t {
        m: [
            [s[0],  s[1],  s[2],  s[3]],
            [s[4],  s[5],  s[6],  s[7]],
            [s[8],  s[9],  s[10], s[11]],
        ],
    }
}

// ─── Right-wrist local transform ───────────────────────────────────────────
// Controller-space 3×4 row-major (m[row*4+col], translation in column 3).
// Derived from wayvr's WATCH_POS / WATCH_ROT but mirrored to the right hand:
//   WATCH_POS right = (0.03, -0.01, 0.125)
//   WATCH_ROT right (180° around axis (0.707, 0, 0.707)) = [[0,0,1],[0,-1,0],[1,0,0]]
const RIGHT_WRIST: [f32; 12] = [
    0.0,  0.0,  1.0,  0.03,
    0.0, -1.0,  0.0, -0.01,
    1.0,  0.0,  0.0,  0.125,
];

// ─── EVREventType constants not exposed as named consts in 2.x bindings ─────
const VR_EVENT_MOUSE_MOVE: u32 = 300;
const VR_EVENT_MOUSE_DOWN: u32 = 301;
const VR_EVENT_MOUSE_UP:   u32 = 302;
const VR_EVENT_QUIT:       u32 = 700;

// ─── Public surface ─────────────────────────────────────────────────────────

/// Register the app manifest with SteamVR so Mixtape appears in the SteamVR
/// overlay list and auto-launches on startup.
///
/// `manifest_path` must be the absolute path to `mixtape.vrmanifest`.
/// Safe to call repeatedly – SteamVR deduplicates by app key.
pub unsafe fn register_manifest(manifest_path: *const c_char) -> i32 {
    let at = applications_table();
    if at.is_null() { eprintln!("[mvr] register_manifest: applications_table is null"); return -1; }

    // IsApplicationInstalled: returns true if key already registered.
    const APP_KEY: &[u8] = b"steam.overlay.com.mixtape.vr\0";
    if let Some(is_installed) = (*at).IsApplicationInstalled {
        if is_installed(APP_KEY.as_ptr() as *mut _) {
            eprintln!("[mvr] register_manifest: already registered");
            return 0; // already registered
        }
    }

    if let Some(add_manifest) = (*at).AddApplicationManifest {
        let path_str = std::ffi::CStr::from_ptr(manifest_path).to_string_lossy();
        eprintln!("[mvr] register_manifest: adding manifest at '{}'", path_str);
        let err = add_manifest(manifest_path as *mut _, false);
        eprintln!("[mvr] register_manifest: AddApplicationManifest returned {}", err);
        return if err == 0 { 0 } else { err as i32 };
    }
    -1
}

/// Initialise OpenVR as an overlay application, then init the Vulkan device.
/// Returns 0 on success.
pub fn init() -> i32 {
    eprintln!("[mvr] init: calling VR_InitInternal");
    let mut err = sys::EVRInitError_VRInitError_None;
    unsafe {
        sys::VR_InitInternal(&mut err, sys::EVRApplicationType_VRApplication_Overlay);
    }
    if err != sys::EVRInitError_VRInitError_None {
        eprintln!("[mvr] init: failed with EVRInitError={}", err);
        return err as i32;
    }
    eprintln!("[mvr] init: OpenVR ready, initialising Vulkan");
    unsafe { vulkan::init(); }
    // Keep the SteamVR compositor watchdog alive with a background sync thread.
    start_frame_sync_thread();
    eprintln!("[mvr] init: frame-sync thread started");
    0
}

/// Shut down Vulkan device then OpenVR.
pub fn shutdown() {
    // Stop the watchdog thread before tearing down the VR session so the
    // thread cannot call WaitFrameSync on a dead context.
    stop_frame_sync_thread();
    vulkan::shutdown();
    unsafe { sys::VR_ShutdownInternal() }
}

/// Create an overlay identified by `key` / `name`.
pub unsafe fn create_overlay(
    key: *const c_char,
    name: *const c_char,
    out_handle: *mut u64,
) -> i32 {
    let key_str = std::ffi::CStr::from_ptr(key).to_string_lossy();
    let name_str = std::ffi::CStr::from_ptr(name).to_string_lossy();
    eprintln!("[mvr] create_overlay: key='{}' name='{}'", key_str, name_str);
    let ot = overlay_table();
    if ot.is_null() { eprintln!("[mvr] create_overlay: overlay_table is null"); return -1; }
    let create = match (*ot).CreateOverlay { Some(f) => f, None => { eprintln!("[mvr] create_overlay: CreateOverlay fn ptr is null"); return -1; } };
    let err = create(key as *mut _, name as *mut _, out_handle);
    if err == 0 {
        eprintln!("[mvr] create_overlay: success, handle={}", *out_handle);
        0
    } else {
        eprintln!("[mvr] create_overlay: failed with EVROverlayError={}", err);
        err as i32
    }
}

/// Submit a raw RGBA8 frame to the overlay.
///
/// Uses the Vulkan `SetOverlayTexture` path (same strategy as wayvr) when
/// Vulkan is available. Falls back to the CPU `SetOverlayRaw` path if Vulkan
/// initialisation failed at startup.
pub unsafe fn set_overlay_raw(handle: u64, rgba: *const u8, width: u32, height: u32) -> i32 {
    if vulkan::is_available() {
        return vulkan::submit_texture(handle, rgba, width, height, overlay_table());
    }
    // CPU fallback (no Vulkan)
    let ot = overlay_table();
    if ot.is_null() { return -1; }
    if let Some(f) = (*ot).SetOverlayRaw {
        let err = f(handle, rgba as *mut c_void, width, height, 4);
        if err != 0 {
            eprintln!("[mvr] set_overlay_raw (CPU fallback): EVROverlayError={}", err);
        }
        err as i32
    } else { -1 }
}

/// Set the overlay physical width in metres.
pub unsafe fn set_overlay_width_meters(handle: u64, meters: f32) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayWidthInMeters { f(handle, meters); }
}

/// Make the overlay visible.
pub unsafe fn show_overlay(handle: u64) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).ShowOverlay { f(handle); }
}

/// Anchor the overlay transform relative to a tracked device.
pub unsafe fn set_transform_tracked_device(handle: u64, device_index: u32, matrix: *const f32) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayTransformTrackedDeviceRelative {
        let mut m = to_hmd_matrix(matrix);
        f(handle, device_index, &mut m as *mut _);
    }
}

/// Disable input on this overlay so it never consumes controller laser events.
pub unsafe fn set_input_method_none(handle: u64) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayInputMethod {
        f(handle, sys::VROverlayInputMethod_None);
    }
}

/// Enable mouse input on this overlay.
///
/// Sets `SetOverlayInputMethod(Mouse)` so SteamVR generates `VREvent_MouseMove`,
/// `VREvent_MouseDown`, and `VREvent_MouseUp` events when the controller laser
/// intersects the overlay, then sets `SetOverlayMouseScale` so the event
/// coordinates span `[0..scale_x]` x `[0..scale_y]` (use pixel dimensions for
/// 1:1 screen coordinates, or `1.0 x 1.0` for normalised UV coords).
///
/// Call this after creating the overlay (or whenever the texture dimensions
/// change) so the Dart event-poll loop receives correctly-scaled coordinates.
pub unsafe fn set_input_method_mouse(handle: u64, scale_x: f32, scale_y: f32) {
    let ot = overlay_table();
    if ot.is_null() {
        eprintln!("[mvr] set_input_method_mouse: overlay_table is null");
        return;
    }
    if let Some(f) = (*ot).SetOverlayInputMethod {
        f(handle, sys::VROverlayInputMethod_Mouse);
    }
    // Clamp to a safe minimum so SteamVR doesn't receive a zero-scale.
    let sx = if scale_x > 0.0 { scale_x } else { 1.0 };
    let sy = if scale_y > 0.0 { scale_y } else { 1.0 };
    if let Some(f) = (*ot).SetOverlayMouseScale {
        let mut scale = sys::HmdVector2_t { v: [sx, sy] };
        f(handle, &mut scale as *mut _);
    }
}

/// Return the device index of the right-hand controller, or 0xFFFF_FFFF if
/// not currently tracked.
unsafe fn get_right_controller_index() -> u32 {
    let st = system_table();
    if st.is_null() { return 0xFFFF_FFFF; }
    if let Some(f) = (*st).GetTrackedDeviceIndexForControllerRole {
        return f(sys::ETrackedControllerRole_TrackedControllerRole_RightHand);
    }
    0xFFFF_FFFF
}

/// Attach the overlay to the user's right wrist using
/// `SetOverlayTransformTrackedDeviceRelative`.
///
/// Returns the device index on success, or -1 when the right controller is
/// not currently tracked.  Input mode is left unchanged so the caller can
/// decide whether to call `set_input_method_mouse` or `set_input_method_none`.
pub unsafe fn attach_to_right_wrist(handle: u64) -> i32 {
    let idx = get_right_controller_index();
    if idx == 0xFFFF_FFFF {
        eprintln!("[mvr] attach_to_right_wrist: right controller not tracked");
        return -1;
    }
    set_transform_tracked_device(handle, idx, RIGHT_WRIST.as_ptr());
    eprintln!("[mvr] attach_to_right_wrist: attached to device {}", idx);
    idx as i32
}

// ─── Event types returned to Dart ───────────────────────────────────────────
//  0 = hover/move
//  1 = mouse button down
//  2 = mouse button up

/// Drain one event from the overlay event queue.
/// Returns 1 if filled, 0 when empty.
pub unsafe fn poll_event(
    handle: u64,
    out_event_type: *mut u32,
    out_device_index: *mut u32,
    out_x: *mut f32,
    out_y: *mut f32,
) -> i32 {
    let ot = overlay_table();
    if ot.is_null() { return 0; }
    let poll = match (*ot).PollNextOverlayEvent { Some(f) => f, None => return 0 };

    let mut ev = std::mem::zeroed::<sys::VREvent_t>();
    let ev_size = std::mem::size_of::<sys::VREvent_t>() as u32;
    if !poll(handle, &mut ev, ev_size) { return 0; }

    let mapped_type: u32 = match ev.eventType {
        VR_EVENT_MOUSE_MOVE => 0,
        VR_EVENT_MOUSE_DOWN => 1,
        VR_EVENT_MOUSE_UP   => 2,
        _ => return 0,
    };

    *out_event_type   = mapped_type;
    *out_device_index = ev.trackedDeviceIndex;

    let mouse = ev.data.mouse;
    *out_x = mouse.x;
    *out_y = mouse.y;

    1
}

/// Poll the VRSystem event queue for a VREvent_Quit.
///
/// When a quit event is found:
///   - `AcknowledgeQuit_Exiting` is called so SteamVR knows we received it.
///   - Returns 1.
///
/// Returns 0 when no quit event is pending.
/// The Dart side should call `mvr_shutdown()` and `dart:io` exit after
/// receiving 1 so the process exits cleanly within SteamVR's 5-second window.
pub unsafe fn poll_should_quit() -> i32 {
    let st = system_table();
    if st.is_null() { return 0; }
    let poll = match (*st).PollNextEvent { Some(f) => f, None => return 0 };

    let mut ev = std::mem::zeroed::<sys::VREvent_t>();
    let ev_size = std::mem::size_of::<sys::VREvent_t>() as u32;
    loop {
        if !poll(&mut ev, ev_size) { return 0; }
        if ev.eventType == VR_EVENT_QUIT {
            // Acknowledge so SteamVR doesn't force-kill us.
            if let Some(ack) = (*st).AcknowledgeQuit_Exiting {
                ack();
            }
            return 1;
        }
    }
}
