import 'package:dio/dio.dart';

import '../source_plugin.dart';

/// Plugin for the Internet Archive (archive.org) audio collection.
///
/// Provides access to hundreds of thousands of freely streamable, full-length
/// audio files — live concerts, classical music, podcasts, radio recordings,
/// netlabels and more — all in the public domain or under open licences.
///
/// No API key or account required.
///
/// API docs: https://archive.org/advancedsearch.php
///           https://archive.org/help/json.php
class InternetArchivePlugin extends MixtapeSourcePlugin {
  static const _baseUrl = 'https://archive.org';

  Dio? _dio;

  @override
  String get id => 'com.mixtape.internet_archive';

  @override
  String get name => 'Internet Archive';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Internet_Archive_logo_and_wordmark.svg/512px-Internet_Archive_logo_and_wordmark.svg.png';

  @override
  String get description =>
      'Millions of free, full-length audio files — concerts, classical, radio & more';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.search,
    PluginCapability.browse,
    PluginCapability.stream,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'collection',
      label: 'Default Collection (optional)',
      hint:
          'e.g. GratefulDead, etree, librivoxaudio. Leave blank for all audio.',
      defaultValue: '',
    ),
  ];

  String? _collection;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _collection = config['collection']?.trim().isNotEmpty == true
        ? config['collection']!.trim()
        : null;

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
  }

  @override
  Future<bool> isConfigured() async => true;

  // ── Search ──────────────────────────────────────────────────────────────────

  @override
  Future<List<SourceResult>> search(String query) async {
    // Build the Lucene query: include user query + restrict to audio mediatype.
    final collectionClause = _collection != null
        ? ' AND collection:$_collection'
        : '';
    final luceneQuery = '($query) AND mediatype:audio$collectionClause';

    final resp = await _dio!.get(
      '/advancedsearch.php',
      queryParameters: {
        'q': luceneQuery,
        'fl[]': ['identifier', 'title', 'creator', 'description', 'date'],
        'rows': 30,
        'page': 1,
        'output': 'json',
        'sort[]': 'downloads desc',
      },
    );

    final docs = (resp.data['response']?['docs'] as List?) ?? [];
    final results = <SourceResult>[];
    for (final doc in docs) {
      final r = await _docToResult(doc as Map<String, dynamic>);
      if (r != null) results.add(r);
    }
    return results;
  }

  // ── Browse – popular audio items ─────────────────────────────────────────

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    final collectionClause = _collection != null
        ? 'collection:$_collection'
        : 'mediatype:audio';

    final resp = await _dio!.get(
      '/advancedsearch.php',
      queryParameters: {
        'q': collectionClause,
        'fl[]': ['identifier', 'title', 'creator', 'description', 'date'],
        'rows': limit,
        'page': (offset ~/ limit) + 1,
        'output': 'json',
        'sort[]': 'downloads desc',
      },
    );

    final docs = (resp.data['response']?['docs'] as List?) ?? [];
    final results = <SourceResult>[];
    for (final doc in docs) {
      final r = await _docToResult(doc as Map<String, dynamic>);
      if (r != null) results.add(r);
    }
    return results;
  }

  // ── Item details & file listing ─────────────────────────────────────────────

  /// Returns individual audio files from an Archive item.
  /// Useful for drilling into a concert recording or album.
  Future<List<SourceResult>> fetchItemFiles(String identifier) async {
    try {
      final resp = await _dio!.get('/metadata/$identifier');
      final files = (resp.data['files'] as List?) ?? [];
      final metadata = resp.data['metadata'] as Map<String, dynamic>? ?? {};

      final creator = _firstString(metadata['creator']);
      final albumTitle = _firstString(metadata['title']);
      final thumbUrl = 'https://archive.org/services/img/$identifier';

      final audioExtensions = {
        'mp3',
        'flac',
        'ogg',
        'opus',
        'wav',
        'aiff',
        'm4a',
        'mp4',
      };

      final results = <SourceResult>[];
      for (final file in files) {
        final f = file as Map<String, dynamic>;
        final name = f['name'] as String? ?? '';
        final ext = name.contains('.')
            ? name.split('.').last.toLowerCase()
            : '';
        if (!audioExtensions.contains(ext)) continue;

        final fileTitle = (f['title'] as String?)?.trim().isNotEmpty == true
            ? f['title'] as String
            : name.replaceAll(RegExp(r'\.[^.]+$'), '');

        final durationStr = f['length'] as String?;
        final duration = _parseDuration(durationStr);

        results.add(
          SourceResult(
            id: '$identifier/$name',
            title: fileTitle,
            artist: creator,
            album: albumTitle,
            thumbnailUrl: thumbUrl,
            duration: duration,
            uri: 'https://archive.org/download/$identifier/$name',
            sourcePluginId: id,
            metadata: {
              'identifier': identifier,
              'file_name': name,
              'format': f['format'],
              'size': f['size'],
            },
          ),
        );
      }
      return results;
    } on DioException {
      return [];
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Converts a top-level search result document into a SourceResult.
  /// Resolves the first streamable audio file from the item's metadata.
  Future<SourceResult?> _docToResult(Map<String, dynamic> doc) async {
    final identifier = doc['identifier'] as String?;
    if (identifier == null) return null;

    final title = _firstString(doc['title']) ?? identifier;
    final creator = _firstString(doc['creator']);
    final thumbUrl = 'https://archive.org/services/img/$identifier';

    // Prefer fetchItemFiles for rich metadata, but for search performance
    // we return a stub SourceResult pointing at the item page URI.
    // The player layer can resolve a specific file via fetchItemFiles().
    return SourceResult(
      id: identifier,
      title: title,
      artist: creator,
      thumbnailUrl: thumbUrl,
      uri: 'archive:$identifier', // resolved by fetchItemFiles at play time
      sourcePluginId: id,
      metadata: {
        'identifier': identifier,
        'description': _firstString(doc['description']),
        'date': _firstString(doc['date']),
      },
    );
  }

  /// Parses a duration string that may be "HH:MM:SS", "MM:SS", or decimal seconds.
  static Duration? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    try {
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: double.parse(parts[2]).truncate(),
        );
      } else if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: double.parse(parts[1]).truncate(),
        );
      } else {
        final secs = double.tryParse(raw);
        if (secs != null) return Duration(seconds: secs.truncate());
      }
    } catch (_) {}
    return null;
  }

  /// Extracts the first string from a field that may be a String or List.
  static String? _firstString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isNotEmpty ? value.trim() : null;
    if (value is List && value.isNotEmpty) {
      final s = value.first?.toString().trim() ?? '';
      return s.isNotEmpty ? s : null;
    }
    return null;
  }
}
