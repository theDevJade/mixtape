import 'package:dio/dio.dart';
import '../source_plugin.dart';

/// Plugin for the Jamendo API (free/open music under Creative Commons).
/// API docs: https://developer.jamendo.com/v3.0
class JamendoPlugin extends MixtapeSourcePlugin {
  static const _baseUrl = 'https://api.jamendo.com/v3.0';

  Dio? _dio;
  String? _clientId;

  @override
  String get id => 'com.mixtape.jamendo';

  @override
  String get name => 'Jamendo';

  @override
  String? get iconUrl => 'https://images.jamendo.com/jamendo-logo-black.png';

  @override
  String get description =>
      'Millions of free, Creative Commons-licensed tracks';

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
      key: 'client_id',
      label: 'Client ID',
      hint: 'Get a free API key at developer.jamendo.com',
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
      queryParameters: {
        'client_id': _clientId,
        'format': 'json',
        'search': query,
        'include': 'musicinfo',
        'imagesize': '300',
        'limit': 30,
      },
    );

    return _parseResults(resp.data);
  }

  @override
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    if (!await isConfigured()) return [];

    final resp = await _dio!.get(
      '/tracks',
      queryParameters: {
        'client_id': _clientId,
        'format': 'json',
        'order': 'popularity_total',
        'include': 'musicinfo',
        'imagesize': '300',
        'limit': limit,
        'offset': offset,
      },
    );

    return _parseResults(resp.data);
  }

  List<SourceResult> _parseResults(dynamic data) {
    final results = data['results'] as List? ?? [];
    return results.map((item) {
      final durationSec = item['duration'] as int? ?? 0;
      return SourceResult(
        id: item['id'].toString(),
        title: item['name'] as String? ?? '',
        artist: item['artist_name'] as String?,
        album: item['album_name'] as String?,
        thumbnailUrl: item['image'] as String?,
        duration: Duration(seconds: durationSec),
        uri: item['audio'] as String? ?? '',
        sourcePluginId: id,
        metadata: {
          'license': item['license_ccurl'] ?? '',
          'jamendo_url': item['shareurl'] ?? '',
        },
      );
    }).toList();
  }
}
