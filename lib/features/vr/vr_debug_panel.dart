/// Quick-test panel shown on the home screen when SteamVR is running.
///
/// Lets you load a hard-coded or custom track directly into the player so
/// the VR earbud overlay shows something.  Also displays live overlay state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/player_service.dart';
import '../../core/models/track.dart';
import 'vr_overlay_service.dart';

// A handful of freely-streamable test tracks (Internet Archive / CC).
const _kTestTracks = [
  (
    title: 'Gymnopedie No. 1 – Satie',
    artist: 'Kevin MacLeod',
    uri:
        'https://ia801900.us.archive.org/16/items/kevin-macleod-gymnopedie-no-1/Gymnopedie_No_1.mp3',
  ),
  (
    title: 'Bike Ride – Vibe Tracks',
    artist: 'YouTube Audio Library',
    uri:
        'https://ia803404.us.archive.org/25/items/bike-ride-vibe-tracks/Bike%20Ride%20-%20Vibe%20Tracks.mp3',
  ),
  (
    title: 'Impact Moderato – Kevin MacLeod',
    artist: 'Kevin MacLeod',
    uri:
        'https://ia801508.us.archive.org/20/items/impact-moderato-by-kevin-macleod/impact-moderato.mp3',
  ),
];

class VrDebugPanel extends ConsumerStatefulWidget {
  const VrDebugPanel({super.key});

  @override
  ConsumerState<VrDebugPanel> createState() => _VrDebugPanelState();
}

class _VrDebugPanelState extends ConsumerState<VrDebugPanel> {
  final _uriController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  Future<void> _loadTrack(String uri, String title, String artist) async {
    setState(() => _loading = true);
    final track = Track(
      id: 'vr-debug-${uri.hashCode}',
      title: title,
      artist: artist,
      uri: uri,
      sourcePluginId: 'vr_debug',
    );
    await ref.read(playerServiceProvider).play(track);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vr = VrOverlayService.instance;
    final track = ref.watch(currentTrackProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vrpano_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'VR Debug',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _StatusChip(vr: vr),
              ],
            ),
            const SizedBox(height: 8),
            if (track != null)
              Text(
                'Now playing: ${track.title}${track.artist != null ? " – ${track.artist}" : ""}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                'No track loaded – overlay shows blank',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.error,
                ),
              ),
            const SizedBox(height: 10),
            Text('Quick-load:', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _kTestTracks)
                  ActionChip(
                    label: Text(t.title, style: const TextStyle(fontSize: 11)),
                    onPressed: _loading
                        ? null
                        : () => _loadTrack(t.uri, t.title, t.artist),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _uriController,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Custom audio URL or file path...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _loading
                      ? null
                      : () {
                          final uri = _uriController.text.trim();
                          if (uri.isNotEmpty) {
                            _loadTrack(uri, uri.split('/').last, 'Custom');
                          }
                        },
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.vr});
  final VrOverlayService vr;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final running = vr.isRunning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: running ? cs.primaryContainer : cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        running ? 'overlay running' : 'offline',
        style: TextStyle(
          fontSize: 11,
          color: running ? cs.onPrimaryContainer : cs.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
