import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../../models/track.dart';

part 'tracks_dao.g.dart';

@DriftAccessor(tables: [TracksTable])
class TracksDao extends DatabaseAccessor<AppDatabase> with _$TracksDaoMixin {
  TracksDao(super.db);

  Future<List<TracksTableData>> getAllTracks() => select(tracksTable).get();

  Stream<List<TracksTableData>> watchAllTracks() => select(tracksTable).watch();

  Future<TracksTableData?> getTrack(String id, String pluginId) {
    return (select(tracksTable)
          ..where((t) => t.id.equals(id) & t.sourcePluginId.equals(pluginId)))
        .getSingleOrNull();
  }

  Future<void> upsertTrack(Track track) {
    return into(tracksTable).insertOnConflictUpdate(
      TracksTableCompanion.insert(
        id: track.id,
        title: track.title,
        artist: Value(track.artist),
        album: Value(track.album),
        albumArtUrl: Value(track.albumArtUrl),
        durationMs: Value(track.duration?.inMilliseconds),
        uri: track.uri,
        sourcePluginId: track.sourcePluginId,
        sourceMetadataJson: Value(jsonEncode(track.sourceMetadata)),
        addedAt: Value(track.addedAt ?? DateTime.now()),
      ),
    );
  }

  Future<int> deleteTrack(String id, String pluginId) {
    return (delete(tracksTable)
          ..where((t) => t.id.equals(id) & t.sourcePluginId.equals(pluginId)))
        .go();
  }

  Track mapToTrack(TracksTableData row) {
    Map<String, dynamic> metadata = {};
    try {
      metadata = jsonDecode(row.sourceMetadataJson) as Map<String, dynamic>;
    } catch (_) {}

    return Track(
      id: row.id,
      title: row.title,
      artist: row.artist,
      album: row.album,
      albumArtUrl: row.albumArtUrl,
      duration: row.durationMs != null
          ? Duration(milliseconds: row.durationMs!)
          : null,
      uri: row.uri,
      sourcePluginId: row.sourcePluginId,
      sourceMetadata: metadata,
      addedAt: row.addedAt,
    );
  }
}
