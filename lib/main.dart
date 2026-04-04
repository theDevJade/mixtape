import 'dart:ui';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'splash_screen.dart';
import 'core/audio/audio_handler.dart';
import 'core/audio/player_service.dart';
import 'core/database/database.dart';
import 'core/plugins/plugin_registry.dart';
import 'core/plugins/local_files/local_files_plugin.dart';
import 'core/plugins/jamendo/jamendo_plugin.dart';
import 'core/plugins/soundcloud/soundcloud_plugin.dart';
import 'core/plugins/youtube/youtube_plugin.dart';
import 'core/plugins/spotify/spotify_plugin.dart';
import 'core/plugins/spotify_public/spotify_public_plugin.dart';
import 'core/plugins/deezer/deezer_plugin.dart';
import 'core/plugins/internet_archive/internet_archive_plugin.dart';
import 'core/plugins/free_music_archive/fma_plugin.dart';
import 'core/plugins/ytdlp/ytdlp_plugin.dart';
import 'core/providers.dart';
import 'core/settings/settings_provider.dart';
import 'features/vr/vr_overlay_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final ex = details.exception;
    if (_isKnownWebViewDetachChannelError(ex)) return;
    if (previousOnError != null) {
      previousOnError(details);
      return;
    }
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isKnownWebViewDetachChannelError(error)) return true;
    // Shut down SteamVR overlay cleanly before the isolate dies.
    VrOverlayService.instance.dispose();
    return false;
  };

  // Show splash screen immediately while heavy init happens.
  runApp(const SplashScreen());

  // Heavy initialization (MediaKit/libmpv, database, plugins, audio service).
  splashStatus.value = 'Initializing media engine…';
  MediaKit.ensureInitialized();

  splashStatus.value = 'Opening database…';
  final db = AppDatabase();

  splashStatus.value = 'Registering plugins…';
  final registry = PluginRegistry();
  registry.register(LocalFilesPlugin());
  registry.register(JamendoPlugin());
  registry.register(SoundCloudPlugin());
  registry.register(YouTubePlugin());
  registry.register(SpotifyPlugin());
  registry.register(SpotifyPublicPlugin());
  registry.register(DeezerPlugin());
  registry.register(InternetArchivePlugin());
  registry.register(FreeMusicArchivePlugin());

  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    registry.register(YtDlpPlugin());
  }

  final configRows = await db.select(db.pluginConfigsTable).get();
  final configs = <String, Map<String, String>>{};
  for (final row in configRows) {
    configs.putIfAbsent(row.pluginId, () => {})[row.key] = row.value;
  }

  final prefs = await SharedPreferences.getInstance();

  const ytdlpPluginId = 'com.mixtape.ytdlp';
  const ytdlpAckPrefKey = 'ytdlp_acknowledged';
  final ytdlpEnabledInSettings = prefs.getBool(ytdlpAckPrefKey) ?? false;
  final ytdlpConfig = configs.putIfAbsent(ytdlpPluginId, () => {});
  if (ytdlpEnabledInSettings && ytdlpConfig['ack'] != 'true') {
    ytdlpConfig['ack'] = 'true';
    await db
        .into(db.pluginConfigsTable)
        .insertOnConflictUpdate(
          PluginConfigsTableCompanion.insert(
            pluginId: ytdlpPluginId,
            key: 'ack',
            value: 'true',
          ),
        );
  }

  splashStatus.value = 'Initializing plugins…';
  await registry.initializeAll(configs);

  final cacheAudioFiles =
      prefs.getBool(AppSettingsNotifier.keyCacheAudioFiles) ?? false;
  final initialVolume = (prefs.getDouble('volume') ?? 1.0)
      .clamp(0.0, 1.0)
      .toDouble();
  final initialCrossfadeEnabled = prefs.getBool('crossfade_enabled') ?? false;
  final initialCrossfadeSeconds = prefs.getInt('crossfade_duration') ?? 0;

  splashStatus.value = 'Starting audio service…';
  final audioHandler = await AudioService.init(
    builder: () => MixtapeAudioHandler(
      registry,
      cacheAudioFiles: cacheAudioFiles,
      volume: initialVolume,
      crossfadeEnabled: initialCrossfadeEnabled,
      crossfadeDurationSeconds: initialCrossfadeSeconds,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mixtape.audio',
      androidNotificationChannelName: 'Mixtape',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
        pluginRegistryProvider.overrideWithValue(registry),
        databaseProvider.overrideWithValue(db),
      ],
      child: const MixtapeApp(),
    ),
  );

  // Start SteamVR overlay after the first frame is rendered so that
  // RepaintBoundary nodes are already attached to the render tree.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => VrOverlayService.instance.maybeInit(),
  );

  // Shut down SteamVR overlay cleanly on Ctrl-C or SIGTERM so the headset
  // screen doesn't stay black after the process exits.
  if (Platform.isLinux || Platform.isMacOS) {
    ProcessSignal.sigint.watch().listen((_) {
      VrOverlayService.instance.dispose();
      exit(0);
    });
    ProcessSignal.sigterm.watch().listen((_) {
      VrOverlayService.instance.dispose();
      exit(0);
    });
  }
}

bool _isKnownWebViewDetachChannelError(Object error) {
  if (error is! PlatformException) return false;
  if (error.code != 'channel-error') return false;
  final message = error.message ?? '';
  return message.contains(
    'dev.flutter.pigeon.webview_flutter_wkwebview.PigeonInternalInstanceManager.removeStrongReference',
  );
}
