/// Low-level Dart FFI bindings to the `mixtape_vr` Rust cdylib.
///
/// Loads `mixtape_vr.dll` (Windows), `libmixtape_vr.so` (Linux), or
/// `libmixtape_vr.dylib` (macOS) at runtime.
/// All public members check [isAvailable] before calling through; if the
/// library is absent the getters simply return error codes / do nothing.
library;

import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// ─── Native type aliases ─────────────────────────────────────────────────────

typedef _MvrInitNative = ffi.Int32 Function();
typedef _MvrInit = int Function();

typedef _MvrShutdownNative = ffi.Void Function();
typedef _MvrShutdown = void Function();

typedef _MvrCreateOverlayNative =
    ffi.Int32 Function(
      ffi.Pointer<Utf8> key,
      ffi.Pointer<Utf8> name,
      ffi.Pointer<ffi.Uint64> outHandle,
    );
typedef _MvrCreateOverlay =
    int Function(
      ffi.Pointer<Utf8> key,
      ffi.Pointer<Utf8> name,
      ffi.Pointer<ffi.Uint64> outHandle,
    );

typedef _MvrSetOverlayRawNative =
    ffi.Int32 Function(
      ffi.Uint64 handle,
      ffi.Pointer<ffi.Uint8> rgba,
      ffi.Uint32 width,
      ffi.Uint32 height,
    );
typedef _MvrSetOverlayRaw =
    int Function(
      int handle,
      ffi.Pointer<ffi.Uint8> rgba,
      int width,
      int height,
    );

typedef _MvrSetWidthNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Float meters);
typedef _MvrSetWidth = void Function(int handle, double meters);

typedef _MvrShowHideNative = ffi.Void Function(ffi.Uint64 handle);
typedef _MvrShowHide = void Function(int handle);

typedef _MvrSetTransformHmdNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Pointer<ffi.Float> matrix);
typedef _MvrSetTransformHmd =
    void Function(int handle, ffi.Pointer<ffi.Float> matrix);

typedef _MvrSetInputNoneNative = ffi.Void Function(ffi.Uint64 handle);
typedef _MvrSetInputNone = void Function(int handle);

typedef _MvrSetInputMouseNative =
    ffi.Void Function(ffi.Uint64 handle, ffi.Float scaleX, ffi.Float scaleY);
typedef _MvrSetInputMouse =
    void Function(int handle, double scaleX, double scaleY);

typedef _MvrAttachToRightWristNative = ffi.Int32 Function(ffi.Uint64 handle);
typedef _MvrAttachToRightWrist = int Function(int handle);

typedef _MvrRegisterManifestNative =
    ffi.Int32 Function(ffi.Pointer<ffi.Char> path);
typedef _MvrRegisterManifest = int Function(ffi.Pointer<ffi.Char> path);

typedef _MvrShouldQuitNative = ffi.Int32 Function();
typedef _MvrShouldQuit = int Function();

typedef _MvrPollEventNative =
    ffi.Int32 Function(
      ffi.Uint64 handle,
      ffi.Pointer<ffi.Uint32> outType,
      ffi.Pointer<ffi.Uint32> outDeviceIndex,
      ffi.Pointer<ffi.Float> outX,
      ffi.Pointer<ffi.Float> outY,
    );
typedef _MvrPollEvent =
    int Function(
      int handle,
      ffi.Pointer<ffi.Uint32> outType,
      ffi.Pointer<ffi.Uint32> outDeviceIndex,
      ffi.Pointer<ffi.Float> outX,
      ffi.Pointer<ffi.Float> outY,
    );

// ─── VR Event ────────────────────────────────────────────────────────────────

/// Event types returned by [VrBridge.pollEvent].
///
/// Values must stay in sync with the Rust `poll_event` mapping:
///   0 hover/move  1 buttonDown  2 buttonUp
enum VrEventType { hover, buttonDown, buttonUp }

class VrEvent {
  final VrEventType type;
  final int deviceIndex;
  final double x;
  final double y;

  const VrEvent({
    required this.type,
    required this.deviceIndex,
    required this.x,
    required this.y,
  });
}

// ─── Bridge singleton ────────────────────────────────────────────────────────

class VrBridge {
  VrBridge._();
  static VrBridge? _instance;

  static VrBridge get instance => _instance ??= VrBridge._();

  ffi.DynamicLibrary? _lib;
  bool _attempted = false;

  // Bound functions (null until _loadLib succeeds).
  _MvrInit? _init;
  _MvrShutdown? _shutdown;
  _MvrCreateOverlay? _createOverlay;
  _MvrSetOverlayRaw? _setOverlayRaw;
  _MvrSetWidth? _setWidth;
  _MvrShowHide? _show;
  _MvrSetTransformHmd? _setTransformHmd;
  _MvrSetInputNone? _setInputNone;
  _MvrSetInputMouse? _setInputMouse;
  _MvrShouldQuit? _shouldQuit;
  _MvrAttachToRightWrist? _attachToRightWrist;
  _MvrRegisterManifest? _registerManifest;
  _MvrPollEvent? _pollEvent;

  // Persistent native scratch buffers reused across frames.
  ffi.Pointer<ffi.Uint8>? _framePtr;
  int _framePtrSize = 0;
  ffi.Pointer<ffi.Float>? _matrixPtr; // 12 floats

  /// Whether the native library is loaded and ready.
  bool get isAvailable => _lib != null;

  /// Attempt to load the library (idempotent). Returns [isAvailable].
  bool tryLoad() {
    if (_attempted) return isAvailable;
    _attempted = true;

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }

    try {
      final libName = Platform.isWindows
          ? 'mixtape_vr.dll'
          : Platform.isMacOS
          ? 'libmixtape_vr.dylib'
          : 'libmixtape_vr.so';
      debugPrint('[VrBridge] opening $libName');
      _lib = ffi.DynamicLibrary.open(libName);
      _bindFunctions();
      _matrixPtr = malloc<ffi.Float>(12);
      debugPrint('[VrBridge] library loaded OK');
    } catch (e, st) {
      debugPrint('[VrBridge] failed to load library: $e\n$st');
      _lib = null;
    }
    return isAvailable;
  }

  void _bindFunctions() {
    final lib = _lib!;
    _init = lib.lookupFunction<_MvrInitNative, _MvrInit>('mvr_init');
    _shutdown = lib.lookupFunction<_MvrShutdownNative, _MvrShutdown>(
      'mvr_shutdown',
    );
    _createOverlay = lib
        .lookupFunction<_MvrCreateOverlayNative, _MvrCreateOverlay>(
          'mvr_create_overlay',
        );
    _setOverlayRaw = lib
        .lookupFunction<_MvrSetOverlayRawNative, _MvrSetOverlayRaw>(
          'mvr_set_overlay_raw',
        );
    _setWidth = lib.lookupFunction<_MvrSetWidthNative, _MvrSetWidth>(
      'mvr_set_overlay_width_meters',
    );
    _show = lib.lookupFunction<_MvrShowHideNative, _MvrShowHide>(
      'mvr_show_overlay',
    );
    _setTransformHmd = lib
        .lookupFunction<_MvrSetTransformHmdNative, _MvrSetTransformHmd>(
          'mvr_set_transform_hmd',
        );
    _setInputNone = lib
        .lookupFunction<_MvrSetInputNoneNative, _MvrSetInputNone>(
          'mvr_set_input_method_none',
        );
    _setInputMouse = lib
        .lookupFunction<_MvrSetInputMouseNative, _MvrSetInputMouse>(
          'mvr_set_input_method_mouse',
        );
    _attachToRightWrist = lib
        .lookupFunction<_MvrAttachToRightWristNative, _MvrAttachToRightWrist>(
          'mvr_attach_to_right_wrist',
        );
    _registerManifest = lib
        .lookupFunction<_MvrRegisterManifestNative, _MvrRegisterManifest>(
          'mvr_register_manifest',
        );
    _pollEvent = lib.lookupFunction<_MvrPollEventNative, _MvrPollEvent>(
      'mvr_poll_event',
    );
    _shouldQuit =
        lib.lookupFunction<_MvrShouldQuitNative, _MvrShouldQuit>(
          'mvr_should_quit',
        );
  }

  // ─── Public wrappers ──────────────────────────────────────────────────────

  int init() => _init?.call() ?? -1;
  void shutdown() => _shutdown?.call();

  /// Creates an overlay. Returns the handle on success, or -1 on failure.
  int createOverlay(String key, String name) {
    if (_createOverlay == null) return -1;
    return using((arena) {
      final keyPtr = key.toNativeUtf8(allocator: arena);
      final namePtr = name.toNativeUtf8(allocator: arena);
      final out = arena<ffi.Uint64>();
      final rc = _createOverlay!(keyPtr, namePtr, out);
      return rc == 0 ? out.value.toInt() : -1;
    });
  }

  /// Submit a raw RGBA frame to the overlay. Reuses a persistent native buffer.
  /// Returns 0 on success, or an EVROverlayError code on failure.
  int setOverlayRaw(int handle, Uint8List bytes, int width, int height) {
    if (_setOverlayRaw == null) return -1;

    // Grow the persistent buffer if the frame size changed.
    if (_framePtrSize != bytes.length) {
      if (_framePtrSize > 0) malloc.free(_framePtr!);
      _framePtr = malloc<ffi.Uint8>(bytes.length);
      _framePtrSize = bytes.length;
    }
    _framePtr!.asTypedList(bytes.length).setAll(0, bytes);
    return _setOverlayRaw!(handle, _framePtr!, width, height);
  }

  void setWidth(int handle, double meters) => _setWidth?.call(handle, meters);
  void show(int handle) => _show?.call(handle);

  /// Set HMD-relative transform from a 12-element row-major float list.
  void setTransformHmd(int handle, List<double> matrix3x4) {
    if (_setTransformHmd == null || _matrixPtr == null) return;
    assert(matrix3x4.length == 12);
    for (var i = 0; i < 12; i++) {
      _matrixPtr![i] = matrix3x4[i];
    }
    _setTransformHmd!(handle, _matrixPtr!);
  }

  void setInputNone(int handle) => _setInputNone?.call(handle);

  /// Enable mouse input on the overlay with the given mouse-scale dimensions.
  ///
  /// [scaleX] / [scaleY] control the coordinate range in [VrBridge.pollEvent]:
  ///   - use the pixel dimensions of the captured frame for pixel-space coords;
  ///   - use 1.0 / 1.0 for normalised `[0..1]` UV coordinates.
  /// X increases left-to-right; Y increases bottom-to-top (OpenVR convention).
  void setInputMethodMouse(int handle, double scaleX, double scaleY) =>
      _setInputMouse?.call(handle, scaleX, scaleY);

  /// Returns true when SteamVR has sent a quit event.
  ///
  /// The native side drains one system event at a time and calls
  /// `AcknowledgeQuit_Exiting` immediately upon finding `VREvent_Quit`.
  /// The caller must shut down and exit the process promptly after this returns
  /// true so the process terminates within SteamVR's 5-second grace window.
  bool shouldQuit() => (_shouldQuit?.call() ?? 0) != 0;

  /// Attach overlay to right wrist via SetOverlayTransformTrackedDeviceRelative.
  /// Returns device index or -1 if right controller not tracked.
  int attachToRightWrist(int handle) => _attachToRightWrist?.call(handle) ?? -1;

  /// Register the vrmanifest. Returns 0 on success.
  int registerManifest(String path) {
    if (_registerManifest == null) return -1;
    return using((arena) {
      final p = path.toNativeUtf8(allocator: arena);
      return _registerManifest!(p.cast<ffi.Char>());
    });
  }

  /// Drain one event. Returns null if the queue is empty.
  VrEvent? pollEvent(int handle) {
    if (_pollEvent == null) return null;
    return using((arena) {
      final type = arena<ffi.Uint32>();
      final device = arena<ffi.Uint32>();
      final x = arena<ffi.Float>();
      final y = arena<ffi.Float>();
      final got = _pollEvent!(handle, type, device, x, y);
      if (got == 0) return null;
      return VrEvent(
        type: VrEventType.values[type.value.clamp(0, 2)],
        deviceIndex: device.value,
        x: x.value.toDouble(),
        y: y.value.toDouble(),
      );
    });
  }

  void dispose() {
    if (_framePtrSize > 0 && _framePtr != null) {
      malloc.free(_framePtr!);
      _framePtr = null;
      _framePtrSize = 0;
    }
    if (_matrixPtr != null) {
      malloc.free(_matrixPtr!);
      _matrixPtr = null;
    }
  }
}
