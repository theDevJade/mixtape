import 'package:equatable/equatable.dart';

class Track extends Equatable {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtUrl;
  final Duration? duration;
  final String uri; // streamable or local URI
  final String sourcePluginId;
  final Map<String, dynamic> sourceMetadata;
  final DateTime? addedAt;

  const Track({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumArtUrl,
    this.duration,
    required this.uri,
    required this.sourcePluginId,
    this.sourceMetadata = const {},
    this.addedAt,
  });

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    Duration? duration,
    String? uri,
    String? sourcePluginId,
    Map<String, dynamic>? sourceMetadata,
    DateTime? addedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      sourcePluginId: sourcePluginId ?? this.sourcePluginId,
      sourceMetadata: sourceMetadata ?? this.sourceMetadata,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  List<Object?> get props => [id, sourcePluginId];
}
