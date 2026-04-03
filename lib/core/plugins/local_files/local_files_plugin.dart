import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../source_plugin.dart';

/// Built-in plugin: browse and play local audio files.
/// Reads ID3/Vorbis/MP4 tags via flutter_media_metadata for proper title,
/// artist, album and duration — falls back to filename parsing when metadata
/// is absent or unreadable.
class LocalFilesPlugin extends MixtapeSourcePlugin {
  @override
  String get id => 'com.mixtape.local';

  @override
  String get name => 'Local Files';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/OOjs_UI_icon_folder.svg/512px-OOjs_UI_icon_folder.svg.png';

  @override
  String get description => 'Play audio files stored on this device';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.localFiles,
    PluginCapability.browse,
    PluginCapability.search,
  };

  // In-memory index populated by pickFiles / scanDirectory
  final List<SourceResult> _index = [];

  @override
  Future<void> initialize(Map<String, String> config) async {}

  @override
  Future<bool> isConfigured() async => true;

  // ── File picking ────────────────────────────────────────────────────────────

  /// Opens a file picker and returns audio files with embedded metadata.
  Future<List<SourceResult>> pickFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (picked == null) return [];

    final results = await Future.wait(
      picked.files
          .where((f) => f.path != null)
          .map((f) => _fileToResult(f.path!)),
    );
    _mergeIntoIndex(results);
    return results;
  }

  /// Recursively scans [dirPath] for audio files and returns them with metadata.
  Future<List<SourceResult>> scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    const audioExtensions = {
      '.mp3',
      '.flac',
      '.aac',
      '.m4a',
      '.ogg',
      '.opus',
      '.wav',
      '.aiff',
      '.wma',
      '.alac',
    };

    final paths = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          audioExtensions.contains(p.extension(entity.path).toLowerCase())) {
        paths.add(entity.path);
      }
    }

    final results = await Future.wait(paths.map(_fileToResult));
    _mergeIntoIndex(results);
    return results;
  }

  // ── Browse / search ─────────────────────────────────────────────────────────

  /// Returns files that have been indexed via [pickFiles] or [scanDirectory].
  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    final sorted = List<SourceResult>.from(_index)
      ..sort((a, b) => a.title.compareTo(b.title));
    final end = (offset + limit).clamp(0, sorted.length);
    if (offset >= sorted.length) return [];
    return sorted.sublist(offset, end);
  }

  /// Case-insensitive search over indexed files by title or artist.
  @override
  Future<List<SourceResult>> search(String query) async {
    final q = query.toLowerCase();
    return _index
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              (r.artist?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  // ── Metadata ────────────────────────────────────────────────────────────────

  /// Reads embedded metadata from [filePath], falling back to filename parsing.
  Future<SourceResult> _fileToResult(String filePath) async {
    final baseName = p.basenameWithoutExtension(filePath);

    try {
      final meta = readMetadata(File(filePath), getImage: false);

      final title = meta.title?.trim().isNotEmpty == true
          ? meta.title!.trim()
          : _parseTitleFromFilename(baseName);

      final artist = meta.artist?.trim().isNotEmpty == true
          ? meta.artist!.trim()
          : _parseArtistFromFilename(baseName);

      return SourceResult(
        id: filePath,
        title: title,
        artist: artist?.isEmpty == true ? null : artist,
        album: meta.album?.trim().isNotEmpty == true
            ? meta.album!.trim()
            : null,
        duration: meta.duration,
        uri: filePath,
        sourcePluginId: id,
        metadata: {
          'localPath': filePath,
          if (meta.trackNumber != null) 'trackNumber': meta.trackNumber,
          if (meta.year != null) 'year': meta.year,
        },
      );
    } catch (_) {
      // Metadata read failed — degrade gracefully to filename-based result.
      return SourceResult(
        id: filePath,
        title: _parseTitleFromFilename(baseName),
        artist: _parseArtistFromFilename(baseName),
        uri: filePath,
        sourcePluginId: id,
        metadata: {'localPath': filePath},
      );
    }
  }

  /// "Artist - Title" → "Title"; otherwise returns name as-is.
  String _parseTitleFromFilename(String name) {
    final idx = name.indexOf(' - ');
    return idx > 0 ? name.substring(idx + 3).trim() : name;
  }

  /// "Artist - Title" → "Artist"; returns null if pattern not present.
  String? _parseArtistFromFilename(String name) {
    final idx = name.indexOf(' - ');
    return idx > 0 ? name.substring(0, idx).trim() : null;
  }

  void _mergeIntoIndex(List<SourceResult> results) {
    final existing = {for (final r in _index) r.id};
    for (final r in results) {
      if (!existing.contains(r.id)) _index.add(r);
    }
  }
}
