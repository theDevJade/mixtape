/// Static [GlobalKey]s used to locate the [RenderRepaintBoundary] nodes that
/// the VR overlay frame-capture pipeline reads each tick.
///
/// Both keys are attached to [RepaintBoundary] widgets inserted by
/// [MixtapeApp]:
///   • [appCaptureKey]    — the full app content (expanded overlay mode)
///   • [earbudCaptureKey] — the compact [VrEarbudWidget] (earbud mode)
library;

import 'package:flutter/widgets.dart';

abstract final class VrOverlayRunner {
  static final GlobalKey appCaptureKey = GlobalKey(debugLabel: 'vr.app');
  static final GlobalKey earbudCaptureKey = GlobalKey(debugLabel: 'vr.earbud');
}
