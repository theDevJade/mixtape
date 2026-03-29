import 'package:equatable/equatable.dart';

/// Describes capabilities a plugin supports
enum PluginCapability {
  search,
  browse,
  stream,
  localFiles,
  recommendations,
  playlists,
  streamResolve,
}

/// The result of a search or browse query
class SourceResult extends Equatable {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? thumbnailUrl;
  final Duration? duration;
  final String uri;
  final String sourcePluginId;
  final Map<String, dynamic> metadata;

  const SourceResult({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.thumbnailUrl,
    this.duration,
    required this.uri,
    required this.sourcePluginId,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [id, sourcePluginId];
}

/// Plugin configuration field definition
class PluginConfigField {
  final String key;
  final String label;
  final String? hint;
  final bool isSecret; // render as password field
  final bool required;
  final String? defaultValue;

  const PluginConfigField({
    required this.key,
    required this.label,
    this.hint,
    this.isSecret = false,
    this.required = false,
    this.defaultValue,
  });
}

/// Base class all Mixtape source plugins must extend
abstract class MixtapeSourcePlugin {
  /// Unique identifier, e.g. 'com.mixtape.jamendo'
  String get id;

  /// Human-readable name shown in UI
  String get name;

  /// Short description shown in plugin list
  String get description;

  /// Icon asset path or URL
  String? get iconUrl => null;

  /// Capabilities this plugin supports
  Set<PluginCapability> get capabilities;

  /// Configuration fields this plugin needs (API keys, etc.)
  List<PluginConfigField> get configFields => const [];

  /// Called when plugin is initialized with user-supplied config values
  Future<void> initialize(Map<String, String> config);

  /// Called to test whether the plugin is properly configured
  Future<bool> isConfigured();

  /// Returns HTTP headers required to play the resolved stream URL.
  /// Call after [resolveStreamUrl] - implementations may serve this from cache.
  Future<Map<String, String>> resolveStreamHeaders(String uri) async =>
      const {};

  /// Search for tracks - plugins that don't support search throw UnimplementedError
  Future<List<SourceResult>> search(String query) async {
    throw UnimplementedError('$name does not support search');
  }

  /// Browse featured/trending tracks
  Future<List<SourceResult>> browse({int offset = 0, int limit = 20}) async {
    throw UnimplementedError('$name does not support browse');
  }

  /// Resolve a URI to a streamable URL if needed (e.g., indirect stream URLs)
  Future<String> resolveStreamUrl(String uri) async => uri;

  /// Dispose any resources held by the plugin
  Future<void> dispose() async {}
}
