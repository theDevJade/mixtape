import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/audio/player_service.dart';
import 'core/models/track.dart';
import 'core/discord/discord_rpc_service.dart';
import 'core/settings/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/adaptive_scaffold.dart';

class MixtapeApp extends ConsumerWidget {
  const MixtapeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'Mixtape',
      debugShowCheckedModeBanner: false,
      theme: MixtapeTheme.buildTheme(
        scheme: settings.colorScheme,
        brightness: Brightness.light,
      ),
      darkTheme: MixtapeTheme.buildTheme(
        scheme: settings.colorScheme,
        brightness: Brightness.dark,
      ),
      themeMode: settings.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, child) {
        // Apply global font scale and optional background image
        Widget content = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(settings.fontScale)),
          child: child!,
        );

        final bgPath = settings.backgroundImagePath;
        if (bgPath != null && bgPath.isNotEmpty) {
          content = Stack(
            children: [
              Positioned.fill(
                child: Image.file(File(bgPath), fit: BoxFit.cover),
              ),
              content,
            ],
          );
        }

        return content;
      },
      home: const _AppRoot(),
    );
  }
}

/// Sits at the root and drives Discord RPC whenever the playing track changes.
class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot>
    with WidgetsBindingObserver {
  int? _lastPresenceBucket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Kick off initial connection attempt after first frame.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateDiscordPresence(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the window regains focus (macOS, Linux, Windows) the position
    // StreamProvider may have stale UI because Flutter throttles frame
    // scheduling for unfocused windows.  Invalidating forces a fresh
    // subscription that immediately emits the current player state.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(positionDataProvider);
    }
  }

  Future<void> _updateDiscordPresence() async {
    final settings = ref.read(appSettingsProvider);
    final clientId = settings.discordRpcClientId.trim();
    final rpc = ref.read(discordRpcServiceProvider);

    if (!settings.discordRpcEnabled || clientId.isEmpty) {
      await rpc.disconnect();
      return;
    }

    if (!rpc.isConnected) {
      await rpc.connect(clientId);
    }
    if (!rpc.isConnected) return;

    final track = ref.read(currentTrackProvider);
    final isPlaying = ref.read(isPlayingProvider).valueOrNull ?? false;
    final positionData = ref.read(positionDataProvider).valueOrNull;

    if (track == null) {
      await rpc.clearActivity();
      return;
    }

    final title = _truncate(track.title, 128);
    final artist = _pickArtist(track);
    final album = _cleanText(track.album);
    final sourceLabel = _sourceLabel(track);

    final infoParts = [
      if (artist != null && artist.isNotEmpty) artist,
      if (album != null && album.isNotEmpty) album,
    ];

    if (!isPlaying) {
      await rpc.setActivity(
        details: title,
        state: _truncate(
          infoParts.isNotEmpty
              ? 'Paused - ${infoParts.join(' - ')}'
              : 'Paused on $sourceLabel',
          128,
        ),
        largeImageUrl: track.albumArtUrl,
        largeImageText: _truncate(album ?? artist ?? sourceLabel, 128),
        smallImageKey: 'paused',
        smallImageText: 'Paused',
      );
      return;
    }

    final positionSeconds = (positionData?.position ?? Duration.zero).inSeconds
        .clamp(0, 2147483647);
    final durationSeconds =
        (positionData?.totalDuration ?? track.duration ?? Duration.zero)
            .inSeconds;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final startTimestamp = nowSeconds - positionSeconds;
    final endTimestamp = durationSeconds > 0
        ? startTimestamp + durationSeconds
        : null;

    await rpc.setActivity(
      details: title,
      state: _truncate(
        infoParts.isNotEmpty
            ? infoParts.join(' - ')
            : 'Playing on $sourceLabel',
        128,
      ),
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      largeImageUrl: track.albumArtUrl,
      largeImageText: _truncate(album ?? artist ?? sourceLabel, 128),
      smallImageKey: 'playing',
      smallImageText: 'Playing',
    );
  }

  String? _cleanText(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    final lowered = normalized.toLowerCase();
    const placeholders = {'unknown', 'null', 'n/a', 'na', 'url', 'uri'};
    if (placeholders.contains(lowered)) return null;

    return normalized;
  }

  String? _pickArtist(Track track) {
    final directArtist = _cleanText(track.artist);
    if (directArtist != null) return directArtist;

    final title = _cleanText(track.title);
    if (title == null) return null;

    final separators = [' - ', ' | ', ' -', '- '];
    for (final separator in separators) {
      final parts = title.split(separator);
      if (parts.length < 2) continue;

      final candidate = _cleanText(parts.first);
      if (candidate != null &&
          candidate.length >= 2 &&
          candidate.length <= 48) {
        return candidate;
      }
    }

    return null;
  }

  String _sourceLabel(Track track) {
    final sourceId = track.sourcePluginId.trim().toLowerCase();

    if (sourceId == 'com.mixtape.youtube') return 'YouTube';
    if (sourceId == 'com.mixtape.soundcloud') return 'SoundCloud';
    if (sourceId == 'com.mixtape.spotify') return 'Spotify';
    if (sourceId == 'com.mixtape.jamendo') return 'Jamendo';
    if (sourceId == 'com.mixtape.local') return 'Local Files';
    if (sourceId == 'com.mixtape.ytdlp') return 'yt-dlp';

    final previewSource = _cleanText(
      track.sourceMetadata['previewSource']?.toString(),
    );
    if (previewSource != null &&
        previewSource.toLowerCase().contains('youtube')) {
      return 'YouTube';
    }

    final candidateUrls = [
      track.sourceMetadata['youtubeUrl']?.toString(),
      track.sourceMetadata['originalUrl']?.toString(),
      track.sourceMetadata['url']?.toString(),
      track.uri,
    ];

    for (final raw in candidateUrls) {
      final parsed = Uri.tryParse(raw ?? '');
      final host = parsed?.host.toLowerCase();
      if (host == null || host.isEmpty) continue;

      if (host.contains('youtube.com') || host.contains('youtu.be')) {
        return 'YouTube';
      }
      if (host.contains('soundcloud.com')) {
        return 'SoundCloud';
      }
      if (host.contains('spotify.com')) {
        return 'Spotify';
      }

      var cleanedHost = host;
      if (cleanedHost.startsWith('www.')) {
        cleanedHost = cleanedHost.substring(4);
      }
      if (cleanedHost.startsWith('m.')) {
        cleanedHost = cleanedHost.substring(2);
      }
      if (cleanedHost.startsWith('music.')) {
        cleanedHost = cleanedHost.substring(6);
      }

      final firstLabel = cleanedHost.split('.').first;
      if (firstLabel.isNotEmpty) {
        return '${firstLabel[0].toUpperCase()}${firstLabel.substring(1)}';
      }
    }

    if (sourceId.startsWith('com.mixtape.')) {
      final suffix = sourceId.substring('com.mixtape.'.length);
      if (suffix.isNotEmpty) {
        return '${suffix[0].toUpperCase()}${suffix.substring(1)}';
      }
    }

    if (sourceId == 'url' || sourceId == 'uri' || sourceId == 'link') {
      return 'Web URL';
    }

    return sourceId.isEmpty ? 'Mixtape' : sourceId;
  }

  String _truncate(String value, int maxLength) {
    final normalized = value.trim();
    if (normalized.length <= maxLength) return normalized;
    if (maxLength <= 3) return normalized.substring(0, maxLength);
    return '${normalized.substring(0, maxLength - 3)}...';
  }

  @override
  Widget build(BuildContext context) {
    // Watch for track changes and push them to Discord.
    ref.listen<Track?>(currentTrackProvider, (_, _) async {
      _lastPresenceBucket = null;
      await _updateDiscordPresence();
    });

    // Update/clear presence when play/pause changes.
    ref.listen<AsyncValue<bool>>(isPlayingProvider, (_, _) async {
      _lastPresenceBucket = null;
      await _updateDiscordPresence();
    });

    // Refresh timestamps periodically while playing so seek/scrub stays accurate.
    ref.listen<AsyncValue<PositionData>>(positionDataProvider, (_, next) async {
      final isPlaying = ref.read(isPlayingProvider).valueOrNull ?? false;
      if (!isPlaying) return;

      final positionSeconds = next.valueOrNull?.position.inSeconds;
      if (positionSeconds == null) return;

      final bucket = positionSeconds ~/ 15;
      if (bucket == _lastPresenceBucket) return;

      _lastPresenceBucket = bucket;
      await _updateDiscordPresence();
    });

    // Also re-connect when the Discord settings change.
    ref.listen(
      appSettingsProvider.select(
        (s) => (s.discordRpcEnabled, s.discordRpcClientId),
      ),
      (_, next) async {
        final rpc = ref.read(discordRpcServiceProvider);
        final (enabled, clientId) = next;
        if (!enabled || clientId.trim().isEmpty) {
          await rpc.disconnect();
        } else {
          await rpc.connect(clientId.trim());
          _lastPresenceBucket = null;
          await _updateDiscordPresence();
        }
      },
    );

    // Keep audio cache mode in sync with settings while app is running.
    ref.listen(appSettingsProvider.select((s) => s.cacheAudioFiles), (
      _,
      enabled,
    ) {
      ref.read(audioHandlerProvider).setCacheAudioFiles(enabled);
    });

    // Keep player output volume in sync with settings while app is running.
    ref.listen(appSettingsProvider.select((s) => s.volume), (_, volume) {
      ref.read(audioHandlerProvider).setVolume(volume);
    });

    // Keep crossfade mode in sync with settings while app is running.
    ref.listen(
      appSettingsProvider.select(
        (s) => (s.crossfadeEnabled, s.crossfadeDurationSeconds),
      ),
      (_, next) {
        final (enabled, seconds) = next;
        ref
            .read(audioHandlerProvider)
            .setCrossfade(enabled: enabled, durationSeconds: seconds);
      },
    );

    return const AdaptiveScaffold();
  }
}
