import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/player_service.dart';
import '../../core/models/track.dart';
import '../../core/plugins/local_files/local_files_plugin.dart';
import '../../core/plugins/source_plugin.dart';
import '../../core/providers.dart';
import '../../shared/widgets/cover_art.dart';
import '../player/now_playing_screen.dart';

/// Shows indexed local files and provides entry points to pick more.
class LocalFilesScreen extends ConsumerStatefulWidget {
  const LocalFilesScreen({super.key});

  @override
  ConsumerState<LocalFilesScreen> createState() => _LocalFilesScreenState();
}

class _LocalFilesScreenState extends ConsumerState<LocalFilesScreen> {
  List<SourceResult> _tracks = [];
  bool _loading = false;

  LocalFilesPlugin get _plugin =>
      ref.read(pluginRegistryProvider)['com.mixtape.local']!
          as LocalFilesPlugin;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final results = await _plugin.browse(limit: 9999);
    if (mounted) setState(() => _tracks = results);
  }

  Future<void> _pickFiles() async {
    setState(() => _loading = true);
    try {
      await _plugin.pickFiles();
      await _refresh();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    setState(() => _loading = true);
    try {
      await _plugin.scanDirectory(result);
      await _refresh();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _play(SourceResult r) {
    final track = Track(
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
    ref.read(playerServiceProvider).play(track);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NowPlayingScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    return Scaffold(
      appBar: AppBar(title: const Text('Local Files')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tracks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 72,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No local files added',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick audio files or scan a folder to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _ActionButtons(
                    isDesktop: isDesktop,
                    onPickFiles: _pickFiles,
                    onScanFolder: _scanFolder,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${_tracks.length} track${_tracks.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      _ActionButtons(
                        isDesktop: isDesktop,
                        onPickFiles: _pickFiles,
                        onScanFolder: _scanFolder,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, i) {
                      final r = _tracks[i];
                      return ListTile(
                        leading: CoverArt(
                          url: r.thumbnailUrl,
                          size: 48,
                          borderRadius: 8,
                        ),
                        title: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [r.artist, r.album].whereType<String>().join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: r.duration != null
                            ? Text(
                                _fmt(r.duration!),
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            : null,
                        onTap: () => _play(r),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isDesktop;
  final bool compact;
  final VoidCallback onPickFiles;
  final VoidCallback onScanFolder;

  const _ActionButtons({
    required this.isDesktop,
    required this.onPickFiles,
    required this.onScanFolder,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.audio_file_rounded, size: 18),
            label: const Text('Add Files'),
            onPressed: onPickFiles,
          ),
          if (isDesktop) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.folder_rounded, size: 18),
              label: const Text('Scan Folder'),
              onPressed: onScanFolder,
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.audio_file_rounded),
          label: const Text('Pick Files'),
          onPressed: onPickFiles,
        ),
        if (isDesktop) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_rounded),
            label: const Text('Scan Folder'),
            onPressed: onScanFolder,
          ),
        ],
      ],
    );
  }
}
