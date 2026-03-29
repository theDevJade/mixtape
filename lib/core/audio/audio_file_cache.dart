import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioCacheStats {
  final int bytes;
  final int fileCount;

  const AudioCacheStats({required this.bytes, required this.fileCount});
}

class AudioFileCache {
  AudioFileCache._();

  static final AudioFileCache instance = AudioFileCache._();

  static const String _dirName = 'audio_cache';
  static const String _indexName = 'index.json';
  final Set<String> _inFlight = <String>{};

  Future<Directory> _cacheDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, _indexName));
  }

  Future<Map<String, dynamic>> _readIndex() async {
    final file = await _indexFile();
    if (!await file.exists()) return <String, dynamic>{};
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _writeIndex(Map<String, dynamic> index) async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(index));
  }

  String _hashKey(String cacheKey) {
    return sha1.convert(utf8.encode(cacheKey)).toString();
  }

  /// Maps a MIME type string to a file extension including the dot.
  String? _extFromMime(String? mime) {
    if (mime == null) return null;
    final base = mime.split(';').first.trim().toLowerCase();
    return switch (base) {
      'audio/mpeg' || 'audio/mp3' => '.mp3',
      'audio/mp4' || 'audio/x-m4a' => '.m4a',
      'video/mp4' => '.m4a', // audio-only mp4 container
      'audio/webm' || 'video/webm' => '.webm',
      'audio/ogg' || 'application/ogg' => '.ogg',
      'audio/flac' || 'audio/x-flac' => '.flac',
      'audio/aac' || 'audio/x-aac' => '.aac',
      'audio/wav' || 'audio/x-wav' => '.wav',
      'audio/opus' => '.opus',
      _ => null,
    };
  }

  /// Best-effort extension guess before making the HTTP request.
  /// Checks the `mime` query parameter (present in YouTube CDN URLs),
  /// then falls back to the URL path extension.
  String? _extHintFromUri(Uri uri) {
    final mimeParam = uri.queryParameters['mime'];
    if (mimeParam != null && mimeParam.isNotEmpty) {
      final ext = _extFromMime(Uri.decodeComponent(mimeParam));
      if (ext != null) return ext;
    }
    final pathExt = p.extension(uri.path);
    return (pathExt.isNotEmpty && pathExt.length <= 8) ? pathExt : null;
  }

  int? _expectedBytesFromUri(Uri uri) {
    for (final key in const ['clen', 'content_length', 'content-length']) {
      final raw = uri.queryParameters[key];
      if (raw == null || raw.isEmpty) continue;
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  Future<bool> _promoteTempToCache({
    required String cacheKey,
    required String sourceUri,
    required String fileName,
    required File temp,
    required File target,
    int? expectedBytes,
    required bool allowUnknownExpected,
  }) async {
    if (!await temp.exists()) return false;

    final stat = await temp.stat();
    if (stat.size <= 0) {
      await temp.delete();
      return false;
    }

    if (expectedBytes != null && expectedBytes > 0) {
      if (stat.size < expectedBytes) {
        return false;
      }
    } else if (!allowUnknownExpected) {
      return false;
    }

    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);

    final index = await _readIndex();
    index[cacheKey] = {
      'fileName': fileName,
      'sourceUri': sourceUri,
      'sizeBytes': stat.size,
      'lastAccessedMs': DateTime.now().millisecondsSinceEpoch,
    };
    await _writeIndex(index);
    return true;
  }

  Future<String?> getCachedFilePath(String cacheKey) async {
    final index = await _readIndex();
    final entry = index[cacheKey];
    if (entry is! Map<String, dynamic>) return null;

    final name = entry['fileName'] as String?;
    if (name == null || name.isEmpty) return null;

    // Evict legacy entries that were cached without an extension — they cannot
    // be reliably played back because the decoder can't identify the format.
    if (p.extension(name).isEmpty) {
      index.remove(cacheKey);
      await _writeIndex(index);
      // Also delete the orphan file if it exists.
      final dir = await _cacheDir();
      final orphan = File(p.join(dir.path, name));
      if (await orphan.exists()) await orphan.delete();
      return null;
    }

    final dir = await _cacheDir();
    final file = File(p.join(dir.path, name));
    if (!await file.exists()) {
      index.remove(cacheKey);
      await _writeIndex(index);
      return null;
    }

    try {
      final stat = await file.stat();
      entry['sizeBytes'] = stat.size;
      entry['lastAccessedMs'] = DateTime.now().millisecondsSinceEpoch;
      await _writeIndex(index);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheInBackground({
    required String cacheKey,
    required String sourceUri,
    required Map<String, String> headers,
  }) async {
    if (_inFlight.contains(cacheKey)) return;
    _inFlight.add(cacheKey);

    try {
      final existing = await getCachedFilePath(cacheKey);
      if (existing != null) return;

      final uri = Uri.tryParse(sourceUri);
      if (uri == null || !uri.hasScheme) return;

      final dir = await _cacheDir();
      final hash = _hashKey(cacheKey);
      // Use a fixed .part extension for the temp file; the final extension is
      // determined from the HTTP response Content-Type below.
      final temp = File(p.join(dir.path, '$hash.part'));

      if (await temp.exists()) {
        await temp.delete();
      }

      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        headers.forEach(request.headers.set);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return;
        }

        // Determine the file extension from Content-Type first, then fall back
        // to a pre-request hint derived from the URL (e.g. YouTube's mime= param).
        final contentTypeMime = response.headers.contentType?.mimeType;
        final ext = _extFromMime(contentTypeMime) ?? _extHintFromUri(uri) ?? '';

        if (ext.isEmpty) {
          // Cannot determine format — skip caching rather than storing an
          // unidentifiable file that will fail on playback.
          return;
        }

        final fileName = '$hash$ext';
        final target = File(p.join(dir.path, fileName));

        final expectedBytes = response.contentLength > 0
            ? response.contentLength
            : _expectedBytesFromUri(uri);

        final sink = temp.openWrite();
        try {
          await response.forEach(sink.add);
        } finally {
          await sink.flush();
          await sink.close();
        }

        await _promoteTempToCache(
          cacheKey: cacheKey,
          sourceUri: sourceUri,
          fileName: fileName,
          temp: temp,
          target: target,
          expectedBytes: expectedBytes,
          allowUnknownExpected: true,
        );
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // Cache writes are best-effort and must not break playback.
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<AudioCacheStats> getStats() async {
    final index = await _readIndex();
    final dir = await _cacheDir();

    int bytes = 0;
    int count = 0;
    final staleKeys = <String>[];

    for (final entry in index.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        staleKeys.add(entry.key);
        continue;
      }
      final name = value['fileName'] as String?;
      if (name == null || name.isEmpty) {
        staleKeys.add(entry.key);
        continue;
      }
      final file = File(p.join(dir.path, name));
      if (!await file.exists()) {
        staleKeys.add(entry.key);
        continue;
      }
      final size = (await file.stat()).size;
      if (size <= 0) {
        staleKeys.add(entry.key);
        continue;
      }
      bytes += size;
      count += 1;
      value['sizeBytes'] = size;
    }

    if (staleKeys.isNotEmpty) {
      for (final key in staleKeys) {
        index.remove(key);
      }
      await _writeIndex(index);
    }

    return AudioCacheStats(bytes: bytes, fileCount: count);
  }

  Future<int> clearAll() async {
    final stats = await getStats();
    final dir = await _cacheDir();

    if (await dir.exists()) {
      final children = await dir.list().toList();
      for (final entity in children) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }

    return stats.bytes;
  }
}
