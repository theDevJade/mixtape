import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/audio/player_service.dart';
import '../../core/database/daos/tracks_dao.dart';
import '../../core/models/track.dart';
import '../../core/providers.dart';
import '../../core/plugins/source_plugin.dart';
import '../../shared/widgets/cover_art.dart';
import '../player/now_playing_screen.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');
final _activePluginIdProvider = StateProvider<String?>((ref) => null);
final _searchResultsProvider = FutureProvider.autoDispose<List<SourceResult>>((
  ref,
) async {
  final query = ref.watch(_searchQueryProvider);
  final pluginId = ref.watch(_activePluginIdProvider);
  final registry = ref.watch(pluginRegistryProvider);

  if (query.isEmpty) return [];

  final plugins = pluginId != null
      ? [registry[pluginId]].whereType<MixtapeSourcePlugin>().toList()
      : registry.pluginsWithCapability(PluginCapability.search);

  final results = await Future.wait(
    plugins.map((p) => p.search(query).catchError((_) => <SourceResult>[])),
  );
  return results.expand((r) => r).toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showAddByUrlDialog(BuildContext context, WidgetRef ref) {
    showAddByUrlDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(pluginRegistryProvider);
    final activePlugin = ref.watch(_activePluginIdProvider);
    final searchAsync = ref.watch(_searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'Add by URL',
            onPressed: () => _showAddByUrlDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _controller,
              hintText: 'Search for tracks, artists…',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _controller.clear();
                      ref.read(_searchQueryProvider.notifier).state = '';
                    },
                  ),
              ],
              onChanged: (value) {
                ref.read(_searchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // Source filter chips
          if (registry.plugins.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: activePlugin == null,
                    onSelected: (_) =>
                        ref.read(_activePluginIdProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 8),
                  ...registry
                      .pluginsWithCapability(PluginCapability.search)
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(p.name),
                            selected: activePlugin == p.id,
                            onSelected: (_) =>
                                ref
                                        .read(_activePluginIdProvider.notifier)
                                        .state =
                                    p.id,
                          ),
                        ),
                      ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: searchAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (results) {
                if (results.isEmpty &&
                    ref.read(_searchQueryProvider).isNotEmpty) {
                  return const Center(child: Text('No results'));
                }
                if (results.isEmpty) {
                  final hasSearchPlugins = registry
                      .pluginsWithCapability(PluginCapability.search)
                      .isNotEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 72,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasSearchPlugins
                                ? 'Search across all your sources'
                                : 'No sources configured',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasSearchPlugins
                                ? 'Type something above to find tracks'
                                : 'Go to the Sources tab and configure a plugin\n(e.g. YouTube, Jamendo, SoundCloud)',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) =>
                      _SearchResultTile(result: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final SourceResult result;
  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);

    return ListTile(
      leading: CoverArt(url: result.thumbnailUrl, size: 50, borderRadius: 8),
      title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [result.artist, result.album].whereType<String>().join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (result.duration != null)
            Text(
              _fmt(result.duration!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showOptions(context, ref),
          ),
        ],
      ),
      onTap: () {
        final track = _toTrack(result);
        playerService.play(track);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      },
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    final playerService = ref.read(playerServiceProvider);
    final track = _toTrack(result);
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
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Play now'),
              onTap: () {
                playerService.play(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Text('Play next'),
              onTap: () {
                playerService.playNext(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                playerService.addToQueue(track);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add_rounded),
              title: const Text('Save to library'),
              onTap: () async {
                final db = ref.read(databaseProvider);
                await TracksDao(db).upsertTrack(track);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${track.title}" saved to library'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
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

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Add by URL dialog ─────────────────────────────────────────────────────────

void showAddByUrlDialog(BuildContext context) {
  showDialog<void>(context: context, builder: (_) => const AddByUrlDialog());
}

class AddByUrlDialog extends ConsumerStatefulWidget {
  const AddByUrlDialog({super.key});

  @override
  ConsumerState<AddByUrlDialog> createState() => _AddByUrlDialogState();
}

class _AddByUrlDialogState extends ConsumerState<AddByUrlDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add by URL'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Paste a direct audio URL, YouTube link, or any URL supported by your enabled sources.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://…',
                prefixIcon: Icon(Icons.link_rounded),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'Leave blank to use URL as title',
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          icon: _loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: const Text('Play'),
          onPressed: _loading ? null : () => _submit(context, save: false),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.library_add_rounded),
          label: const Text('Save'),
          onPressed: _loading ? null : () => _submit(context, save: true),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, {required bool save}) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a URL');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preview = await _fetchPreview(url);
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : (preview['title'] ??
                Uri.tryParse(url)?.pathSegments.lastWhere(
                  (s) => s.isNotEmpty,
                  orElse: () => url,
                ) ??
                url);

      final videoId = _extractYouTubeVideoId(url);

      final track = Track(
        id: url,
        title: title,
        artist: preview['artist'],
        album: preview['provider'],
        albumArtUrl: preview['thumbnail'],
        uri: url,
        sourcePluginId: 'url',
        sourceMetadata: {
          'originalUrl': url,
          'youtubeUrl': ?(videoId != null
              ? 'https://www.youtube.com/watch?v=$videoId'
              : null),
          'videoId': ?videoId,
          'previewSource': ?preview['source'],
          'provider': ?preview['provider'],
        },
        addedAt: DateTime.now(),
      );

      if (save) {
        final db = ref.read(databaseProvider);
        await TracksDao(db).upsertTrack(track);
      }

      if (!context.mounted) return;
      Navigator.pop(context);

      final playerService = ref.read(playerServiceProvider);
      if (save) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" saved to library'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        playerService.play(track);
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  String? _extractYouTubeVideoId(String url) {
    final patterns = [
      RegExp(r'[?&]v=([^&]+)'),
      RegExp(r'youtu\.be/([^?&/]+)'),
      RegExp(r'youtube\.com/embed/([^?&/]+)'),
      RegExp(r'youtube\.com/shorts/([^?&/]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null && m.groupCount >= 1) return m.group(1);
    }
    return null;
  }

  Future<Map<String, String?>> _fetchPreview(String url) async {
    final videoId = _extractYouTubeVideoId(url);
    if (videoId == null) return const {'title': null, 'thumbnail': null};

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final response = await dio.get(
        'https://www.youtube.com/oembed',
        queryParameters: {'url': url, 'format': 'json'},
      );
      final data = response.data as Map<String, dynamic>;
      return {
        'title': data['title']?.toString(),
        'artist': data['author_name']?.toString(),
        'provider': data['provider_name']?.toString(),
        'thumbnail': data['thumbnail_url']?.toString(),
        'source': 'youtube_oembed',
      };
    } catch (_) {
      return {
        'title': null,
        'artist': null,
        'provider': 'YouTube',
        'thumbnail': 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        'source': 'youtube_fallback',
      };
    }
  }
}
