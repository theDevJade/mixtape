import 'package:equatable/equatable.dart';
import 'track.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? coverArtUrl;

  /// Local file path to a custom header image (overrides coverArtUrl in UI)
  final String? headerImagePath;
  final List<Track> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverArtUrl,
    this.headerImagePath,
    this.tracks = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverArtUrl,
    String? headerImagePath,
    bool clearHeaderImage = false,
    List<Track>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      headerImagePath: clearHeaderImage
          ? null
          : headerImagePath ?? this.headerImagePath,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id];
}
