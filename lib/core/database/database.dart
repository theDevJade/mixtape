import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ─── Table definitions ────────────────────────────────────────────────────────

class TracksTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtUrl => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get uri => text()();
  TextColumn get sourcePluginId => text()();
  TextColumn get sourceMetadataJson =>
      text().withDefault(const Constant('{}'))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id, sourcePluginId};
}

class PlaylistsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverArtUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PlaylistTracksTable extends Table {
  TextColumn get playlistId => text().references(PlaylistsTable, #id)();
  TextColumn get trackId => text()();
  TextColumn get trackSourcePluginId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId, trackSourcePluginId};
}

class PluginConfigsTable extends Table {
  TextColumn get pluginId => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {pluginId, key};
}

class PlayHistoryTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  TextColumn get trackSourcePluginId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumArtUrl => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get uri => text()();
  TextColumn get sourceMetadataJson =>
      text().withDefault(const Constant('{}'))();
  DateTimeColumn get playedAt => dateTime().withDefault(currentDateAndTime)();
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    TracksTable,
    PlaylistsTable,
    PlaylistTracksTable,
    PluginConfigsTable,
    PlayHistoryTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(playHistoryTable);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'mixtape_db');
  }
}
