//! Real OpenVR IVROverlay implementation.
//!
//! Enabled only when the crate is built with `--features steamvr`.

use std::os::raw::{c_char, c_void};

use openvr_sys as sys;

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Return the IVROverlay function-pointer table via `VR_GetGenericInterface`.
#[inline]
unsafe fn overlay_table() -> *mut sys::VR_IVROverlay_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        sys::IVROverlay_Version.as_ptr() as *const c_char,
        &mut err,
    );
    iface as *mut sys::VR_IVROverlay_FnTable
}

/// Return the IVRSystem function-pointer table.
#[inline]
unsafe fn system_table() -> *mut sys::VR_IVRSystem_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        sys::IVRSystem_Version.as_ptr() as *const c_char,
        &mut err,
    );
    iface as *mut sys::VR_IVRSystem_FnTable
}

/// Return the IVRApplications function-pointer table.
#[inline]
unsafe fn applications_table() -> *mut sys::VR_IVRApplications_FnTable {
    let mut err = sys::EVRInitError_VRInitError_None;
    let iface = sys::VR_GetGenericInterface(
        sys::IVRApplications_Version.as_ptr() as *const c_char,
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

/// Identity 3×4 matrix.
const IDENTITY: sys::HmdMatrix34_t = sys::HmdMatrix34_t {
    m: [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
    ],
};

// ─── EVREventType constants not exposed as named consts in 2.x bindings ─────
const VR_EVENT_BUTTON_PRESS:   u32 = 200;
const VR_EVENT_BUTTON_UNPRESS: u32 = 201;
const VR_EVENT_MOUSE_MOVE:     u32 = 300;
const VR_EVENT_MOUSE_DOWN:     u32 = 301;
const VR_EVENT_MOUSE_UP:       u32 = 302;

// k_EButton_Grip = 2
const K_BUTTON_GRIP: u32 = 1 << 2;

// ─── Public surface ─────────────────────────────────────────────────────────

/// Register the app manifest with SteamVR so Mixtape appears in the SteamVR
/// overlay list and auto-launches on startup.
///
/// `manifest_path` must be the absolute path to `mixtape.vrmanifest`.
/// Safe to call repeatedly – SteamVR deduplicates by app key.
pub unsafe fn register_manifest(manifest_path: *const c_char) -> i32 {
    let at = applications_table();
    if at.is_null() { return -1; }

    // IsApplicationInstalled: returns true if key already registered.
    const APP_KEY: &[u8] = b"steam.overlay.com.mixtape.vr\0";
    if let Some(is_installed) = (*at).IsApplicationInstalled {
        if is_installed(APP_KEY.as_ptr() as *mut _) {
            return 0; // already registered
        }
    }

    if let Some(add_manifest) = (*at).AddApplicationManifest {
        let err = add_manifest(manifest_path as *mut _, false);
        return if err == 0 { 0 } else { err as i32 };
    }
    -1
}

/// Initialise OpenVR as an overlay application. Returns 0 on success.
pub fn init() -> i32 {
    let mut err = sys::EVRInitError_VRInitError_None;
    unsafe {
        sys::VR_InitInternal(&mut err, sys::EVRApplicationType_VRApplication_Overlay);
    }
    if err == sys::EVRInitError_VRInitError_None { 0 } else { err as i32 }
}

/// Shut down OpenVR.
pub fn shutdown() {
    unsafe { sys::VR_ShutdownInternal() }
}

/// Create an overlay identified by `key` / `name`.
pub unsafe fn create_overlay(
    key: *const c_char,
    name: *const c_char,
    out_handle: *mut u64,
) -> i32 {
    let ot = overlay_table();
    if ot.is_null() { return -1; }
    let create = match (*ot).CreateOverlay { Some(f) => f, None => return -1 };
    let err = create(key as *mut _, name as *mut _, out_handle);
    if err == 0 { 0 } else { err as i32 }
}

/// Submit a raw RGBA8 CPU buffer as the overlay texture.
pub unsafe fn set_overlay_raw(handle: u64, rgba: *const u8, width: u32, height: u32) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayRaw {
        f(handle, rgba as *mut c_void, width, height, 4);
    }
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

/// Hide the overlay.
pub unsafe fn hide_overlay(handle: u64) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).HideOverlay { f(handle); }
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

/// Anchor the overlay to a controller at the identity offset (hand-held mode).
pub unsafe fn set_transform_controller_identity(handle: u64, device_index: u32) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayTransformTrackedDeviceRelative {
        let mut m = IDENTITY;
        f(handle, device_index, &mut m as *mut _);
    }
}

/// Enable laser-pointer mouse input for the overlay.
pub unsafe fn set_input_method_mouse(handle: u64) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayInputMethod {
        f(handle, sys::VROverlayInputMethod_Mouse);
    }
}

/// Disable pointer input (earbud mode – no interaction needed).
pub unsafe fn set_input_method_none(handle: u64) {
    let ot = overlay_table();
    if ot.is_null() { return; }
    if let Some(f) = (*ot).SetOverlayInputMethod {
        f(handle, sys::VROverlayInputMethod_None);
    }
}

/// Return the tracked device index of the left or right controller, or
/// `k_unTrackedDeviceIndexInvalid` (0xFFFFFFFF) if not tracked.
///
/// `hand`: 0 = left, 1 = right.
pub unsafe fn get_controller_index(hand: u32) -> u32 {
    let st = system_table();
    if st.is_null() { return sys::k_unTrackedDeviceIndexInvalid as u32; }
    let role = if hand == 0 {
        sys::ETrackedControllerRole_TrackedControllerRole_LeftHand
    } else {
        sys::ETrackedControllerRole_TrackedControllerRole_RightHand
    };
    if let Some(f) = (*st).GetTrackedDeviceIndexForControllerRole {
        f(role)
    } else {
        sys::k_unTrackedDeviceIndexInvalid as u32
    }
}

// ─── Event types returned to Dart ───────────────────────────────────────────
//  0 = hover/move
//  1 = button down (trigger / primary)
//  2 = button up
//  3 = grip pressed   ← NEW: earbud grabbed
//  4 = grip released  ← NEW: earbud dropped

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
        VR_EVENT_MOUSE_MOVE  => 0,
        VR_EVENT_MOUSE_DOWN  => 1,
        VR_EVENT_MOUSE_UP    => 2,
        VR_EVENT_BUTTON_PRESS => {
            // Only report grip button presses as grab events.
            let btn = ev.data.controller;
            if btn.button == K_BUTTON_GRIP { 3 } else { return 0; }
        }
        VR_EVENT_BUTTON_UNPRESS => {
            let btn = ev.data.controller;
            if btn.button == K_BUTTON_GRIP { 4 } else { return 0; }
        }
        _ => return 0,
    };

    *out_event_type   = mapped_type;
    *out_device_index = ev.trackedDeviceIndex;

    // Mouse events carry UV coords; grip events carry zero.
    let mouse = ev.data.mouse;
    *out_x = mouse.x;
    *out_y = mouse.y;

    1
}
