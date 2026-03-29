import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/plugins/ytdlp/ytdlp_plugin.dart';
import '../../core/providers.dart';
import '../../core/models/track.dart';
import '../../core/audio/player_service.dart';
import '../../core/settings/settings_provider.dart';
import 'widgets/lyrics_view.dart';

final _showLyricsProvider = StateProvider.autoDispose<bool>((_) => false);

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(positionDataProvider);
    final settings = ref.watch(appSettingsProvider);
    final playerService = ref.read(playerServiceProvider);
    final shuffle = ref.watch(shuffleProvider);
    final repeat = ref.watch(repeatModeProvider);
    final showLyrics = ref.watch(_showLyricsProvider);

    if (track == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    final isPlaying = isPlayingAsync.value ?? false;
    final position = positionAsync.value;
    final colorScheme = Theme.of(context).colorScheme;
    final videoId = _extractYouTubeVideoId(track);
    final videoSourceUrl = _extractYouTubeSourceUrl(track, videoId);
    final showVideo = settings.showYoutubeVideoInPlayer && videoId != null;
    final effectiveTotalDuration = position == null
        ? null
        : _effectiveDuration(track, position.totalDuration);
    final effectivePosition = position == null
        ? null
        : _effectivePosition(track, position.position, position.totalDuration);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.lyrics_rounded,
              color: showLyrics ? Colors.white : Colors.white54,
            ),
            tooltip: showLyrics ? 'Show artwork' : 'Show lyrics',
            onPressed: () =>
                ref.read(_showLyricsProvider.notifier).state = !showLyrics,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showTrackOptions(context, ref),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (track.albumArtUrl != null && settings.showAlbumColorInPlayer)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: settings.playerBlurIntensity,
                sigmaY: settings.playerBlurIntensity,
              ),
              child: CachedNetworkImage(
                imageUrl: track.albumArtUrl!,
                fit: BoxFit.cover,
              ),
            ),
          Container(color: Colors.black.withValues(alpha: 0.45)),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: showLyrics
                        ? const LyricsView(key: ValueKey('lyrics'))
                        : (showVideo
                              ? Padding(
                                  key: const ValueKey('video'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: _YouTubeVideoEmbed(
                                        videoId: videoId,
                                        sourceUrl: videoSourceUrl,
                                        audioPosition:
                                            effectivePosition ?? Duration.zero,
                                        audioPlaying: isPlaying,
                                      ),
                                    ),
                                  ),
                                )
                              : Padding(
                                  key: const ValueKey('artwork'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: track.albumArtUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: track.albumArtUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons.music_note_rounded,
                                                size: 80,
                                              ),
                                            ),
                                    ),
                                  ),
                                )),
                  ),
                ),

                const SizedBox(height: 32),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (track.artist != null)
                              Text(
                                track.artist!,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (_shouldShowRefetchButton(track))
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _refetchMetadata(context, ref, track),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Refetch'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (position != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: effectivePosition!.inMilliseconds
                                .toDouble()
                                .clamp(
                                  0,
                                  effectiveTotalDuration!.inMilliseconds
                                      .toDouble()
                                      .clamp(1, double.infinity),
                                ),
                            max: effectiveTotalDuration.inMilliseconds
                                .toDouble()
                                .clamp(1, double.infinity),
                            onChanged: (v) {
                              // Scale the seek target back to the raw player
                              // timeline when duration is doubled.
                              final rawTotal = position.totalDuration;
                              final effectiveMax =
                                  effectiveTotalDuration.inMilliseconds;
                              final rawMax = rawTotal.inMilliseconds.clamp(
                                1,
                                1 << 53,
                              );
                              final scaledMs = (v * rawMax / effectiveMax)
                                  .round();
                              playerService.seekTo(
                                Duration(milliseconds: scaledMs),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(effectivePosition),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatDuration(effectiveTotalDuration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 4),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.volume_down_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: settings.volume,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            label: '${(settings.volume * 100).round()}%',
                            onChanged: ref
                                .read(appSettingsProvider.notifier)
                                .setVolume,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: settings.rearrangePlayerControls
                        ? [
                            IconButton(
                              iconSize: 26,
                              icon: Icon(
                                _repeatIcon(repeat),
                                color: repeat != LoopMode.off
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                              onPressed: () => playerService.cycleRepeatMode(),
                            ),
                            _transportCircle(
                              context,
                              icon: Icons.skip_next_rounded,
                              onPressed: () => playerService.skipToNext(),
                              track: track,
                              settings: settings,
                            ),
                            _transportCircle(
                              context,
                              icon: isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onPressed: () => isPlaying
                                  ? playerService.pause()
                                  : playerService.resume(),
                              track: track,
                              settings: settings,
                              isPrimary: true,
                            ),
                            _transportCircle(
                              context,
                              icon: Icons.skip_previous_rounded,
                              onPressed: () => playerService.skipToPrevious(),
                              track: track,
                              settings: settings,
                            ),
                            IconButton(
                              iconSize: 26,
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: shuffle ? Colors.white : Colors.white54,
                              ),
                              onPressed: () => playerService.toggleShuffle(),
                            ),
                          ]
                        : [
                            IconButton(
                              iconSize: 26,
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: shuffle ? Colors.white : Colors.white54,
                              ),
                              onPressed: () => playerService.toggleShuffle(),
                            ),
                            _transportCircle(
                              context,
                              icon: Icons.skip_previous_rounded,
                              onPressed: () => playerService.skipToPrevious(),
                              track: track,
                              settings: settings,
                            ),
                            _transportCircle(
                              context,
                              icon: isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onPressed: () => isPlaying
                                  ? playerService.pause()
                                  : playerService.resume(),
                              track: track,
                              settings: settings,
                              isPrimary: true,
                            ),
                            _transportCircle(
                              context,
                              icon: Icons.skip_next_rounded,
                              onPressed: () => playerService.skipToNext(),
                              track: track,
                              settings: settings,
                            ),
                            IconButton(
                              iconSize: 26,
                              icon: Icon(
                                _repeatIcon(repeat),
                                color: repeat != LoopMode.off
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                              onPressed: () => playerService.cycleRepeatMode(),
                            ),
                          ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon(LoopMode mode) => switch (mode) {
    LoopMode.one => Icons.repeat_one_rounded,
    LoopMode.all => Icons.repeat_rounded,
    LoopMode.off => Icons.repeat_rounded,
  };

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Duration _effectiveDuration(Track track, Duration runtimeDuration) {
    final metadataDuration = track.duration;
    if (metadataDuration == null || metadataDuration <= Duration.zero) {
      return runtimeDuration;
    }
    if (runtimeDuration <= Duration.zero) {
      return metadataDuration;
    }

    final isYouTube =
        track.sourcePluginId == 'com.mixtape.youtube' ||
        _isYouTubeUrl(track.uri);
    if (!isYouTube) return runtimeDuration;

    final runtimeMs = runtimeDuration.inMilliseconds;
    final metadataMs = metadataDuration.inMilliseconds;
    if (metadataMs <= 0) return runtimeDuration;

    final ratio = runtimeMs / metadataMs;
    if (ratio >= 1.5 || ratio <= 0.67) {
      return metadataDuration;
    }
    return runtimeDuration;
  }

  /// Scales the raw just_audio position down when the container reports a
  /// doubled duration (common with certain YouTube-resolved m4a streams).
  Duration _effectivePosition(
    Track track,
    Duration rawPosition,
    Duration runtimeDuration,
  ) {
    final metadataDuration = track.duration;
    if (metadataDuration == null || metadataDuration <= Duration.zero) {
      return rawPosition;
    }
    if (runtimeDuration <= Duration.zero) return rawPosition;

    final isYouTube =
        track.sourcePluginId == 'com.mixtape.youtube' ||
        _isYouTubeUrl(track.uri);
    if (!isYouTube) return rawPosition;

    final runtimeMs = runtimeDuration.inMilliseconds;
    final metadataMs = metadataDuration.inMilliseconds;
    if (metadataMs <= 0) return rawPosition;

    final ratio = runtimeMs / metadataMs;
    if (ratio >= 1.5 || ratio <= 0.67) {
      // Scale position by the same ratio so it tracks the corrected timeline.
      return Duration(
        milliseconds: (rawPosition.inMilliseconds / ratio).round(),
      );
    }
    return rawPosition;
  }

  bool _isYouTubeUrl(String uriText) {
    final uri = Uri.tryParse(uriText);
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') || host.endsWith('youtu.be');
  }

  Widget _transportCircle(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required Track track,
    required AppSettings settings,
    bool isPrimary = false,
  }) {
    final size = isPrimary ? 64.0 : 54.0;
    final iconSize = isPrimary ? 36.0 : 30.0;
    final useArtwork =
        settings.useArtworkOnPlayerButtons && track.albumArtUrl != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: useArtwork ? Colors.white.withValues(alpha: 0.22) : Colors.white,
        image: useArtwork
            ? DecorationImage(
                image: CachedNetworkImageProvider(track.albumArtUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.35),
                  BlendMode.darken,
                ),
              )
            : null,
      ),
      child: IconButton(
        iconSize: iconSize,
        icon: Icon(icon, color: useArtwork ? Colors.white : Colors.black),
        onPressed: onPressed,
      ),
    );
  }

  void _showTrackOptions(BuildContext context, WidgetRef ref) {
    final track = ref.read(currentTrackProvider);
    if (track == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                ref.read(playerServiceProvider).addToQueue(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowRefetchButton(Track track) {
    final title = track.title.trim();
    final artist = track.artist?.trim() ?? '';
    final albumArt = track.albumArtUrl?.trim() ?? '';
    final albumArtUri = Uri.tryParse(albumArt);

    final missingArt =
        albumArt.isEmpty ||
        albumArtUri == null ||
        (!albumArtUri.hasScheme) ||
        (albumArtUri.scheme != 'http' && albumArtUri.scheme != 'https');
    final missingNames = title.isEmpty || artist.isEmpty;

    return missingArt || missingNames;
  }

  Future<void> _refetchMetadata(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final previousArt = track.albumArtUrl;
    if (previousArt != null && previousArt.isNotEmpty) {
      await CachedNetworkImage.evictFromCache(previousArt);
    }

    final updated = await ref
        .read(playerServiceProvider)
        .refetchTrackMetadata(track);

    if (updated == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not refetch metadata for this track'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final newArt = updated.albumArtUrl;
    if (newArt != null && newArt.isNotEmpty) {
      await CachedNetworkImage.evictFromCache(newArt);
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Track metadata refreshed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _extractYouTubeVideoId(Track track) {
    String? normalizeId(String? raw) {
      final trimmed = raw?.trim();
      if (trimmed?.isEmpty ?? true) return null;
      final value = trimmed!;
      final m = RegExp(r'^[A-Za-z0-9_-]{11}$').firstMatch(value);
      return m?.group(0);
    }

    final fromMeta = normalizeId(track.sourceMetadata['videoId']?.toString());
    if (fromMeta != null) return fromMeta;

    final fromYoutubeUrl =
        track.sourceMetadata['youtubeUrl']?.toString() ??
        track.sourceMetadata['originalUrl']?.toString();
    final fromUrlMeta = _extractVideoIdFromText(fromYoutubeUrl);
    if (fromUrlMeta != null) return fromUrlMeta;

    final fromTrackId = normalizeId(track.id);
    if (fromTrackId != null && track.sourcePluginId.contains('youtube')) {
      return fromTrackId;
    }

    final fromUri = _extractVideoIdFromText(track.uri);
    if (fromUri != null) return fromUri;

    final fromTrackIdUrl = _extractVideoIdFromText(track.id);
    if (fromTrackIdUrl != null) return fromTrackIdUrl;

    return null;
  }

  String _extractYouTubeSourceUrl(Track track, String? videoId) {
    final fromMeta = track.sourceMetadata['youtubeUrl']?.toString();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;

    final fromOriginal = track.sourceMetadata['originalUrl']?.toString();
    if (fromOriginal != null && fromOriginal.isNotEmpty) return fromOriginal;

    if (_extractVideoIdFromText(track.uri) != null) return track.uri;
    if (videoId != null) return 'https://www.youtube.com/watch?v=$videoId';
    return track.uri;
  }

  String? _extractVideoIdFromText(String? text) {
    if (text?.isEmpty ?? true) return null;
    final uri = text!;
    final patterns = [
      RegExp(r'[?&]v=([^&]+)'),
      RegExp(r'youtu\.be/([^?&/]+)'),
      RegExp(r'youtube\.com/embed/([^?&/]+)'),
      RegExp(r'youtube\.com/shorts/([^?&/]+)'),
      RegExp(r'youtube\.com/live/([^?&/]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(uri);
      if (m != null && m.groupCount >= 1) {
        final candidate = m.group(1)?.trim();
        if (candidate != null &&
            RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)) {
          return candidate;
        }
      }
    }
    return null;
  }
}

class _YouTubeVideoEmbed extends ConsumerStatefulWidget {
  final String videoId;
  final String sourceUrl;
  final Duration audioPosition;
  final bool audioPlaying;
  const _YouTubeVideoEmbed({
    required this.videoId,
    required this.sourceUrl,
    required this.audioPosition,
    required this.audioPlaying,
  });

  @override
  ConsumerState<_YouTubeVideoEmbed> createState() => _YouTubeVideoEmbedState();
}

class _YouTubeVideoEmbedState extends ConsumerState<_YouTubeVideoEmbed> {
  VideoPlayerController? _controller;
  String? _downloadedPreviewPath;
  bool _loadFailed = false;
  bool _loading = true;

  Uri get _watchUrl =>
      Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}');

  @override
  void initState() {
    super.initState();
    unawaited(_initializePreview());
  }

  @override
  void didUpdateWidget(covariant _YouTubeVideoEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.sourceUrl != widget.sourceUrl) {
      unawaited(_disposeController());
      setState(() {
        _controller = null;
        _loadFailed = false;
        _loading = true;
      });
      unawaited(_initializePreview());
      return;
    }

    if (oldWidget.audioPosition != widget.audioPosition ||
        oldWidget.audioPlaying != widget.audioPlaying) {
      unawaited(_syncVideoToAudio(force: false));
    }
  }

  Future<void> _initializePreview() async {
    try {
      final registry = ref.read(pluginRegistryProvider);
      final plugin = registry['com.mixtape.ytdlp'];
      if (plugin is! YtDlpPlugin || !await plugin.isConfigured()) {
        throw Exception('yt-dlp is not configured');
      }

      final previewPath = await plugin.downloadPreviewFile(widget.sourceUrl);
      if (previewPath == null || !File(previewPath).existsSync()) {
        throw Exception('Preview download failed');
      }

      final controller = await _createControllerWithRetry(File(previewPath));

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _downloadedPreviewPath = previewPath;
        _loading = false;
      });

      await _syncVideoToAudio(force: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  Future<VideoPlayerController> _createControllerWithRetry(File file) async {
    final maxAttempts = Platform.isMacOS ? 4 : 1;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final controller = VideoPlayerController.file(file);
      try {
        if (Platform.isMacOS) {
          await WidgetsBinding.instance.endOfFrame;
        }
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.play();
        return controller;
      } catch (e) {
        lastError = e;
        await controller.dispose();

        if (!_isRecoverableVideoInitError(e) || attempt == maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw Exception('Video preview initialization failed: $lastError');
  }

  Future<void> _syncVideoToAudio({required bool force}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    final targetMs = widget.audioPosition.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toInt();
    final currentMs = controller.value.position.inMilliseconds;
    final driftMs = (currentMs - targetMs).abs();

    if (force || driftMs > 1500) {
      await controller.seekTo(Duration(milliseconds: targetMs));
    }

    if (widget.audioPlaying) {
      if (!controller.value.isPlaying) {
        await controller.play();
      }
    } else {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
    }
  }

  bool _isRecoverableVideoInitError(Object error) {
    if (error is! PlatformException) return false;
    if (error.code != 'channel-error') return false;
    final msg = error.message ?? '';
    return msg.contains('video_player_avfoundation') ||
        msg.contains('AVFoundationVideoPlayerApi.initialize');
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      await c.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  Future<void> _openExternalVideo() async {
    await launchUrl(_watchUrl, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDownloadedPreview() async {
    final path = _downloadedPreviewPath;
    if (path == null || path.isEmpty) {
      await _openExternalVideo();
      return;
    }
    await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
  }

  Widget _fallback(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: 'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Container(color: Colors.black),
        ),
        Container(color: Colors.black.withValues(alpha: 0.40)),
        Center(
          child: FilledButton.icon(
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(
              _downloadedPreviewPath != null
                  ? 'Play Downloaded Preview'
                  : 'Open Video',
            ),
            onPressed: _downloadedPreviewPath != null
                ? _openDownloadedPreview
                : _openExternalVideo,
          ),
        ),
      ],
    );
  }

  Widget _loadingPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: 'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Container(color: Colors.black),
        ),
        Container(color: Colors.black.withValues(alpha: 0.35)),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return _fallback(context);
    }

    if (_loading) {
      return _loadingPlaceholder();
    }

    final controller = _controller;
    if (controller == null) {
      return _loadingPlaceholder();
    }

    if (!controller.value.isInitialized) {
      return _loadingPlaceholder();
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
