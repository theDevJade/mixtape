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
import 'playlist_detail_screen.dart';
import 'playlist_edit_screen.dart';

enum _TrackSort {
  titleAsc('Title (A–Z)'),
  titleDesc('Title (Z–A)'),
  artistAsc('Artist (A–Z)'),
  artistDesc('Artist (Z–A)'),
  dateNewest('Date Added (Newest)'),
  dateOldest('Date Added (Oldest)'),
  durationAsc('Duration (Shortest)'),
  durationDesc('Duration (Longest)');

  const _TrackSort(this.label);
  final String label;
}

enum _PlaylistSort {
  nameAsc('Name (A–Z)'),
  nameDesc('Name (Z–A)'),
  dateNewest('Date Created (Newest)'),
  dateOldest('Date Created (Oldest)');

  const _PlaylistSort(this.label);
  final String label;
}

final _trackSortProvider = StateProvider<_TrackSort>(
  (_) => _TrackSort.dateNewest,
);
final _playlistSortProvider = StateProvider<_PlaylistSort>(
  (_) => _PlaylistSort.nameAsc,
);

final libraryTracksProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(databaseProvider);
  final dao = TracksDao(db);
  return dao.watchAllTracks().map((rows) => rows.map(dao.mapToTrack).toList());
});

final _playlistRowsProvider = StreamProvider<List<PlaylistsTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  return PlaylistsDao(db).watchAllPlaylists();
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSortSheet() {
    if (_tabController.index == 0) {
      _showTrackSortSheet();
    } else {
      _showPlaylistSortSheet();
    }
  }

  void _showTrackSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sort Tracks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._TrackSort.values.map((mode) {
                    final current = ref.read(_trackSortProvider);
                    return ListTile(
                      title: Text(mode.label),
                      trailing: current == mode
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        ref.read(_trackSortProvider.notifier).state = mode;
                        Navigator.pop(context);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sort Playlists',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._PlaylistSort.values.map((mode) {
                    final current = ref.read(_playlistSortProvider);
                    return ListTile(
                      title: Text(mode.label),
                      trailing: current == mode
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        ref.read(_playlistSortProvider.notifier).state = mode;
                        Navigator.pop(context);
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.music_note_rounded), text: 'Tracks'),
            Tab(icon: Icon(Icons.queue_music_rounded), text: 'Playlists'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TracksTab(), _PlaylistsTab()],
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
    final sortMode = ref.watch(_trackSortProvider);
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

        final sorted = [...tracks];
        switch (sortMode) {
          case _TrackSort.titleAsc:
            sorted.sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
            );
          case _TrackSort.titleDesc:
            sorted.sort(
              (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
            );
          case _TrackSort.artistAsc:
            sorted.sort(
              (a, b) => (a.artist ?? '').toLowerCase().compareTo(
                (b.artist ?? '').toLowerCase(),
              ),
            );
          case _TrackSort.artistDesc:
            sorted.sort(
              (a, b) => (b.artist ?? '').toLowerCase().compareTo(
                (a.artist ?? '').toLowerCase(),
              ),
            );
          case _TrackSort.dateNewest:
            sorted.sort(
              (a, b) => (b.addedAt ?? DateTime(0)).compareTo(
                a.addedAt ?? DateTime(0),
              ),
            );
          case _TrackSort.dateOldest:
            sorted.sort(
              (a, b) => (a.addedAt ?? DateTime(0)).compareTo(
                b.addedAt ?? DateTime(0),
              ),
            );
          case _TrackSort.durationAsc:
            sorted.sort(
              (a, b) => (a.duration ?? Duration.zero).compareTo(
                b.duration ?? Duration.zero,
              ),
            );
          case _TrackSort.durationDesc:
            sorted.sort(
              (a, b) => (b.duration ?? Duration.zero).compareTo(
                a.duration ?? Duration.zero,
              ),
            );
        }

        return ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, i) {
            final track = sorted[i];
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
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        _fmt(track.duration!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  IconButton(
                    tooltip: 'More options',
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () =>
                        _showTrackActionsSheet(context, ref, track, sorted, i),
                  ),
                ],
              ),
              onTap: () {
                playerService.playQueue(sorted, startIndex: i);
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
    final sortMode = ref.watch(_playlistSortProvider);
    final db = ref.read(databaseProvider);

    return playlistsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (playlists) {
        final sorted = [...playlists];
        switch (sortMode) {
          case _PlaylistSort.nameAsc:
            sorted.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          case _PlaylistSort.nameDesc:
            sorted.sort(
              (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
            );
          case _PlaylistSort.dateNewest:
            sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case _PlaylistSort.dateOldest:
            sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }

        return Scaffold(
          body: sorted.isEmpty
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
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final p = sorted[i];
                    return ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PlaylistDetailScreen(playlistId: p.id),
                        ),
                      ),
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: PlaylistHeaderImage(
                          playlistId: p.id,
                          coverArtUrl: p.coverArtUrl,
                          height: 56,
                          borderRadius: BorderRadius.circular(8),
                        ),
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

void _showTrackActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Track track,
  List<Track> queue,
  int index,
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
            leading: const Icon(Icons.shuffle_rounded),
            title: const Text('Shuffle all'),
            onTap: () async {
              Navigator.pop(context);
              await playerService.playQueue(queue, startIndex: index);
              if (!ref.read(shuffleProvider)) {
                await playerService.toggleShuffle();
              }
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                );
              }
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
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Add to playlist'),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistSheet(context, track);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Remove from library',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmRemoveFromLibrary(context, ref, track),
          ),
        ],
      ),
    ),
  );
}

void _confirmRemoveFromLibrary(
  BuildContext context,
  WidgetRef ref,
  Track track,
) {
  Navigator.pop(context);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove from library'),
      content: Text('Remove "${track.title}" from your library?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () async {
            Navigator.pop(ctx);
            final db = ref.read(databaseProvider);
            await TracksDao(db).deleteTrack(track.id, track.sourcePluginId);
          },
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}

void _showAddToPlaylistSheet(BuildContext context, Track track) {
  showModalBottomSheet(
    context: context,
    builder: (_) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  final Track track;
  const _AddToPlaylistSheet({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(_playlistRowsProvider).valueOrNull ?? [];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Add to playlist',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No playlists yet. Create one in the Playlists tab.'),
            )
          else
            ...playlists.map(
              (p) => ListTile(
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: PlaylistHeaderImage(
                    playlistId: p.id,
                    coverArtUrl: p.coverArtUrl,
                    height: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final db = ref.read(databaseProvider);
                  final dao = PlaylistsDao(db);
                  final existing = await dao.getPlaylistTracks(p.id);
                  await dao.addTrackToPlaylist(p.id, track, existing.length);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added to ${p.name}')),
                    );
                  }
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
