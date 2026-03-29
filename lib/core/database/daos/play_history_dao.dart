import 'dart:convert';
import 'package:drift/drift.dart';
import '../database.dart';
import '../../models/track.dart';

part 'play_history_dao.g.dart';

@DriftAccessor(tables: [PlayHistoryTable])
class PlayHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$PlayHistoryDaoMixin {
  PlayHistoryDao(super.db);

  Future<void> recordPlay(Track track) {
    return into(playHistoryTable).insert(
      PlayHistoryTableCompanion.insert(
        trackId: track.id,
        trackSourcePluginId: track.sourcePluginId,
        title: track.title,
        artist: Value(track.artist),
        album: Value(track.album),
        albumArtUrl: Value(track.albumArtUrl),
        durationMs: Value(track.duration?.inMilliseconds),
        uri: track.uri,
        sourceMetadataJson: Value(jsonEncode(track.sourceMetadata)),
      ),
    );
  }

  Future<List<Track>> getRecentlyPlayed({int limit = 20}) async {
    final query = select(playHistoryTable)
      ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
      ..limit(limit);
    final rows = await query.get();
    return _deduplicateAndMap(rows);
  }

  Stream<List<Track>> watchRecentlyPlayed({int limit = 20}) {
    final query = select(playHistoryTable)
      ..orderBy([(t) => OrderingTerm.desc(t.playedAt)])
      ..limit(limit);
    return query.watch().map(_deduplicateAndMap);
  }

  List<Track> _deduplicateAndMap(List<PlayHistoryTableData> rows) {
    final seen = <String>{};
    final result = <Track>[];
    for (final row in rows) {
      final key = '${row.trackId}:${row.trackSourcePluginId}';
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(_mapToTrack(row));
    }
    return result;
  }

  Track _mapToTrack(PlayHistoryTableData row) {
    Map<String, dynamic> metadata = {};
    try {
      metadata = jsonDecode(row.sourceMetadataJson) as Map<String, dynamic>;
    } catch (_) {}
    return Track(
      id: row.trackId,
      title: row.title,
      artist: row.artist,
      album: row.album,
      albumArtUrl: row.albumArtUrl,
      duration: row.durationMs != null
          ? Duration(milliseconds: row.durationMs!)
          : null,
      uri: row.uri,
      sourcePluginId: row.trackSourcePluginId,
      sourceMetadata: metadata,
      addedAt: row.playedAt,
    );
  }

  Future<int> clearHistory() {
    return delete(playHistoryTable).go();
  }
}
