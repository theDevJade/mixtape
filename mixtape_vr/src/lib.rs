//! mixtape_vr – SteamVR overlay bridge for the Mixtape Flutter app.
//!
//! Exposes a flat C API (`mvr_*`) loaded by the Dart side via `dart:ffi`.
//! Build with `--features steamvr` on Windows / Linux for the real OpenVR
//! implementation. Without the feature, every function is a safe no-op stub
//! that returns -1 / 0 so the Dart code can detect "VR not available".

#![allow(clippy::missing_safety_doc)]

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
#[no_mangle]
pub unsafe extern "C" fn mvr_set_overlay_raw(
    handle: u64,
    rgba: *const u8,
    width: u32,
    height: u32,
) {
    #[cfg(feature = "steamvr")]
    overlay::set_overlay_raw(handle, rgba, width, height);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, rgba, width, height);
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

/// Hide the overlay without destroying it.
#[no_mangle]
pub unsafe extern "C" fn mvr_hide_overlay(handle: u64) {
    #[cfg(feature = "steamvr")]
    overlay::hide_overlay(handle);
    #[cfg(not(feature = "steamvr"))]
    let _ = handle;
}

/// Anchor the overlay to the HMD (device index 0) using the supplied 3×4
/// row-major transform matrix (12 `f32` values: 3 rows × 4 columns).
///
/// Translation lives in column 3: `matrix[0*4+3]`, `[1*4+3]`, `[2*4+3]`.
#[no_mangle]
pub unsafe extern "C" fn mvr_set_transform_hmd(handle: u64, matrix: *const f32) {
    #[cfg(feature = "steamvr")]
    overlay::set_transform_tracked_device(handle, 0, matrix);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, matrix);
}

/// Anchor the overlay to an arbitrary tracked device (e.g. a controller).
///
/// `device_index` is the OpenVR tracked device index (0 = HMD, 1/2 =
/// controllers in most configurations).
#[no_mangle]
pub unsafe extern "C" fn mvr_set_transform_device(
    handle: u64,
    device_index: u32,
    matrix: *const f32,
) {
    #[cfg(feature = "steamvr")]
    overlay::set_transform_tracked_device(handle, device_index, matrix);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, device_index, matrix);
}

/// Enable laser-pointer mouse input on the overlay so that SteamVR forwards
/// controller intersections as Win32 / X11 mouse events to the process.
#[no_mangle]
pub unsafe extern "C" fn mvr_set_input_method_mouse(handle: u64) {
    #[cfg(feature = "steamvr")]
    overlay::set_input_method_mouse(handle);
    #[cfg(not(feature = "steamvr"))]
    let _ = handle;
}

/// Dequeue the next overlay event.
///
/// Returns 1 if an event was filled, 0 when the queue is empty.
///
/// `out_event_type`:
///   0 = mouse move / hover
///   1 = mouse button down  (trigger / primary button)
///   2 = mouse button up
///
/// `out_device_index`: the tracked device that generated the event.
/// `out_x`, `out_y`: normalised UV cursor position [0 … 1].
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

/// Set the overlay transform anchored to a specific controller at identity
/// offset (used to hold the expanded panel in the grabbing hand).
///
/// `device_index`: OpenVR tracked device index of the controller.
#[no_mangle]
pub unsafe extern "C" fn mvr_set_transform_controller(handle: u64, device_index: u32) {
    #[cfg(feature = "steamvr")]
    overlay::set_transform_controller_identity(handle, device_index);
    #[cfg(not(feature = "steamvr"))]
    let _ = (handle, device_index);
}

/// Disable pointer input on the overlay (earbud resting mode).
#[no_mangle]
pub unsafe extern "C" fn mvr_set_input_none(handle: u64) {
    #[cfg(feature = "steamvr")]
    overlay::set_input_method_none(handle);
    #[cfg(not(feature = "steamvr"))]
    let _ = handle;
}

/// Return the tracked device index of the left (0) or right (1) controller.
///
/// Returns `0xFFFFFFFF` if the controller is not tracked / unavailable.
#[no_mangle]
pub unsafe extern "C" fn mvr_get_controller_index(hand: u32) -> u32 {
    #[cfg(feature = "steamvr")]
    return overlay::get_controller_index(hand);
    #[cfg(not(feature = "steamvr"))]
    {
        let _ = hand;
        0xFFFF_FFFF
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
