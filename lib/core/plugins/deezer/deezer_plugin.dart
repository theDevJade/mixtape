import 'package:dio/dio.dart';

import '../source_plugin.dart';

/// Plugin for the Deezer public API.
///
/// No authentication or API key is required for read-only catalog access —
/// just enable the plugin and start searching.  An optional App ID can be
/// supplied for higher rate-limits if you register at
/// https://developers.deezer.com/myapps.
///
/// Capabilities:
///   • Search: full Deezer catalogue by title, artist or album.
///   • Browse: Deezer chart (top tracks in the selected country).
///   • Stream: 30-second MP3 preview via Deezer's free preview API.
///
/// Note: full-length streaming requires a Deezer Premium account and is not
/// supported here. Preview URLs are publicly usable, royalty-free 30 s clips.
class DeezerPlugin extends MixtapeSourcePlugin {
  static const _baseUrl = 'https://api.deezer.com';

  Dio? _dio;
  String? _appId;

  @override
  String get id => 'com.mixtape.deezer';

  @override
  String get name => 'Deezer';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b8/Deezer_logo_2023.svg/512px-Deezer_logo_2023.svg.png';

  @override
  String get description =>
      'Search & preview 90 M+ tracks from Deezer — no login required';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.search,
    PluginCapability.browse,
    PluginCapability.stream,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'app_id',
      label: 'App ID (optional)',
      hint:
          'Register a free app at developers.deezer.com for higher rate limits',
    ),
    const PluginConfigField(
      key: 'country',
      label: 'Chart Country Code (optional)',
      hint: 'ISO 3166-1 alpha-2 code, e.g. US, GB, DE. Default: global chart.',
      defaultValue: '',
    ),
  ];

  @override
  Future<void> initialize(Map<String, String> config) async {
    _appId = config['app_id'];
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  @override
  Future<bool> isConfigured() async => true; // No mandatory key required

  // ── Search ──────────────────────────────────────────────────────────────────

  @override
  Future<List<SourceResult>> search(String query) async {
    final resp = await _dio!.get(
      '/search',
      queryParameters: {
        'q': query,
        'limit': 30,
        if (_appId?.isNotEmpty == true) 'app_id': _appId,
      },
    );

    final items = (resp.data['data'] as List?) ?? [];
    return items.map(_mapTrack).whereType<SourceResult>().toList();
  }

  // ── Browse – Deezer Chart ──────────────────────────────────────────────────

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    // Deezer chart endpoint: /chart or /chart/0/tracks
    final resp = await _dio!.get(
      '/chart/0/tracks',
      queryParameters: {
        'limit': limit,
        'index': offset,
        if (_appId?.isNotEmpty == true) 'app_id': _appId,
      },
    );

    final items = (resp.data['data'] as List?) ?? [];
    return items.map(_mapTrack).whereType<SourceResult>().toList();
  }

  // ── Playlist browse ─────────────────────────────────────────────────────────

  /// Fetches tracks from a public Deezer playlist by numeric ID or URL.
  ///
  /// Accepts:
  ///   • https://www.deezer.com/playlist/3155776842
  ///   • 3155776842  (bare numeric ID)
  Future<List<SourceResult>> fetchPlaylistTracks(String idOrUrl) async {
    final id = _extractPlaylistId(idOrUrl);
    if (id == null) return [];

    final results = <SourceResult>[];
    int index = 0;
    const pageSize = 100;

    while (true) {
      final resp = await _dio!.get(
        '/playlist/$id/tracks',
        queryParameters: {
          'limit': pageSize,
          'index': index,
          if (_appId?.isNotEmpty == true) 'app_id': _appId,
        },
      );

      final items = (resp.data['data'] as List?) ?? [];
      for (final item in items) {
        final r = _mapTrack(item);
        if (r != null) results.add(r);
      }

      if (items.length < pageSize) break;
      index += pageSize;
    }

    return results;
  }

  // ── Artist top tracks ───────────────────────────────────────────────────────

  /// Returns top tracks for a Deezer artist (by numeric artist ID or URL).
  Future<List<SourceResult>> fetchArtistTopTracks(String artistIdOrUrl) async {
    final id = _extractArtistId(artistIdOrUrl);
    if (id == null) return [];

    final resp = await _dio!.get(
      '/artist/$id/top',
      queryParameters: {
        'limit': 50,
        if (_appId?.isNotEmpty == true) 'app_id': _appId,
      },
    );

    final items = (resp.data['data'] as List?) ?? [];
    return items.map(_mapTrack).whereType<SourceResult>().toList();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  SourceResult? _mapTrack(dynamic item) {
    final t = item as Map<String, dynamic>?;
    if (t == null) return null;

    final trackId = t['id']?.toString();
    if (trackId == null) return null;

    final preview = t['preview'] as String?;
    if (preview == null || preview.isEmpty) {
      // No preview available for this track — still include as catalog entry.
    }

    final artist = t['artist'] as Map<String, dynamic>?;
    final album = t['album'] as Map<String, dynamic>?;
    final durationSec = (t['duration'] as int?) ?? 0;

    return SourceResult(
      id: trackId,
      title: t['title'] as String? ?? t['title_short'] as String? ?? '',
      artist: artist?['name'] as String?,
      album: album?['title'] as String?,
      thumbnailUrl:
          album?['cover_medium'] as String? ?? album?['cover'] as String?,
      duration: durationSec > 0 ? Duration(seconds: durationSec) : null,
      uri: preview ?? 'deezer:track:$trackId',
      sourcePluginId: id,
      metadata: {
        'deezer_id': trackId,
        'preview_url': ?preview,
        'link': t['link'],
        if (artist != null) 'artist_id': artist['id']?.toString(),
        if (album != null) 'album_id': album['id']?.toString(),
      },
    );
  }

  static String? _extractPlaylistId(String input) {
    final trimmed = input.trim();
    // https://www.deezer.com/playlist/3155776842
    final urlMatch = RegExp(
      r'deezer\.com(?:/[a-z]{2})?/playlist/(\d+)',
    ).firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1);
    // Bare numeric ID
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;
    return null;
  }

  static String? _extractArtistId(String input) {
    final trimmed = input.trim();
    final urlMatch = RegExp(
      r'deezer\.com(?:/[a-z]{2})?/artist/(\d+)',
    ).firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1);
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return trimmed;
    return null;
  }
}
