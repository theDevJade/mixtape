//! mixtape_vr – SteamVR overlay bridge for the Mixtape Flutter app.
//!
//! Exposes a flat C API (`mvr_*`) loaded by the Dart side via `dart:ffi`.
//! Build with `--features steamvr` on Windows / Linux for the real OpenVR
//! implementation. Without the feature, every function is a safe no-op stub
//! that returns -1 / 0 so the Dart code can detect "VR not available".

#![allow(clippy::missing_safety_doc)]

#[cfg(feature = "steamvr")]
mod vulkan;

#[cfg(feature = "steamvr")]
mod overlay;

// ─── C API ──────────────────────────────────────────────────────────────────

/// Initialise OpenVR as an overlay application.
///
/// Returns 0 on success, or an `EVRInitError` integer on failure (e.g. -1
/// when the `steamvr` feature is absent, or the SteamVR runtime is not
/// running).
#[no_mangle]
pub unsafe extern "C" fn mvr_init() -> i32 {
    #[cfg(feature = "steamvr")]
    return overlay::init();
    #[cfg(not(feature = "steamvr"))]
    -1
}

/// Shut down OpenVR and release all overlay handles.
#[no_mangle]
pub unsafe extern "C" fn mvr_shutdown() {
    #[cfg(feature = "steamvr")]
    overlay::shutdown();
}

/// Create a named overlay.
///
/// On success writes the handle into `*out_handle` and returns 0.
/// On failure returns a non-zero `EVROverlayError` code.
#[no_mangle]
#[allow(unused_variables)]
pub unsafe extern "C" fn mvr_create_overlay(
    key: *const std::os::raw::c_char,
    name: *const std::os::raw::c_char,
    out_handle: *mut u64,
) -> i32 {
    #[cfg(feature = "steamvr")]
    return overlay::create_overlay(key, name, out_handle);
    #[cfg(not(feature = "steamvr"))]
    return -1;
}

/// Submit a raw RGBA frame for the overlay (CPU buffer path).
///
/// `rgba` must point to `width * height * 4` bytes in RGBA8 order.
/// Returns 0 on success, or an `EVROverlayError` code on failure.
#[no_mangle]
pub unsafe extern "C" fn mvr_set_overlay_raw(
    handle: u64,
    rgba: *const u8,
    width: u32,
    height: u32,
) -> i32 {
    #[cfg(feature = "steamvr")]
    return overlay::set_overlay_raw(handle, rgba, width, height);
    #[cfg(not(feature = "steamvr"))]
    { let _ = (handle, rgba, width, height); -1 }
}

/// Set overlay physical width in metres (height is derived from the texture
/// aspect ratio by SteamVR).
#[no_mangle]
pub unsafe extern "C" fn mvr_set_overlay_width_meters(handle: u64, meters: f32) {
    #[cfg(feature = "steamvr")]
    overlay::set_overlay_width_meters(handle, meters);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, meters);
}

/// Make the overlay visible in the headset.
#[no_mangle]
pub unsafe extern "C" fn mvr_show_overlay(handle: u64) {
    #[cfg(feature = "steamvr")]
    overlay::show_overlay(handle);
    #[cfg(not(feature = "steamvr"))]
    let _ = handle;
}

/// Anchor the overlay to the HMD (device index 0) using the supplied 3x4
/// row-major transform matrix (12 `f32` values: 3 rows x 4 columns).
///
/// Call this every frame (or whenever the desired position changes) to move
/// the player panel relative to the wearer's head.
///
/// Translation lives in column 3: `matrix[0*4+3]`, `[1*4+3]`, `[2*4+3]`.
#[no_mangle]
pub unsafe extern "C" fn mvr_set_transform_hmd(handle: u64, matrix: *const f32) {
    #[cfg(feature = "steamvr")]
    overlay::set_transform_tracked_device(handle, 0, matrix);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, matrix);
}

/// Disable mouse input on the overlay so it does not consume controller laser
/// pointer events. The overlay becomes an informational display only.
#[no_mangle]
pub unsafe extern "C" fn mvr_set_input_method_none(handle: u64) {
    #[cfg(feature = "steamvr")]
    overlay::set_input_method_none(handle);
    #[cfg(not(feature = "steamvr"))]
    let _ = handle;
}

/// Enable mouse input on the overlay so controller laser pointer events are
/// delivered as `VREvent_MouseMove` / `VREvent_MouseDown` / `VREvent_MouseUp`
/// events and can be drained with `mvr_poll_event`.
///
/// `scale_x` / `scale_y` set the coordinate range for mouse events:
///   - pass the overlay's pixel dimensions to get pixel-space coordinates, or
///   - pass `1.0` / `1.0` for normalised UV coordinates in `[0..1]`.
///
/// Call this after creating the overlay and whenever the texture dimensions
/// change.  Coordinates returned by `mvr_poll_event` will be in
/// `[0..scale_x]` (x, left→right) and `[0..scale_y]` (y, bottom→top).
#[no_mangle]
#[allow(unused_variables)]
pub unsafe extern "C" fn mvr_set_input_method_mouse(handle: u64, scale_x: f32, scale_y: f32) {
    #[cfg(feature = "steamvr")]
    overlay::set_input_method_mouse(handle, scale_x, scale_y);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, scale_x, scale_y);
}

/// Poll the VRSystem event queue for a `VREvent_Quit` (700).
///
/// When found, `AcknowledgeQuit_Exiting` is called immediately so SteamVR
/// knows the app acknowledged the request.  Returns 1 when a quit event was
/// consumed; 0 when the queue is empty (no quit pending).
///
/// The caller must call `mvr_shutdown()` and exit the process after receiving 1
/// so that the process terminates within SteamVR's 5-second grace window.
#[no_mangle]
pub unsafe extern "C" fn mvr_should_quit() -> i32 {
    #[cfg(feature = "steamvr")]
    { overlay::poll_should_quit() }
    #[cfg(not(feature = "steamvr"))]
    { 0 }
}

/// Attach the overlay to the user's right wrist.
///
/// Uses `SetOverlayTransformTrackedDeviceRelative` with a fixed wrist-space
/// offset (mirrored from the wayvr watch position). Also calls
/// `SetOverlayInputMethod(None)` so the overlay never steals controller input.
///
/// Returns the device index used on success, or -1 when the right controller
/// is not currently tracked (call again later when it appears).
#[no_mangle]
#[allow(unused_variables)]
pub unsafe extern "C" fn mvr_attach_to_right_wrist(handle: u64) -> i32 {
    #[cfg(feature = "steamvr")]
    return overlay::attach_to_right_wrist(handle);
    #[cfg(not(feature = "steamvr"))]
    return -1;
}

/// Dequeue the next overlay event.
///
/// Returns 1 if an event was filled, 0 when the queue is empty.
///
/// `out_event_type`:
///   0 = mouse move / hover
///   1 = mouse button down
///   2 = mouse button up
///
/// `out_device_index`: the tracked device that generated the event.
/// `out_x`, `out_y`: normalised UV cursor position [0 .. 1].
#[no_mangle]
pub unsafe extern "C" fn mvr_poll_event(
    handle: u64,
    out_event_type: *mut u32,
    out_device_index: *mut u32,
    out_x: *mut f32,
    out_y: *mut f32,
) -> i32 {
    #[cfg(feature = "steamvr")]
    return overlay::poll_event(handle, out_event_type, out_device_index, out_x, out_y);
    #[cfg(not(feature = "steamvr"))]
    {
        let _ = (handle, out_event_type, out_device_index, out_x, out_y);
        0
    }
}

/// Register the app vrmanifest with SteamVR.
///
/// `manifest_path_utf8`: null-terminated absolute path to `mixtape.vrmanifest`.
/// Safe to call every launch – SteamVR deduplicates by app key.
/// Returns 0 on success.
#[no_mangle]
#[allow(unused_variables)]
pub unsafe extern "C" fn mvr_register_manifest(manifest_path_utf8: *const std::os::raw::c_char) -> i32 {
    #[cfg(feature = "steamvr")]
    return overlay::register_manifest(manifest_path_utf8);
    #[cfg(not(feature = "steamvr"))]
    return -1;
}
