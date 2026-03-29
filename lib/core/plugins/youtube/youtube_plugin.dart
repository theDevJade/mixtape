import 'package:dio/dio.dart';
import '../source_plugin.dart';

/// Plugin for the YouTube Data API v3 - searches and returns YouTube music videos/songs.
/// Requires a Google API key with YouTube Data API v3 enabled.
/// Get one free at: https://console.developers.google.com/
///
/// Optionally, configure a Piped or Invidious instance URL to proxy stream
/// resolution through your own server instead of hitting YouTube directly.
/// e.g. https://pipedapi.kavin.rocks  or  https://invidious.snopyta.org
///
/// NOTE: Playback of YouTube streams in a standalone app requires compliance
/// with YouTube's Terms of Service. This plugin surfaces metadata and links
/// only; actual streaming requires a licensed player embed or YouTube Premium.
class YouTubePlugin extends MixtapeSourcePlugin {
  static const _baseUrl = 'https://www.googleapis.com/youtube/v3';

  Dio? _dio;
  Dio? _proxyDio;
  String? _apiKey;
  String? _proxyUrl; // Piped or Invidious base URL

  @override
  String get id => 'com.mixtape.youtube';

  @override
  String get name => 'YouTube Music';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/YouTube_Music_icon.svg/512px-YouTube_Music_icon.svg.png';

  @override
  String get description => 'Search YouTube for music videos and songs';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.search,
    PluginCapability.browse,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'api_key',
      label: 'Google API Key',
      hint: 'Enable YouTube Data API v3 at console.developers.google.com',
      isSecret: true,
      required: true,
    ),
    const PluginConfigField(
      key: 'proxy_url',
      label: 'Piped / Invidious URL (optional)',
      hint:
          'e.g. https://pipedapi.kavin.rocks - proxy stream resolution through your own instance',
    ),
  ];

  @override
  Future<void> initialize(Map<String, String> config) async {
    _apiKey = config['api_key'];
    _proxyUrl = config['proxy_url']?.isNotEmpty == true
        ? config['proxy_url']!.trimRight().replaceAll(RegExp(r'/$'), '')
        : null;

    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    if (_proxyUrl != null) {
      _proxyDio = Dio(
        BaseOptions(
          baseUrl: _proxyUrl!,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
    }
  }

  @override
  Future<bool> isConfigured() async => _apiKey != null && _apiKey!.isNotEmpty;

  /// Resolves a YouTube watch URL to a direct stream URL via the configured
  /// Piped/Invidious proxy. Falls back to the original URL if no proxy is set.
  @override
  Future<String> resolveStreamUrl(String uri) async {
    if (_proxyUrl == null) return uri;

    // Extract video ID from various YouTube URL formats
    final videoId = _extractVideoId(uri);
    if (videoId == null) return uri;

    try {
      // Try Piped API format first
      if (_proxyUrl!.contains('piped') || _proxyUrl!.contains('pipedapi')) {
        return await _resolveViaPiped(videoId);
      }
      // Otherwise try Invidious
      return await _resolveViaInvidious(videoId);
    } catch (_) {
      return uri; // Graceful fallback
    }
  }

  Future<String> _resolveViaPiped(String videoId) async {
    final resp = await _proxyDio!.get('/streams/$videoId');
    final audioStreams = resp.data['audioStreams'] as List?;
    if (audioStreams == null || audioStreams.isEmpty) {
      throw Exception('No audio streams');
    }
    // Pick highest quality audio-only stream
    audioStreams.sort((a, b) {
      final qa =
          int.tryParse(
            (a['bitrate'] ?? a['quality'] ?? '0').toString().replaceAll(
              RegExp(r'\D'),
              '',
            ),
          ) ??
          0;
      final qb =
          int.tryParse(
            (b['bitrate'] ?? b['quality'] ?? '0').toString().replaceAll(
              RegExp(r'\D'),
              '',
            ),
          ) ??
          0;
      return qb.compareTo(qa);
    });
    return audioStreams.first['url'] as String;
  }

  Future<String> _resolveViaInvidious(String videoId) async {
    final resp = await _proxyDio!.get(
      '/api/v1/videos/$videoId',
      queryParameters: {'fields': 'adaptiveFormats'},
    );
    final formats = resp.data['adaptiveFormats'] as List?;
    if (formats == null || formats.isEmpty) throw Exception('No formats');
    // Pick audio-only formats (no video)
    final audioOnly = formats
        .where((f) => (f['type'] as String?)?.startsWith('audio/') ?? false)
        .toList();
    if (audioOnly.isEmpty) throw Exception('No audio formats');
    audioOnly.sort((a, b) {
      final qa = (a['bitrate'] as int?) ?? 0;
      final qb = (b['bitrate'] as int?) ?? 0;
      return qb.compareTo(qa);
    });
    return audioOnly.first['url'] as String;
  }

  String? _extractVideoId(String url) {
    final patterns = [
      RegExp(r'[?&]v=([^&]+)'),
      RegExp(r'youtu\.be/([^?]+)'),
      RegExp(r'youtube\.com/embed/([^?]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  @override
  Future<List<SourceResult>> search(String query) async {
    if (!await isConfigured()) return [];

    final resp = await _dio!.get(
      '/search',
      queryParameters: {
        'key': _apiKey,
        'q': query,
        'type': 'video',
        'videoCategoryId': '10', // Music category
        'part': 'snippet',
        'maxResults': 30,
      },
    );

    return _parseSearchResults(resp.data);
  }

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    if (!await isConfigured()) return [];

    final resp = await _dio!.get(
      '/videos',
      queryParameters: {
        'key': _apiKey,
        'chart': 'mostPopular',
        'videoCategoryId': '10',
        'part': 'snippet,contentDetails',
        'maxResults': limit,
      },
    );

    return _parseVideoResults(resp.data);
  }

  List<SourceResult> _parseSearchResults(dynamic data) {
    final items = data['items'] as List? ?? [];
    return items.map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final videoId = item['id']['videoId'] as String;
      return SourceResult(
        id: videoId,
        title: snippet['title'] as String? ?? '',
        artist: snippet['channelTitle'] as String?,
        thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String?,
        uri: 'https://www.youtube.com/watch?v=$videoId',
        sourcePluginId: id,
        metadata: {
          'videoId': videoId,
          'youtubeUrl': 'https://www.youtube.com/watch?v=$videoId',
        },
      );
    }).toList();
  }

  List<SourceResult> _parseVideoResults(dynamic data) {
    final items = data['items'] as List? ?? [];
    return items.map((item) {
      final snippet = item['snippet'] as Map<String, dynamic>;
      final videoId = item['id'] as String;
      final duration = _parseDuration(
        item['contentDetails']?['duration'] as String? ?? 'PT0S',
      );
      return SourceResult(
        id: videoId,
        title: snippet['title'] as String? ?? '',
        artist: snippet['channelTitle'] as String?,
        thumbnailUrl: snippet['thumbnails']?['high']?['url'] as String?,
        duration: duration,
        uri: 'https://www.youtube.com/watch?v=$videoId',
        sourcePluginId: id,
        metadata: {'videoId': videoId},
      );
    }).toList();
  }

  Duration _parseDuration(String iso8601) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(iso8601);
    if (match == null) return Duration.zero;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }
}
