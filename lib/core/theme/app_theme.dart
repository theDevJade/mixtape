import 'package:flutter/material.dart';

enum AppColorScheme {
  midnight,
  cassette,
  forest,
  ocean,
  neon,
  rose,
  mono,
}

class MixtapeTheme {
  static ThemeData buildTheme({
    required AppColorScheme scheme,
    required Brightness brightness,
  }) {
    final seeds = schemeSeeds[scheme] ?? schemeSeeds[AppColorScheme.midnight]!;
    final seed = brightness == Brightness.dark ? seeds.$1 : seeds.$2;

    return ThemeData(
      colorSchemeSeed: seed,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static const Map<AppColorScheme, (Color, Color)> schemeSeeds = {
    AppColorScheme.midnight: (Color(0xFF7C4DFF), Color(0xFF651FFF)),
    AppColorScheme.cassette: (Color(0xFFFF6E40), Color(0xFFFF3D00)),
    AppColorScheme.forest: (Color(0xFF69F0AE), Color(0xFF00C853)),
    AppColorScheme.ocean: (Color(0xFF40C4FF), Color(0xFF0091EA)),
    AppColorScheme.neon: (Color(0xFFE040FB), Color(0xFFAA00FF)),
    AppColorScheme.rose: (Color(0xFFFF80AB), Color(0xFFF50057)),
    AppColorScheme.mono: (Color(0xFF9E9E9E), Color(0xFF616161)),
  };

  static String schemeName(AppColorScheme scheme) => switch (scheme) {
        AppColorScheme.midnight => 'Midnight',
        AppColorScheme.cassette => 'Cassette',
        AppColorScheme.forest => 'Forest',
        AppColorScheme.ocean => 'Ocean',
        AppColorScheme.neon => 'Neon',
        AppColorScheme.rose => 'Rose',
        AppColorScheme.mono => 'Mono',
      };
}
