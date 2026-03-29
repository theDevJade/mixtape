import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';
import '../../models/track.dart';

part 'playlists_dao.g.dart';

@DriftAccessor(tables: [PlaylistsTable, PlaylistTracksTable, TracksTable])
class PlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  static const _uuid = Uuid();

  Stream<List<PlaylistsTableData>> watchAllPlaylists() =>
      select(playlistsTable).watch();

  Future<List<PlaylistsTableData>> getAllPlaylists() =>
      select(playlistsTable).get();

  Future<PlaylistsTableData?> getPlaylist(String id) {
    return (select(
      playlistsTable,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<String> createPlaylist(String name, {String? description}) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await into(playlistsTable).insert(
      PlaylistsTableCompanion.insert(
        id: id,
        name: name,
        description: Value(description),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Future<void> updatePlaylist(String id, {String? name, String? description}) {
    return (update(playlistsTable)..where((p) => p.id.equals(id))).write(
      PlaylistsTableCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deletePlaylist(String id) async {
    await (delete(
      playlistTracksTable,
    )..where((pt) => pt.playlistId.equals(id))).go();
    await (delete(playlistsTable)..where((p) => p.id.equals(id))).go();
  }

  Future<void> addTrackToPlaylist(
    String playlistId,
    Track track,
    int position,
  ) async {
    await into(playlistTracksTable).insertOnConflictUpdate(
      PlaylistTracksTableCompanion.insert(
        playlistId: playlistId,
        trackId: track.id,
        trackSourcePluginId: track.sourcePluginId,
        position: position,
      ),
    );
    await (update(playlistsTable)..where((p) => p.id.equals(playlistId))).write(
      PlaylistsTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
    String pluginId,
  ) async {
    await (delete(playlistTracksTable)..where(
          (pt) =>
              pt.playlistId.equals(playlistId) &
              pt.trackId.equals(trackId) &
              pt.trackSourcePluginId.equals(pluginId),
        ))
        .go();
  }

  Future<List<PlaylistTracksTableData>> getPlaylistTracks(
    String playlistId,
  ) async {
    return (select(playlistTracksTable)
          ..where((pt) => pt.playlistId.equals(playlistId))
          ..orderBy([(pt) => OrderingTerm.asc(pt.position)]))
        .get();
  }
}
