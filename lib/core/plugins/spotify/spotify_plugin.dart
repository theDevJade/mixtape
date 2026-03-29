import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../source_plugin.dart';

/// Spotify plugin - browse & sync the user's Spotify playlists / library.
///
/// Setup:
///   1. Create an app at https://developer.spotify.com/dashboard
///   2. Add your redirect URI (e.g. com.mixtape://callback) under the app settings
///   3. Enter the Client ID in Mixtape's Sources → Spotify settings
///
/// Platform URL-scheme setup (required once per platform):
///
/// Android – add to AndroidManifest.xml activity:
/// ```xml
///   <intent-filter android:autoVerify="true">
///     <action android:name="android.intent.action.VIEW"/>
///     <category android:name="android.intent.category.DEFAULT"/>
///     <category android:name="android.intent.category.BROWSABLE"/>
///     <data android:scheme="com.mixtape" android:host="callback"/>
///   </intent-filter>
/// ```
/// iOS/macOS – add to Info.plist:
/// ```xml
/// <key>CFBundleURLTypes</key>
/// <array><dict>
///   <key>CFBundleURLSchemes</key>
///   <array><string>com.mixtape</string></array>
/// </dict></array>
/// ```
class SpotifyPlugin extends MixtapeSourcePlugin {
  static const _authBase = 'https://accounts.spotify.com';
  static const _apiBase = 'https://api.spotify.com/v1';
  static const _defaultRedirectUri = 'com.mixtape://callback';
  static const _scopes =
      'playlist-read-private playlist-read-collaborative user-library-read user-top-read';

  Dio? _dio;
  String? _clientId;
  String? _redirectUri;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // ── Plugin identity ─────────────────────────────────────────────────────────

  @override
  String get id => 'com.mixtape.spotify';

  @override
  String get name => 'Spotify';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Spotify_icon.svg/512px-Spotify_icon.svg.png';

  @override
  String get description =>
      'Browse and sync your Spotify playlists and saved tracks';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.browse,
    PluginCapability.search,
    PluginCapability.playlists,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'client_id',
      label: 'Spotify Client ID',
      hint: 'From developer.spotify.com/dashboard',
      required: true,
    ),
    const PluginConfigField(
      key: 'redirect_uri',
      label: 'Redirect URI',
      hint: 'Must match your Spotify app settings',
      defaultValue: _defaultRedirectUri,
    ),
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  Future<void> initialize(Map<String, String> config) async {
    _clientId = config['client_id'];
    _redirectUri = config['redirect_uri']?.isNotEmpty == true
        ? config['redirect_uri']
        : _defaultRedirectUri;

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
          await _ensureValidToken();
          if (_accessToken != null) {
            opts.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(opts);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401) {
            // Token expired mid-request - refresh and retry once
            await _refreshAccessToken();
            if (_accessToken != null) {
              final opts = err.requestOptions;
              opts.headers['Authorization'] = 'Bearer $_accessToken';
              try {
                final resp = await _dio!.fetch(opts);
                handler.resolve(resp);
                return;
              } catch (_) {}
            }
          }
          handler.next(err);
        },
      ),
    );

    await _loadTokens();
  }

  @override
  Future<bool> isConfigured() async =>
      _clientId != null && _clientId!.isNotEmpty;

  // ── Browse - returns saved tracks + top tracks ───────────────────────────────

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    if (!await isConfigured()) return [];
    await _ensureAuthenticated();

    final resp = await _dio!.get(
      '/me/tracks',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'market': 'from_token',
      },
    );

    final items = resp.data['items'] as List? ?? [];
    return items
        .map((item) {
          final track = item['track'] as Map<String, dynamic>;
          return _trackToResult(track);
        })
        .whereType<SourceResult>()
        .toList();
  }

  /// Returns the current user's playlists (use for playlist sync).
  Future<List<SpotifyPlaylist>> fetchPlaylists() async {
    await _ensureAuthenticated();
    final resp = await _dio!.get(
      '/me/playlists',
      queryParameters: {'limit': 50},
    );
    final items = resp.data['items'] as List? ?? [];
    return items.map((item) {
      final images = item['images'] as List?;
      return SpotifyPlaylist(
        id: item['id'] as String,
        name: item['name'] as String? ?? 'Untitled',
        description: item['description'] as String?,
        coverUrl: images?.isNotEmpty == true
            ? images!.first['url'] as String?
            : null,
        trackCount: (item['tracks']?['total'] as int?) ?? 0,
      );
    }).toList();
  }

  /// Fetches all tracks in a Spotify playlist.
  Future<List<SourceResult>> fetchPlaylistTracks(
    String spotifyPlaylistId,
  ) async {
    await _ensureAuthenticated();
    final results = <SourceResult>[];
    int offset = 0;
    const pageSize = 100;

    while (true) {
      final resp = await _dio!.get(
        '/playlists/$spotifyPlaylistId/tracks',
        queryParameters: {
          'limit': pageSize,
          'offset': offset,
          'market': 'from_token',
        },
      );
      final items = resp.data['items'] as List? ?? [];
      for (final item in items) {
        final track = item['track'];
        if (track == null || track['id'] == null) continue;
        final result = _trackToResult(track as Map<String, dynamic>);
        if (result != null) results.add(result);
      }
      if (items.length < pageSize) break;
      offset += pageSize;
    }

    return results;
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  @override
  Future<List<SourceResult>> search(String query) async {
    if (!await isConfigured()) return [];
    await _ensureAuthenticated();

    final resp = await _dio!.get(
      '/search',
      queryParameters: {
        'q': query,
        'type': 'track',
        'limit': 30,
        'market': 'from_token',
      },
    );

    final items = resp.data['tracks']?['items'] as List? ?? [];
    return items
        .map((t) => _trackToResult(t as Map<String, dynamic>))
        .whereType<SourceResult>()
        .toList();
  }

  // ── OAuth PKCE helpers ─────────────────────────────────────────────────────

  Future<void> _ensureAuthenticated() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }
    if (_refreshToken != null) {
      await _refreshAccessToken();
      if (_accessToken != null) return;
    }
    await _authenticate();
  }

  Future<void> _ensureValidToken() async {
    if (_accessToken == null) return;
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      await _refreshAccessToken();
    }
  }

  Future<void> _authenticate() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    final state = _randomString(16);

    final authUrl = Uri.parse('$_authBase/authorize').replace(
      queryParameters: {
        'client_id': _clientId!,
        'response_type': 'code',
        'redirect_uri': _redirectUri!,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'state': state,
        'scope': _scopes,
      },
    );

    final callbackUri = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: Uri.parse(_redirectUri!).scheme,
    );

    final uri = Uri.parse(callbackUri);
    final code = uri.queryParameters['code'];
    if (code == null) throw Exception('Spotify auth failed: no code returned');

    await _exchangeCode(code, verifier);
  }

  Future<void> _exchangeCode(String code, String verifier) async {
    final dio = Dio();
    final resp = await dio.post(
      '$_authBase/api/token',
      data: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri!,
        'client_id': _clientId!,
        'code_verifier': verifier,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    _storeTokenResponse(resp.data);
    await _saveTokens();
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) return;
    try {
      final dio = Dio();
      final resp = await dio.post(
        '$_authBase/api/token',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
          'client_id': _clientId!,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      _storeTokenResponse(resp.data);
      await _saveTokens();
    } catch (_) {
      // Refresh failed - clear tokens so fresh auth is triggered
      _accessToken = null;
      _refreshToken = null;
      await _saveTokens();
    }
  }

  void _storeTokenResponse(dynamic data) {
    _accessToken = data['access_token'] as String?;
    if (data['refresh_token'] != null) {
      _refreshToken = data['refresh_token'] as String;
    }
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
  }

  // ── Token persistence (SharedPreferences) ───────────────────────────────────

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) {
      await prefs.setString('${id}_access_token', _accessToken!);
    } else {
      await prefs.remove('${id}_access_token');
    }
    if (_refreshToken != null) {
      await prefs.setString('${id}_refresh_token', _refreshToken!);
    } else {
      await prefs.remove('${id}_refresh_token');
    }
    if (_tokenExpiry != null) {
      await prefs.setInt(
        '${id}_token_expiry',
        _tokenExpiry!.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('${id}_access_token');
    _refreshToken = prefs.getString('${id}_refresh_token');
    final ms = prefs.getInt('${id}_token_expiry');
    _tokenExpiry = ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  // ── PKCE utilities ─────────────────────────────────────────────────────────

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = Random.secure();
    return List.generate(64, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _randomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  // ── Data mapping ────────────────────────────────────────────────────────────

  SourceResult? _trackToResult(Map<String, dynamic> track) {
    final trackId = track['id'] as String?;
    if (trackId == null) return null;

    final artists =
        (track['artists'] as List?)
            ?.map((a) => a['name'] as String)
            .join(', ') ??
        '';
    final album = track['album'] as Map<String, dynamic>?;
    final images = album?['images'] as List?;
    final thumbnailUrl = images?.isNotEmpty == true
        ? images!.first['url'] as String?
        : null;
    final durationMs = track['duration_ms'] as int? ?? 0;

    return SourceResult(
      id: trackId,
      title: track['name'] as String? ?? '',
      artist: artists.isEmpty ? null : artists,
      album: album?['name'] as String?,
      thumbnailUrl: thumbnailUrl,
      duration: Duration(milliseconds: durationMs),
      uri: track['preview_url'] as String? ?? 'spotify:track:$trackId',
      sourcePluginId: id,
      metadata: {
        'spotify_id': trackId,
        'preview_url': track['preview_url'],
        'external_url': track['external_urls']?['spotify'],
      },
    );
  }
}

/// Lightweight data class for a Spotify playlist reference
class SpotifyPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final int trackCount;

  const SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.trackCount,
  });
}
