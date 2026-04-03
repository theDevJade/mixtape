import 'package:dio/dio.dart';

import '../source_plugin.dart';

/// Plugin for the Free Music Archive (freemusicarchive.org).
///
/// Provides access to thousands of high-quality, freely licensed tracks curated
/// by music experts. All tracks are under Creative Commons or similar open
/// licences. No API key is required for basic access; an API key provides
/// higher rate limits.
///
/// API docs: https://freemusicarchive.org/api
class FreeMusicArchivePlugin extends MixtapeSourcePlugin {
  static const _baseUrl = 'https://freemusicarchive.org/api';

  Dio? _dio;
  String? _apiKey;

  @override
  String get id => 'com.mixtape.fma';

  @override
  String get name => 'Free Music Archive';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/Free_Music_Archive_logo.svg/512px-Free_Music_Archive_logo.svg.png';

  @override
  String get description =>
      'Thousands of free, Creative Commons-licensed tracks curated by music experts';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.search,
    PluginCapability.browse,
    PluginCapability.stream,
    PluginCapability.recommendations,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'api_key',
      label: 'API Key (optional)',
      hint:
          'Request a free key at freemusicarchive.org/api for higher rate limits',
    ),
    const PluginConfigField(
      key: 'genre',
      label: 'Default Browse Genre (optional)',
      hint: 'e.g. Electronic, Classical, Hip-Hop. Leave blank for all genres.',
      defaultValue: '',
    ),
  ];

  String? _genre;

  @override
  Future<void> initialize(Map<String, String> config) async {
    _apiKey = config['api_key']?.trim().isNotEmpty == true
        ? config['api_key']!.trim()
        : null;
    _genre = config['genre']?.trim().isNotEmpty == true
        ? config['genre']!.trim()
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
    final resp = await _dio!.get(
      '/tracks.json',
      queryParameters: {
        'q': query,
        'limit': 30,
        if (_apiKey != null) 'api_key': _apiKey,
      },
    );

    return _parseDataset(resp.data);
  }

  // ── Browse ─────────────────────────────────────────────────────────────────

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    final page = (offset ~/ limit) + 1;

    final resp = await _dio!.get(
      '/tracks.json',
      queryParameters: {
        'sort': 'track_date_created',
        'order': 'DESC',
        'limit': limit,
        'page': page,
        if (_genre != null) 'genre_title': _genre,
        if (_apiKey != null) 'api_key': _apiKey,
      },
    );

    return _parseDataset(resp.data);
  }

  // ── Curated genre lists ─────────────────────────────────────────────────────

  /// Returns tracks from a specific FMA genre slug (e.g. "Electronic").
  Future<List<SourceResult>> fetchGenreTracks(
    String genre, {
    int limit = 20,
    int offset = 0,
  }) async {
    final resp = await _dio!.get(
      '/tracks.json',
      queryParameters: {
        'genre_title': genre,
        'limit': limit,
        'page': (offset ~/ limit) + 1,
        'sort': 'track_date_created',
        'order': 'DESC',
        if (_apiKey != null) 'api_key': _apiKey,
      },
    );

    return _parseDataset(resp.data);
  }

  /// Returns a list of available genre names from FMA.
  Future<List<String>> fetchGenres() async {
    try {
      final resp = await _dio!.get(
        '/genres.json',
        queryParameters: {
          'limit': 200,
          if (_apiKey != null) 'api_key': _apiKey,
        },
      );

      final dataset = (resp.data['dataset'] as List?) ?? [];
      return dataset
          .map((g) => (g as Map<String, dynamic>)['genre_title'] as String?)
          .whereType<String>()
          .toList();
    } on DioException {
      return [];
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<SourceResult> _parseDataset(dynamic data) {
    final dataset = (data['dataset'] as List?) ?? [];
    return dataset.map(_mapTrack).whereType<SourceResult>().toList();
  }

  SourceResult? _mapTrack(dynamic item) {
    final t = item as Map<String, dynamic>?;
    if (t == null) return null;

    final trackId = t['track_id']?.toString();
    if (trackId == null) return null;

    final streamUrl = t['track_url'] as String?;
    // FMA redirects /play/track/{id} to the actual MP3
    final uri = streamUrl ?? 'https://freemusicarchive.org/play/track/$trackId';

    // Duration: "MM:SS" or "ss" string
    final durationStr = t['track_duration'] as String?;
    Duration? duration;
    if (durationStr != null && durationStr.contains(':')) {
      final parts = durationStr.split(':');
      if (parts.length == 2) {
        duration = Duration(
          minutes: int.tryParse(parts[0]) ?? 0,
          seconds: int.tryParse(parts[1]) ?? 0,
        );
      } else if (parts.length == 3) {
        duration = Duration(
          hours: int.tryParse(parts[0]) ?? 0,
          minutes: int.tryParse(parts[1]) ?? 0,
          seconds: int.tryParse(parts[2]) ?? 0,
        );
      }
    }

    final imageUrl = t['track_image_file'] as String?;

    return SourceResult(
      id: trackId,
      title: t['track_title'] as String? ?? '',
      artist: t['artist_name'] as String?,
      album: t['album_title'] as String?,
      thumbnailUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
      duration: duration,
      uri: uri,
      sourcePluginId: id,
      metadata: {
        'fma_id': trackId,
        'license': t['license_title'],
        'genre': t['track_genres'],
        'plays': t['track_listens'],
        'downloads': t['track_downloads'],
        'url': t['track_url'],
      },
    );
  }
}
