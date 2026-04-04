import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/player_service.dart';
import '../../core/models/track.dart';
import '../../core/providers.dart';
import '../../core/plugins/source_plugin.dart';
import '../../core/database/daos/play_history_dao.dart';
import '../../shared/widgets/cover_art.dart';
import '../player/now_playing_screen.dart';
import '../search/search_screen.dart';
import '../sources/sources_screen.dart';
import '../vr/vr_debug_panel.dart';
import '../vr/vr_overlay_service.dart';

final _recentlyPlayedProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(databaseProvider);
  return PlayHistoryDao(db).watchRecentlyPlayed(limit: 20);
});

final _browseResultsProvider = FutureProvider<List<SourceResult>>((ref) async {
  final registry = ref.watch(pluginRegistryProvider);
  final plugins = registry.pluginsWithCapability(PluginCapability.browse);
  if (plugins.isEmpty) return [];
  final results = await Future.wait(
    plugins.map(
      (p) => p.browse(limit: 10).catchError((Object _) => <SourceResult>[]),
    ),
  );
  return results.expand((r) => r).toList();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseAsync = ref.watch(_browseResultsProvider);
    final currentTrack = ref.watch(currentTrackProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mixtape'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: browseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (results) {
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sources configured',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set up a source plugin to browse and search for music',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.hub_rounded),
                        label: const Text('Configure Sources'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SourcesScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ── VR debug panel (only when overlay is running) ──
              if (VrOverlayService.instance.isRunning)
                const SliverToBoxAdapter(child: VrDebugPanel()),
              // ── Recently Played ──
              Consumer(
                builder: (context, ref, _) {
                  final recentAsync = ref.watch(_recentlyPlayedProvider);
                  final recentTracks = recentAsync.valueOrNull ?? [];
                  if (recentTracks.isEmpty) return const SliverToBoxAdapter();
                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Recently Played',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 200,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: recentTracks.length,
                            itemBuilder: (context, i) {
                              final t = recentTracks[i];
                              return _RecentlyPlayedCard(track: t);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // ── Featured ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Featured',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: results.take(10).length,
                    itemBuilder: (context, i) {
                      final r = results[i];
                      return _FeaturedCard(result: r);
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'All Tracks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TrackListTile(result: results[i]),
                  childCount: results.length,
                ),
              ),
              // Spacer for mini player
              if (currentTrack != null)
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }
}

class _RecentlyPlayedCard extends ConsumerWidget {
  final Track track;
  const _RecentlyPlayedCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);
    return GestureDetector(
      onTap: () {
        playerService.play(track);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(url: track.albumArtUrl, size: 140, borderRadius: 12),
            const SizedBox(height: 6),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (track.artist != null)
              Text(
                track.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends ConsumerWidget {
  final SourceResult result;
  const _FeaturedCard({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);
    return GestureDetector(
      onTap: () {
        playerService.play(_toTrack(result));
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(url: result.thumbnailUrl, size: 140, borderRadius: 12),
            const SizedBox(height: 6),
            Text(
              result.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (result.artist != null)
              Text(
                result.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Track _toTrack(SourceResult r) => Track(
    id: r.id,
    title: r.title,
    artist: r.artist,
    album: r.album,
    albumArtUrl: r.thumbnailUrl,
    duration: r.duration,
    uri: r.uri,
    sourcePluginId: r.sourcePluginId,
    sourceMetadata: r.metadata,
    addedAt: DateTime.now(),
  );
}

class _TrackListTile extends ConsumerWidget {
  final SourceResult result;
  const _TrackListTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);
    return ListTile(
      leading: CoverArt(url: result.thumbnailUrl, size: 48, borderRadius: 8),
      title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [result.artist, result.album].whereType<String>().join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: result.duration != null
          ? Text(
              _fmt(result.duration!),
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      onTap: () {
        playerService.play(_toTrack(result));
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      },
    );
  }

  Track _toTrack(SourceResult r) => Track(
    id: r.id,
    title: r.title,
    artist: r.artist,
    album: r.album,
    albumArtUrl: r.thumbnailUrl,
    duration: r.duration,
    uri: r.uri,
    sourcePluginId: r.sourcePluginId,
    sourceMetadata: r.metadata,
    addedAt: DateTime.now(),
  );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
