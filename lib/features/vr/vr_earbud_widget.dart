/// Compact music-player widget rendered into the SteamVR earbud overlay.
///
/// Identical in content to [MiniPlayer] but self-contained for off-screen
/// VR capture — it lives in a `Positioned(left: -4000)` slot inside the
/// app's root [Stack] so it is always rendered but never visible on the
/// desktop.
///
/// Tapping the overlay in VR (which SteamVR routes as a mouse click to the
/// Flutter window) triggers [VrOverlayService.toggleState] to switch between
/// earbud and expanded modes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/player_service.dart';
import '../../shared/widgets/cover_art.dart';
import 'vr_overlay_service.dart';

class VrEarbudWidget extends ConsumerWidget {
  const VrEarbudWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;
    final playerService = ref.read(playerServiceProvider);

    if (track == null) {
      return const ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: VrOverlayService.instance.toggleState,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CoverArt(url: track.albumArtUrl, size: 52, borderRadius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artist != null && track.artist!.isNotEmpty)
                      Text(
                        track.artist!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 22,
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: playerService.skipToPrevious,
              ),
              IconButton(
                iconSize: 30,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                onPressed: isPlaying
                    ? playerService.pause
                    : playerService.resume,
              ),
              IconButton(
                iconSize: 22,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: playerService.skipToNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
