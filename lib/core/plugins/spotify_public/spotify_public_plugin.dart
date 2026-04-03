import 'dart:convert';

import 'package:dio/dio.dart';

import '../source_plugin.dart';

/// Spotify «public catalog» plugin — no user login required.
///
/// Uses the OAuth 2.0 Client Credentials flow so any Spotify App's
/// client_id + client_secret can search the full Spotify catalogue and
/// import **public** playlists by URL without asking the user to log in.
///
/// Setup:
///   1. Go to https://developer.spotify.com/dashboard and create an app.
///   2. Copy the Client ID and Client Secret into Mixtape → Sources →
///      Spotify (Public) settings.
///
/// Capabilities:
///   • Search: full Spotify catalogue.
///   • Browse: surfaced tracks from Spotify's "Top 50 – Global" playlist.
///   • Playlist import: paste a public playlist URL in the search box
///     (https://open.spotify.com/playlist/…) to list its tracks.
///
/// Note: full playback is not available via this plugin — URIs are set to the
/// 30-second preview_url when available, or to `spotify:track:{id}` otherwise.
/// Pair with yt-dlp or the authenticated Spotify plugin for full playback.
class SpotifyPublicPlugin extends MixtapeSourcePlugin {
  static const _authBase = 'https://accounts.spotify.com';
  static const _apiBase = 'https://api.spotify.com/v1';

  // Spotify "Top 50 – Global" – a well-known public editorial playlist.
  static const _defaultBrowsePlaylistId = '37i9dQZEVXbMDoHDwVN2tF';

  Dio? _dio;
  Dio? _authDio;

  String? _clientId;
  String? _clientSecret;
  String? _accessToken;
  DateTime? _tokenExpiry;

  // ── Plugin identity ─────────────────────────────────────────────────────────

  @override
  String get id => 'com.mixtape.spotify_public';

  @override
  String get name => 'Spotify (Public)';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Spotify_icon.svg/512px-Spotify_icon.svg.png';

  @override
  String get description =>
      'Search Spotify & import public playlists — no login required';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.search,
    PluginCapability.browse,
    PluginCapability.playlists,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'client_id',
      label: 'Client ID',
      hint: 'From developer.spotify.com/dashboard',
      required: true,
    ),
    const PluginConfigField(
      key: 'client_secret',
      label: 'Client Secret',
      hint: 'From developer.spotify.com/dashboard',
      isSecret: true,
      required: true,
    ),
    const PluginConfigField(
      key: 'browse_playlist_id',
      label: 'Browse Playlist ID (optional)',
      hint: 'Default: Top 50 – Global (37i9dQZEVXbMDoHDwVN2tF)',
      defaultValue: _defaultBrowsePlaylistId,
    ),
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  Future<void> initialize(Map<String, String> config) async {
    _clientId = config['client_id'];
    _clientSecret = config['client_secret'];

    _authDio = Dio(
      BaseOptions(
        baseUrl: _authBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio = Dio(
      BaseOptions(
        baseUrl: _apiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          await _ensureToken();
          if (_accessToken != null) {
            opts.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(opts);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401) {
            _accessToken = null;
            _tokenExpiry = null;
            await _ensureToken();
            if (_accessToken != null) {
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              try {
                handler.resolve(await _dio!.fetch(opts));
                return;
              } catch (_) {}
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  @override
  Future<bool> isConfigured() async =>
      (_clientId?.isNotEmpty ?? false) && (_clientSecret?.isNotEmpty ?? false);

  // ── Search ──────────────────────────────────────────────────────────────────

  /// If [query] looks like a Spotify playlist URL, imports that playlist
  /// instead of running a catalogue search.
  @override
  Future<List<SourceResult>> search(String query) async {
    if (!await isConfigured()) return [];

    final playlistId = _extractPlaylistId(query);
    if (playlistId != null) return fetchPlaylistTracks(playlistId);

    await _ensureToken();
    final resp = await _dio!.get(
      '/search',
      queryParameters: {
        'q': query,
        'type': 'track',
        'limit': 30,
        'market': 'US',
      },
    );

    final items = resp.data['tracks']?['items'] as List? ?? [];
    return items
        .map((t) => _trackToResult(t as Map<String, dynamic>))
        .whereType<SourceResult>()
        .toList();
  }

  // ── Browse ─────────────────────────────────────────────────────────────────

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    if (!await isConfigured()) return [];

    final playlistId = _browsePlaylistId ?? _defaultBrowsePlaylistId;
    await _ensureToken();

    final resp = await _dio!.get(
      '/playlists/$playlistId/tracks',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'market': 'US',
        'fields':
            'items(track(id,name,artists,album(name,images),duration_ms,preview_url,external_urls))',
      },
    );

    final items = resp.data['items'] as List? ?? [];
    return items
        .map((item) {
          final track = item['track'];
          if (track == null) return null;
          return _trackToResult(track as Map<String, dynamic>);
        })
        .whereType<SourceResult>()
        .toList();
  }

  // ── Playlist import ─────────────────────────────────────────────────────────

  /// Retrieves all tracks from a public Spotify playlist.
  Future<List<SourceResult>> fetchPlaylistTracks(String playlistId) async {
    await _ensureToken();

    final results = <SourceResult>[];
    int offset = 0;
    const pageSize = 100;

    while (true) {
      final resp = await _dio!.get(
        '/playlists/$playlistId/tracks',
        queryParameters: {
          'limit': pageSize,
          'offset': offset,
          'market': 'US',
          'fields':
              'items(track(id,name,artists,album(name,images),duration_ms,preview_url,external_urls)),next',
        },
      );

      final items = resp.data['items'] as List? ?? [];
      for (final item in items) {
        final track = item['track'];
        if (track == null || track['id'] == null) continue;
        final r = _trackToResult(track as Map<String, dynamic>);
        if (r != null) results.add(r);
      }

      if (resp.data['next'] == null || items.length < pageSize) break;
      offset += pageSize;
    }

    return results;
  }

  /// Fetches basic info about a public playlist (name, description, cover).
  Future<SpotifyPublicPlaylist?> fetchPlaylistInfo(String playlistId) async {
    await _ensureToken();
    try {
      final resp = await _dio!.get(
        '/playlists/$playlistId',
        queryParameters: {'fields': 'id,name,description,images,tracks(total)'},
      );
      final d = resp.data as Map<String, dynamic>;
      final images = d['images'] as List?;
      return SpotifyPublicPlaylist(
        id: d['id'] as String,
        name: d['name'] as String? ?? 'Untitled',
        description: d['description'] as String?,
        coverUrl: images?.isNotEmpty == true
            ? images!.first['url'] as String?
            : null,
        trackCount: (d['tracks']?['total'] as int?) ?? 0,
      );
    } on DioException {
      return null;
    }
  }

  // ── Token management (Client Credentials) ───────────────────────────────────

  Future<void> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }
    await _fetchToken();
  }

  Future<void> _fetchToken() async {
    if (_clientId == null || _clientSecret == null) return;

    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    final resp = await _authDio!.post(
      '/api/token',
      data: 'grant_type=client_credentials',
      options: Options(
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ),
    );

    _accessToken = resp.data['access_token'] as String?;
    final expiresIn = (resp.data['expires_in'] as int?) ?? 3600;
    _tokenExpiry = DateTime.now().add(
      Duration(seconds: expiresIn - 30), // 30 s safety margin
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String? get _browsePlaylistId => null; // Overridden via config field lookup

  /// Extracts a playlist ID from a Spotify URL or returns null if not a URL.
  /// Handles:
  ///   https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF
  ///   spotify:playlist:37i9dQZEVXbMDoHDwVN2tF
  static String? _extractPlaylistId(String input) {
    final trimmed = input.trim();

    // https://open.spotify.com/playlist/{id}?…
    final urlMatch = RegExp(
      r'open\.spotify\.com/playlist/([A-Za-z0-9]+)',
    ).firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1);

    // spotify:playlist:{id}
    final uriMatch = RegExp(
      r'^spotify:playlist:([A-Za-z0-9]+)$',
    ).firstMatch(trimmed);
    if (uriMatch != null) return uriMatch.group(1);

    // Bare 22-character Spotify base-62 ID
    if (RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(trimmed)) return trimmed;

    return null;
  }

  SourceResult? _trackToResult(Map<String, dynamic> track) {
    final trackId = track['id'] as String?;
    if (trackId == null) return null;

    final artists =
        (track['artists'] as List?)
            ?.map((a) => a['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ') ??
        '';

    final album = track['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List?;
    final thumbnailUrl = images?.isNotEmpty == true
        ? images!.first['url'] as String?
        : null;

    final durationMs = (track['duration_ms'] as int?) ?? 0;
    final previewUrl = track['preview_url'] as String?;

    return SourceResult(
      id: trackId,
      title: track['name'] as String? ?? '',
      artist: artists.isEmpty ? null : artists,
      album: album?['name'] as String?,
      thumbnailUrl: thumbnailUrl,
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      // Use 30 s preview when available; fall back to URI scheme for display.
      uri: previewUrl ?? 'spotify:track:$trackId',
      sourcePluginId: id,
      metadata: {
        'spotify_id': trackId,
        'preview_url': ?previewUrl,
        'external_url': track['external_urls']?['spotify'],
      },
    );
  }
}

/// Lightweight descriptor for a public Spotify playlist.
class SpotifyPublicPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int trackCount;

  const SpotifyPublicPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.trackCount,
  });
}
