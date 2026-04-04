/// High-level SteamVR overlay service.
///
/// Shows the music player as a persistent right-wrist overlay, mirroring the
/// wayvr watch anchor strategy: SetOverlayTransformTrackedDeviceRelative with
/// a fixed wrist-space offset. Input is set to None so the overlay never
/// consumes controller laser events.
///
/// Frames are submitted at up to 30 fps using the Vulkan `SetOverlayTexture`
/// path (via the Rust layer) which has no per-frame shared-memory limits.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vr_bridge.dart';
import 'vr_overlay_runner.dart';

// ─── Transform helpers ───────────────────────────────────────────────────────

// HMD-fallback 3x4 row-major: shown when right controller is not yet tracked.
// Centred, 0.7 m in front, 0.15 m below eye level.
const _hmdFallbackMatrix = <double>[
  1, 0, 0,  0.00,
  0, 1, 0, -0.15,
  0, 0, 1, -0.70,
];

// ─── VrOverlayService ────────────────────────────────────────────────────────

/// Singleton service. Call [maybeInit] after the first frame is rendered.
class VrOverlayService {
  VrOverlayService._();
  static final instance = VrOverlayService._();

  final _bridge = VrBridge.instance;

  bool _running = false;
  int _handle = -1;
  Timer? _frameTimer;
  Timer? _eventTimer;
  bool _frameInFlight = false;
  bool _widgetDirty = true;

  // Current overlay texture dimensions in logical pixels.
  // Updated each time the captured frame changes size.
  // Used to:
  //   (a) keep SetOverlayMouseScale in sync with the rendered content, and
  //   (b) flip the Y axis when converting VR mouse coords to Flutter coords.
  int _overlayWidth = 0;
  int _overlayHeight = 0;

  // Per SteamVR tracked-device pointer state.
  // Key = deviceIndex from VrEvent, Value = whether button is currently down.
  // Needed to emit PointerMoveEvent (not PointerHoverEvent) during a drag.
  final Map<int, bool> _pointerDown = {};

  // Whether the overlay is currently anchored to the right wrist.
  // False means we fell back to the HMD position (controller not yet tracked).
  bool _onWrist = false;
  int _wristRetryTick = 0;
  // Re-try attaching to the controller every ~2 s (120 event ticks @ 16 ms).
  static const int _wristRetryInterval = 120;

  bool get isRunning => _running;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Attempt to initialise OpenVR and start the overlay loop.
  ///
  /// Silently returns if the platform is unsupported, the native library is
  /// absent, or SteamVR is not running.
  Future<void> maybeInit() async {
    if (_running) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('vr_overlay_enabled') ?? true)) {
      debugPrint('[VrOverlay] disabled by settings');
      return;
    }
    if (!_bridge.tryLoad()) {
      debugPrint('[VrOverlay] bridge not available');
      return;
    }

    final rc = _bridge.init();
    if (rc != 0) {
      debugPrint('[VrOverlay] mvr_init returned $rc (SteamVR not running?)');
      return;
    }

    _handle = _bridge.createOverlay('com.mixtape.vr.main', 'Mixtape');
    if (_handle < 0) {
      debugPrint('[VrOverlay] createOverlay failed (handle=$_handle)');
      _bridge.shutdown();
      return;
    }
    debugPrint('[VrOverlay] overlay created, handle=$_handle');

    _tryRegisterManifest();

    // Wrist display: 15 cm wide (comparable to a wristwatch screen).
    _bridge.setWidth(_handle, 0.15);
    _bridge.show(_handle);
    _running = true;

    // Attempt to anchor to the right wrist immediately. Falls back to HMD if
    // the controller is not yet tracked; the event tick retries periodically.
    _tryAttachWrist();

    // Enable mouse input so the controller laser pointer generates events.
    // Scale will be updated properly once the first frame is captured.
    // Use 1.0 x 1.0 as a safe initialiser (normalised UV space).
    _bridge.setInputMethodMouse(_handle, 1.0, 1.0);

    // Submit up to 30 fps. With the Vulkan SetOverlayTexture path there is no
    // shared-memory block limit so we can push frames as fast as we want.
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      _onFrameTick,
    );
    // Mark dirty on every Flutter frame so we only submit when there is new
    // content to display.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      _widgetDirty = true;
    });
    // ~60 fps event drain.
    _eventTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      _onEventTick,
    );
  }

  void dispose() {
    _frameTimer?.cancel();
    _eventTimer?.cancel();
    if (_running) _bridge.shutdown();
    _running = false;
    _pointerDown.clear();
  }

  // ─── Wrist attachment ──────────────────────────────────────────────────────

  /// Try to anchor the overlay to the right-hand controller wrist.
  ///
  /// On success: wrist tracking is handled by SteamVR automatically.
  /// On failure: falls back to the HMD position so the overlay stays visible.
  void _tryAttachWrist() {
    final rc = _bridge.attachToRightWrist(_handle);
    if (rc >= 0) {
      _onWrist = true;
      debugPrint('[VrOverlay] attached to right wrist (device $rc)');
    } else {
      debugPrint('[VrOverlay] right controller not found – using HMD fallback');
      _bridge.setTransformHmd(_handle, _hmdFallbackMatrix);
    }
    // Re-apply mouse input (attach_to_right_wrist no longer forces None).
    _bridge.setInputMethodMouse(
      _handle,
      _overlayWidth > 0 ? _overlayWidth.toDouble() : 1.0,
      _overlayHeight > 0 ? _overlayHeight.toDouble() : 1.0,
    );
  }

  // ─── Event polling ─────────────────────────────────────────────────────────

  void _onEventTick(Timer _) {
    if (!_running) return;

    // Check for SteamVR quit event first.
    if (_bridge.shouldQuit()) {
      debugPrint('[VrOverlay] received VREvent_Quit from SteamVR – shutting down');
      dispose();
      // Give the Rust side's WaitFrameSync thread a moment to acknowledge,
      // then exit the process cleanly so vrserver doesn't have to kill us.
      Future.delayed(const Duration(milliseconds: 100), () => exit(0));
      return;
    }

    // Re-try wrist attachment until the right controller comes online.
    if (!_onWrist) {
      _wristRetryTick++;
      if (_wristRetryTick >= _wristRetryInterval) {
        _wristRetryTick = 0;
        _tryAttachWrist();
      }
    }

    // Drain overlay events and forward them as Flutter pointer events.
    while (true) {
      final ev = _bridge.pollEvent(_handle);
      if (ev == null) break;
      _dispatchVrEvent(ev);
    }
  }

  /// Convert a [VrEvent] to a Flutter [PointerEvent] and inject it into the
  /// gesture pipeline.
  ///
  /// SteamVR mouse coordinate convention (with SetOverlayMouseScale):
  ///   x: 0 = left edge,  scale_x = right edge
  ///   y: 0 = BOTTOM edge, scale_y = TOP edge  (y flipped vs. Flutter)
  ///
  /// We flip Y so Flutter receives top-left-origin logical pixels.
  void _dispatchVrEvent(VrEvent ev) {
    // Guard against zero dimensions before the first frame is captured.
    if (_overlayWidth <= 0 || _overlayHeight <= 0) return;

    final lx = ev.x;
    final ly = _overlayHeight.toDouble() - ev.y;
    final position = ui.Offset(lx, ly);
    final pointerId = ev.deviceIndex;

    switch (ev.type) {
      case VrEventType.buttonDown:
        _pointerDown[pointerId] = true;
        GestureBinding.instance.handlePointerEvent(
          PointerDownEvent(
            pointer: pointerId,
            position: position,
            kind: PointerDeviceKind.touch,
          ),
        );
      case VrEventType.buttonUp:
        _pointerDown[pointerId] = false;
        GestureBinding.instance.handlePointerEvent(
          PointerUpEvent(
            pointer: pointerId,
            position: position,
            kind: PointerDeviceKind.touch,
          ),
        );
      case VrEventType.hover:
        if (_pointerDown[pointerId] == true) {
          // Button held: emit a drag/move event.
          GestureBinding.instance.handlePointerEvent(
            PointerMoveEvent(
              pointer: pointerId,
              position: position,
              kind: PointerDeviceKind.touch,
            ),
          );
        } else {
          // Button not held: emit a hover event (enables hover highlighting).
          GestureBinding.instance.handlePointerEvent(
            PointerHoverEvent(
              pointer: pointerId,
              position: position,
              kind: PointerDeviceKind.touch,
            ),
          );
        }
    }
  }

  // ─── Frame capture and submission ──────────────────────────────────────────

  void _onFrameTick(Timer _) {
    if (_frameInFlight || !_running) return;
    _frameInFlight = true;
    _captureAndSubmit().whenComplete(() => _frameInFlight = false);
  }

  Future<void> _captureAndSubmit() async {
    if (!_widgetDirty) return;
    _widgetDirty = false;

    final ctx = VrOverlayRunner.appCaptureKey.currentContext;
    if (ctx == null) return;

    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || (kDebugMode && boundary.debugNeedsPaint)) return;

    final image = await boundary.toImage(pixelRatio: 1.0);
    final width = image.width;
    final height = image.height;
    if (width == 0 || height == 0) {
      image.dispose();
      return;
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return;

    // Update mouse scale whenever the captured frame dimensions change so that
    // VR mouse event coordinates match the overlay's actual pixel layout.
    if (width != _overlayWidth || height != _overlayHeight) {
      _overlayWidth = width;
      _overlayHeight = height;
      _bridge.setInputMethodMouse(
        _handle,
        width.toDouble(),
        height.toDouble(),
      );
      debugPrint('[VrOverlay] updated mouse scale to ${width}x$height');
    }

    final rc = _bridge.setOverlayRaw(
      _handle,
      byteData.buffer.asUint8List(),
      width,
      height,
    );
    if (rc != 0) {
      debugPrint('[VrOverlay] setOverlayRaw failed (EVROverlayError=$rc)');
    }
  }

  // ─── Manifest registration ─────────────────────────────────────────────────

  void _tryRegisterManifest() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final manifestPath =
        '$exeDir/data/flutter_assets/assets/mixtape.vrmanifest';
    _bridge.registerManifest(manifestPath);
  }
}
