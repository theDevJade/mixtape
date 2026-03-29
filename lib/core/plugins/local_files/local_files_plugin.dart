import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../source_plugin.dart';

/// Built-in plugin: browse and play local audio files
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
  };

  @override
  Future<void> initialize(Map<String, String> config) async {}

  @override
  Future<bool> isConfigured() async => true;

  /// Opens a file picker and returns audio files as SourceResults
  Future<List<SourceResult>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return [];
    return result.files
        .where((f) => f.path != null)
        .map((f) => _fileToResult(f.path!))
        .toList();
  }

  /// Scan a directory for audio files
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
    };

    final results = <SourceResult>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (audioExtensions.contains(ext)) {
          results.add(_fileToResult(entity.path));
        }
      }
    }
    return results;
  }

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    // Browse is handled via pickFiles / scanDirectory; return empty for auto-browse
    return [];
  }

  SourceResult _fileToResult(String filePath) {
    final fileName = p.basenameWithoutExtension(filePath);
    return SourceResult(
      id: filePath,
      title: fileName,
      uri: filePath,
      sourcePluginId: id,
      metadata: {'localPath': filePath},
    );
  }
}
