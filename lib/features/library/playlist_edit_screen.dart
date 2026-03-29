import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/daos/playlists_dao.dart';
import '../../core/providers.dart';

/// Returns the local header image path for a playlist (null if not set).
final _playlistHeaderImageProvider = FutureProvider.family<String?, String>((
  ref,
  playlistId,
) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('playlist_${playlistId}_header');
});

/// Opens the edit screen for a playlist. Use [Navigator.push].
class PlaylistEditScreen extends ConsumerStatefulWidget {
  final String playlistId;

  const PlaylistEditScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends ConsumerState<PlaylistEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  String? _headerImagePath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _initData();
  }

  Future<void> _initData() async {
    final db = ref.read(databaseProvider);
    final dao = PlaylistsDao(db);
    final row = await dao.getPlaylist(widget.playlistId);
    final prefs = await SharedPreferences.getInstance();
    final headerPath = prefs.getString('playlist_${widget.playlistId}_header');

    if (!mounted) return;
    setState(() {
      _nameCtrl.text = row?.name ?? '';
      _descCtrl.text = row?.description ?? '';
      _headerImagePath = headerPath;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickHeaderImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result?.files.single.path != null) {
      setState(() => _headerImagePath = result!.files.single.path!);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    final db = ref.read(databaseProvider);
    final dao = PlaylistsDao(db);
    await dao.updatePlaylist(
      widget.playlistId,
      name: name,
      description: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : null,
    );

    // Persist header image path in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (_headerImagePath != null) {
      await prefs.setString(
        'playlist_${widget.playlistId}_header',
        _headerImagePath!,
      );
    } else {
      await prefs.remove('playlist_${widget.playlistId}_header');
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Playlist'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Header image ──────────────────────────────────────────────────
          GestureDetector(
            onTap: _pickHeaderImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    image: _headerImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_headerImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _headerImagePath == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 48,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add header image',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
                if (_headerImagePath != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ImageActionButton(
                          icon: Icons.edit_rounded,
                          onTap: _pickHeaderImage,
                          tooltip: 'Change image',
                        ),
                        const SizedBox(width: 8),
                        _ImageActionButton(
                          icon: Icons.delete_outline_rounded,
                          onTap: () => setState(() => _headerImagePath = null),
                          tooltip: 'Remove image',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Name ─────────────────────────────────────────────────────────
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Description ───────────────────────────────────────────────────
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 32),

          FilledButton(onPressed: _save, child: const Text('Save changes')),
        ],
      ),
    );
  }
}

/// Small floating action button overlay on the header image
class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _ImageActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Shows the header image for a playlist - checks local file first,
/// then falls back to the network coverArtUrl.
class PlaylistHeaderImage extends ConsumerWidget {
  final String playlistId;
  final String? coverArtUrl;
  final double height;
  final BorderRadius? borderRadius;

  const PlaylistHeaderImage({
    super.key,
    required this.playlistId,
    this.coverArtUrl,
    this.height = 200,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(_playlistHeaderImageProvider(playlistId));

    return pathAsync.when(
      loading: () => _placeholder(context),
      error: (_, e) => _placeholder(context),
      data: (localPath) {
        if (localPath != null && localPath.isNotEmpty) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: Image.file(
              File(localPath),
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        }
        if (coverArtUrl != null && coverArtUrl!.isNotEmpty) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: CachedNetworkImage(
              imageUrl: coverArtUrl!,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        }
        return _placeholder(context);
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: height * 0.5,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
