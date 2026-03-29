import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/player_service.dart';
import '../../core/database/daos/playlists_dao.dart';
import '../../core/database/database.dart';
import '../../core/models/track.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art.dart';
import '../player/now_playing_screen.dart';
import 'playlist_edit_screen.dart';

final _playlistTracksProvider = StreamProvider.family<List<Track>, String>((
  ref,
  playlistId,
) {
  final db = ref.watch(databaseProvider);
  return PlaylistsDao(db).watchPlaylistTracks(playlistId);
});

final _playlistRowProvider = StreamProvider.family<PlaylistsTableData?, String>(
  (ref, playlistId) {
    final db = ref.watch(databaseProvider);
    return PlaylistsDao(db).watchAllPlaylists().map(
      (rows) => rows.where((r) => r.id == playlistId).firstOrNull,
    );
  },
);

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(_playlistRowProvider(playlistId));
    final tracksAsync = ref.watch(_playlistTracksProvider(playlistId));
    final playerService = ref.read(playerServiceProvider);

    final playlist = playlistAsync.valueOrNull;
    final tracks = tracksAsync.valueOrNull ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit playlist',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaylistEditScreen(playlistId: playlistId),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                playlist?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: PlaylistHeaderImage(
                playlistId: playlistId,
                coverArtUrl: playlist?.coverArtUrl,
                height: 220,
              ),
            ),
          ),

          // ── Play all button + track count ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${tracks.length} track${tracks.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (tracks.isNotEmpty) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Shuffle'),
                      onPressed: () async {
                        await playerService.playQueue(tracks);
                        if (!ref.read(shuffleProvider)) {
                          await playerService.toggleShuffle();
                        }
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NowPlayingScreen(),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play all'),
                      onPressed: () {
                        playerService.playQueue(tracks);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NowPlayingScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (playlist?.description != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  playlist!.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: Divider(height: 1)),

          // ── Track list ─────────────────────────────────────────────────
          if (tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 64,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tracks yet',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add songs from the Tracks tab',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final track = tracks[i];
                return ListTile(
                  leading: CoverArt(
                    url: track.albumArtUrl,
                    size: 48,
                    borderRadius: 8,
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [track.artist, track.album].whereType<String>().join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'More options',
                    onPressed: () => _showPlaylistTrackSheet(
                      context,
                      ref,
                      track,
                      tracks,
                      i,
                      playlistId,
                    ),
                  ),
                  onTap: () {
                    playerService.playQueue(tracks, startIndex: i);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NowPlayingScreen(),
                      ),
                    );
                  },
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

void _showPlaylistTrackSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
  List<Track> queue,
  int index,
  String playlistId,
) {
  final playerService = ref.read(playerServiceProvider);
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(context);
              playerService.playQueue(queue, startIndex: index);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_play_next_rounded),
            title: const Text('Play next'),
            onTap: () {
              Navigator.pop(context);
              playerService.playNext(track);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Playing next')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_to_queue_rounded),
            title: const Text('Add to queue'),
            onTap: () {
              Navigator.pop(context);
              playerService.addToQueue(track);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Added to queue')));
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.playlist_remove_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Remove from playlist',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(context);
              final db = ref.read(databaseProvider);
              await PlaylistsDao(db).removeTrackFromPlaylist(
                playlistId,
                track.id,
                track.sourcePluginId,
              );
            },
          ),
        ],
      ),
    ),
  );
}
