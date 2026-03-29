import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/player_service.dart';
import '../../../core/models/track.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../shared/widgets/cover_art.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback onTap;

  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final isPlayingAsync = ref.watch(isPlayingProvider);
    final isPlaying = isPlayingAsync.value ?? false;
    final isResolving = ref.watch(isResolvingProvider).value ?? false;
    final position = ref.watch(positionDataProvider).value;
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final playerService = ref.read(playerServiceProvider);

    if (track == null) return const SizedBox.shrink();

    final effectiveTotalDuration = position == null
        ? null
        : _effectiveDuration(track, position.totalDuration);
    final effectivePosition = position == null
        ? null
        : _effectivePosition(track, position.position, position.totalDuration);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 84,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  CoverArt(url: track.albumArtUrl, size: 48, borderRadius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (track.artist != null)
                          Text(
                            track.artist!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (position != null)
                          Text(
                            '${_fmt(effectivePosition!)} / ${_fmt(effectiveTotalDuration!)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Volume',
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => _showVolumeSheet(
                      context,
                      settings.volume,
                      settingsNotifier.setVolume,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: () => playerService.skipToPrevious(),
                  ),
                  IconButton(
                    iconSize: 32,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: isResolving
                        ? null
                        : () => isPlaying
                              ? playerService.pause()
                              : playerService.resume(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: () => playerService.skipToNext(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            if (position != null)
              LinearProgressIndicator(
                value: effectiveTotalDuration!.inMilliseconds <= 0
                    ? 0
                    : (effectivePosition!.inMilliseconds /
                              effectiveTotalDuration.inMilliseconds)
                          .clamp(0, 1),
                minHeight: 3,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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
    if (ratio >= 1.8 || ratio <= (1 / 1.8)) {
      return metadataDuration;
    }
    return runtimeDuration;
  }

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

    // During crossfade/auto-advance handoff, runtime duration may briefly
    // belong to the previous item. Avoid ratio-based scaling until position
    // has moved past the startup window of the new item.
    if (rawPosition < const Duration(seconds: 4)) return rawPosition;

    final isYouTube =
        track.sourcePluginId == 'com.mixtape.youtube' ||
        _isYouTubeUrl(track.uri);
    if (!isYouTube) return rawPosition;

    final runtimeMs = runtimeDuration.inMilliseconds;
    final metadataMs = metadataDuration.inMilliseconds;
    if (metadataMs <= 0) return rawPosition;

    final ratio = runtimeMs / metadataMs;
    if (ratio >= 1.8 || ratio <= (1 / 1.8)) {
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

  void _showVolumeSheet(
    BuildContext context,
    double volume,
    ValueChanged<double> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        var v = volume;
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume ${(v * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: v,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      onChanged: (next) {
                        setState(() => v = next);
                        onChanged(next);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
