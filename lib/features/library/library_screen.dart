import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/player_service.dart';
import '../../core/providers.dart';
import '../../core/database/database.dart';
import '../../core/database/daos/tracks_dao.dart';
import '../../core/database/daos/playlists_dao.dart';
import '../../core/models/track.dart';
import '../../shared/widgets/cover_art.dart';
import '../player/now_playing_screen.dart';
import '../search/search_screen.dart' show SearchScreen, showAddByUrlDialog;
import '../sources/sources_screen.dart';
import 'playlist_edit_screen.dart';

final libraryTracksProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(databaseProvider);
  final dao = TracksDao(db);
  return dao.watchAllTracks().map((rows) => rows.map(dao.mapToTrack).toList());
});

final _playlistRowsProvider = StreamProvider<List<PlaylistsTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  return PlaylistsDao(db).watchAllPlaylists();
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.music_note_rounded), text: 'Tracks'),
              Tab(icon: Icon(Icons.queue_music_rounded), text: 'Playlists'),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.sort_rounded), onPressed: () {}),
          ],
        ),
        body: const TabBarView(children: [_TracksTab(), _PlaylistsTab()]),
      ),
    );
  }
}

// ── Tracks tab ───────────────────────────────────────────────────────────────

class _TracksTab extends ConsumerWidget {
  const _TracksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(libraryTracksProvider);
    final playerService = ref.read(playerServiceProvider);

    return tracksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.library_music_rounded,
                  size: 80,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your library is empty',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search for Music'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Add by URL'),
                      onPressed: () => showAddByUrlDialog(context),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.hub_rounded),
                      label: const Text('Configure Sources'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SourcesScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return ListView.builder(
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (track.duration != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _fmt(track.duration!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () {
                      playerService.playQueue(tracks, startIndex: i);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NowPlayingScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              onTap: null,
              onLongPress: () {
                playerService.playQueue(tracks, startIndex: i);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                );
              },
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Playlists tab ─────────────────────────────────────────────────────────────

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(_playlistRowsProvider);
    final db = ref.read(databaseProvider);

    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (playlists) {
        return Scaffold(
          body: playlists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 80,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No playlists yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: playlists.length,
                  itemBuilder: (context, i) {
                    final p = playlists[i];
                    return ListTile(
                      leading: PlaylistHeaderImage(
                        playlistId: p.id,
                        coverArtUrl: p.coverArtUrl,
                        height: 56,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: p.description != null
                          ? Text(
                              p.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded),
                        tooltip: 'Edit playlist',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaylistEditScreen(playlistId: p.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _createPlaylist(context, db),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext context, dynamic db) async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Playlist name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await PlaylistsDao(db).createPlaylist(nameCtrl.text.trim());
    }
  }
}
