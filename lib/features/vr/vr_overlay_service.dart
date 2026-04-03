/// High-level SteamVR overlay service.
///
/// Manages the overlay lifecycle, the grab-based earbud state machine, and
/// the frame-capture / submission loop.  All interaction with OpenVR goes
/// through [VrBridge]; all widget-tree captures go through [VrOverlayRunner].
///
/// ## Interaction model
///
/// 1. On startup the overlay is a small earbud icon anchored to the HMD at
///    the configured ear position ([earSide]).
/// 2. When the player reaches out and presses the **grip button** on the
///    controller nearest the earbud, the overlay transitions to **grabbed**
///    state: it re-anchors to that controller's identity transform so the
///    full music panel appears in the player's hand.
/// 3. The *other* controller can now point at / click the panel normally.
/// 4. Releasing the grip button returns the overlay to earbud mode.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'vr_bridge.dart';
import 'vr_overlay_runner.dart';

// ─── Overlay state ────────────────────────────────────────────────────────────

enum OverlayState { earbud, grabbed }

// ─── Ear-side config ──────────────────────────────────────────────────────────

/// Which ear the earbud rests at.
enum EarSide { left, right }

// ─── Transform helpers ───────────────────────────────────────────────────────

// 3×4 row-major:  m[row][col] = m[row*4 + col],  translation in column 3.

/// Right-ear position relative to the HMD.
const _rightEarMatrix = <double>[1, 0, 0, 0.09, 0, 1, 0, -0.10, 0, 0, 1, -0.25];

/// Left-ear position relative to the HMD.
const _leftEarMatrix = <double>[1, 0, 0, -0.09, 0, 1, 0, -0.10, 0, 0, 1, -0.25];

// ─── VrOverlayService ────────────────────────────────────────────────────────

/// Singleton service.  Call [maybeInit] after the first frame is rendered.
class VrOverlayService {
  VrOverlayService._();
  static final instance = VrOverlayService._();

  final _bridge = VrBridge.instance;

  bool _running = false;
  int _handle = -1;
  OverlayState _state = OverlayState.earbud;
  Timer? _frameTimer;
  Timer? _eventTimer;
  bool _frameInFlight = false;

  /// Which ear the earbud icon is anchored to.  Change via Settings before
  /// calling [maybeInit], or at runtime – it takes effect on the next
  /// grip release.
  EarSide earSide = EarSide.right;

  /// Device index of the controller currently holding the overlay, or null.
  // ignore: unused_field
  int? _grabbingController;

  OverlayState get state => _state;
  bool get isRunning => _running;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  /// Attempt to initialise OpenVR and start the overlay loop.
  ///
  /// Silently returns (no crash) if:
  ///   • Not on Windows / Linux / macOS.
  ///   • The native library is absent.
  ///   • SteamVR is not running.
  void maybeInit() {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (!_bridge.tryLoad()) return;

    final rc = _bridge.init();
    if (rc != 0) return; // SteamVR not available

    _handle = _bridge.createOverlay('com.mixtape.vr.main', 'Mixtape');
    if (_handle < 0) {
      _bridge.shutdown();
      return;
    }

    // Register manifest so SteamVR knows how to re-launch the app.
    _tryRegisterManifest();

    // Start in earbud mode – no pointer input needed yet.
    _bridge.setInputMethodNone(_handle);
    _applyEarbudTransform();
    _bridge.setWidth(_handle, _earbudSize);
    _bridge.show(_handle);
    _running = true;

    // ~30 fps frame submission.
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      _onFrameTick,
    );
    // ~60 fps event drain.
    _eventTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      _onEventTick,
    );
  }

  void dispose() {
    _frameTimer?.cancel();
    _eventTimer?.cancel();
    if (_running && _handle >= 0) {
      _bridge.hide(_handle);
    }
    if (_running) _bridge.shutdown();
    _running = false;
  }

  // ─── State machine ─────────────────────────────────────────────────────────

  static const double _earbudSize = 0.12; // metres
  static const double _expandedSize = 0.55; // metres

  List<double> get _earMatrix =>
      earSide == EarSide.right ? _rightEarMatrix : _leftEarMatrix;

  void _applyEarbudTransform() => _bridge.setTransformHmd(_handle, _earMatrix);

  /// Called when the player grabs the earbud with [deviceIndex].
  void _onGripPressed(int deviceIndex) {
    _grabbingController = deviceIndex;
    _state = OverlayState.grabbed;
    _bridge.setTransformController(_handle, deviceIndex);
    _bridge.setInputMethodMouse(_handle);
    _bridge.setWidth(_handle, _expandedSize);
  }

  /// Called when the player releases the grip button.
  void _onGripReleased() {
    _grabbingController = null;
    _state = OverlayState.earbud;
    _applyEarbudTransform();
    _bridge.setInputMethodNone(_handle);
    _bridge.setWidth(_handle, _earbudSize);
  }

  /// Grab/release the panel programmatically (e.g. from a debug tap on the
  /// earbud widget when not in VR).
  void toggleState() {
    if (!_running) return;
    if (_state == OverlayState.earbud) {
      // Simulate a grab using the right-hand controller index.
      final idx = _bridge.getControllerIndex(1);
      _onGripPressed(idx == 0xFFFFFFFF ? 0 : idx);
    } else {
      _onGripReleased();
    }
  }

  // ─── Event polling ─────────────────────────────────────────────────────────

  void _onEventTick(Timer _) {
    if (!_running) return;
    while (true) {
      final ev = _bridge.pollEvent(_handle);
      if (ev == null) break;
      switch (ev.type) {
        case VrEventType.gripDown:
          // Only react to grip if we are in earbud mode.
          if (_state == OverlayState.earbud) {
            _onGripPressed(ev.deviceIndex);
          }
        case VrEventType.gripUp:
          if (_state == OverlayState.grabbed) {
            _onGripReleased();
          }
        case VrEventType.buttonDown:
          // Controller trigger click while the panel is in hand – ignore here;
          // SteamVR routes the pointer ray to Flutter normally.
          break;
        case VrEventType.buttonUp:
        case VrEventType.hover:
          break;
      }
    }
  }

  // ─── Frame capture & submission ────────────────────────────────────────────

  void _onFrameTick(Timer _) {
    if (_frameInFlight || !_running) return;
    _frameInFlight = true;
    _captureAndSubmit().whenComplete(() => _frameInFlight = false);
  }

  Future<void> _captureAndSubmit() async {
    final key = _state == OverlayState.earbud
        ? VrOverlayRunner.earbudCaptureKey
        : VrOverlayRunner.appCaptureKey;

    final ctx = key.currentContext;
    if (ctx == null) return;

    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) return;

    // Capture at logical pixel ratio 1 – SteamVR compositor handles scaling.
    final image = boundary.toImageSync(pixelRatio: 1.0);
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return;

    _bridge.setOverlayRaw(
      _handle,
      byteData.buffer.asUint8List(),
      width,
      height,
    );
  }

  // ─── Manifest registration ─────────────────────────────────────────────────

  void _tryRegisterManifest() {
    // Resolve the vrmanifest path relative to the executable.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final manifestPath =
        '$exeDir/data/flutter_assets/assets/mixtape.vrmanifest';
    _bridge.registerManifest(manifestPath);
  }
}
