import 'package:dio/dio.dart';
import '../source_plugin.dart';

/// Plugin for the SoundCloud API.
/// Requires a SoundCloud client_id (app registration at soundcloud.com/you/apps).
class SoundCloudPlugin extends MixtapeSourcePlugin {
  static const _baseUrl = 'https://api.soundcloud.com';

  Dio? _dio;
  String? _clientId;

  @override
  String get id => 'com.mixtape.soundcloud';

  @override
  String get name => 'SoundCloud';

  @override
  String? get iconUrl =>
      'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Soundcloud_logo.svg/512px-Soundcloud_logo.svg.png';

  @override
  String get description => 'Stream tracks from SoundCloud';

  @override
  Set<PluginCapability> get capabilities => {
    PluginCapability.search,
    PluginCapability.browse,
    PluginCapability.stream,
  };

  @override
  List<PluginConfigField> get configFields => [
    const PluginConfigField(
      key: 'client_id',
      label: 'Client ID',
      hint: 'Register an app at soundcloud.com/you/apps',
      required: true,
    ),
  ];

  @override
  Future<void> initialize(Map<String, String> config) async {
    _clientId = config['client_id'];
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  @override
  Future<bool> isConfigured() async =>
      _clientId != null && _clientId!.isNotEmpty;

  @override
  Future<List<SourceResult>> search(String query) async {
    if (!await isConfigured()) return [];

    final resp = await _dio!.get(
      '/tracks',
      queryParameters: {'client_id': _clientId, 'q': query, 'limit': 30},
    );

    final items = resp.data as List? ?? [];
    return items.map(_mapTrack).toList();
  }

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    if (!await isConfigured()) return [];

    final resp = await _dio!.get(
      '/tracks',
      queryParameters: {
        'client_id': _clientId,
        'order': 'hotness',
        'limit': limit,
        'offset': offset,
      },
    );

    final items = resp.data as List? ?? [];
    return items.map(_mapTrack).toList();
  }

  @override
  Future<String> resolveStreamUrl(String uri) async {
    // SoundCloud stream URLs need client_id appended
    if (!uri.contains('stream_url') && uri.startsWith('http')) {
      return '$uri?client_id=$_clientId';
    }
    // Resolve indirect stream_url
    final resp = await _dio!.get(
      uri,
      queryParameters: {'client_id': _clientId},
      options: Options(followRedirects: false),
    );

    if (resp.statusCode == 302) {
      return resp.headers['location']?.first ?? uri;
    }
    return uri;
  }

  SourceResult _mapTrack(dynamic item) {
    final durationMs = item['duration'] as int? ?? 0;
    final artwork = (item['artwork_url'] as String?)?.replaceAll(
      'large',
      't300x300',
    );
    return SourceResult(
      id: item['id'].toString(),
      title: item['title'] as String? ?? '',
      artist: item['user']?['username'] as String?,
      thumbnailUrl: artwork,
      duration: Duration(milliseconds: durationMs),
      uri: item['stream_url'] as String? ?? '',
      sourcePluginId: id,
      metadata: {
        'permalink_url': item['permalink_url'] ?? '',
        'genre': item['genre'] ?? '',
      },
    );
  }
}
