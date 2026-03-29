// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TracksTableTable extends TracksTable
    with TableInfo<$TracksTableTable, TracksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtUrlMeta = const VerificationMeta(
    'albumArtUrl',
  );
  @override
  late final GeneratedColumn<String> albumArtUrl = GeneratedColumn<String>(
    'album_art_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePluginIdMeta = const VerificationMeta(
    'sourcePluginId',
  );
  @override
  late final GeneratedColumn<String> sourcePluginId = GeneratedColumn<String>(
    'source_plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMetadataJsonMeta =
      const VerificationMeta('sourceMetadataJson');
  @override
  late final GeneratedColumn<String> sourceMetadataJson =
      GeneratedColumn<String>(
        'source_metadata_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    artist,
    album,
    albumArtUrl,
    durationMs,
    uri,
    sourcePluginId,
    sourceMetadataJson,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<TracksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('album_art_url')) {
      context.handle(
        _albumArtUrlMeta,
        albumArtUrl.isAcceptableOrUnknown(
          data['album_art_url']!,
          _albumArtUrlMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('uri')) {
      context.handle(
        _uriMeta,
        uri.isAcceptableOrUnknown(data['uri']!, _uriMeta),
      );
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('source_plugin_id')) {
      context.handle(
        _sourcePluginIdMeta,
        sourcePluginId.isAcceptableOrUnknown(
          data['source_plugin_id']!,
          _sourcePluginIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcePluginIdMeta);
    }
    if (data.containsKey('source_metadata_json')) {
      context.handle(
        _sourceMetadataJsonMeta,
        sourceMetadataJson.isAcceptableOrUnknown(
          data['source_metadata_json']!,
          _sourceMetadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, sourcePluginId};
  @override
  TracksTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TracksTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      albumArtUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_art_url'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      uri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uri'],
      )!,
      sourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_plugin_id'],
      )!,
      sourceMetadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_metadata_json'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $TracksTableTable createAlias(String alias) {
    return $TracksTableTable(attachedDatabase, alias);
  }
}

class TracksTableData extends DataClass implements Insertable<TracksTableData> {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumArtUrl;
  final int? durationMs;
  final String uri;
  final String sourcePluginId;
  final String sourceMetadataJson;
  final DateTime addedAt;
  const TracksTableData({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.albumArtUrl,
    this.durationMs,
    required this.uri,
    required this.sourcePluginId,
    required this.sourceMetadataJson,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || albumArtUrl != null) {
      map['album_art_url'] = Variable<String>(albumArtUrl);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['uri'] = Variable<String>(uri);
    map['source_plugin_id'] = Variable<String>(sourcePluginId);
    map['source_metadata_json'] = Variable<String>(sourceMetadataJson);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  TracksTableCompanion toCompanion(bool nullToAbsent) {
    return TracksTableCompanion(
      id: Value(id),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      albumArtUrl: albumArtUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtUrl),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      uri: Value(uri),
      sourcePluginId: Value(sourcePluginId),
      sourceMetadataJson: Value(sourceMetadataJson),
      addedAt: Value(addedAt),
    );
  }

  factory TracksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TracksTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      albumArtUrl: serializer.fromJson<String?>(json['albumArtUrl']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      uri: serializer.fromJson<String>(json['uri']),
      sourcePluginId: serializer.fromJson<String>(json['sourcePluginId']),
      sourceMetadataJson: serializer.fromJson<String>(
        json['sourceMetadataJson'],
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'albumArtUrl': serializer.toJson<String?>(albumArtUrl),
      'durationMs': serializer.toJson<int?>(durationMs),
      'uri': serializer.toJson<String>(uri),
      'sourcePluginId': serializer.toJson<String>(sourcePluginId),
      'sourceMetadataJson': serializer.toJson<String>(sourceMetadataJson),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  TracksTableData copyWith({
    String? id,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    Value<String?> albumArtUrl = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    String? uri,
    String? sourcePluginId,
    String? sourceMetadataJson,
    DateTime? addedAt,
  }) => TracksTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    album: album.present ? album.value : this.album,
    albumArtUrl: albumArtUrl.present ? albumArtUrl.value : this.albumArtUrl,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    uri: uri ?? this.uri,
    sourcePluginId: sourcePluginId ?? this.sourcePluginId,
    sourceMetadataJson: sourceMetadataJson ?? this.sourceMetadataJson,
    addedAt: addedAt ?? this.addedAt,
  );
  TracksTableData copyWithCompanion(TracksTableCompanion data) {
    return TracksTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumArtUrl: data.albumArtUrl.present
          ? data.albumArtUrl.value
          : this.albumArtUrl,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      uri: data.uri.present ? data.uri.value : this.uri,
      sourcePluginId: data.sourcePluginId.present
          ? data.sourcePluginId.value
          : this.sourcePluginId,
      sourceMetadataJson: data.sourceMetadataJson.present
          ? data.sourceMetadataJson.value
          : this.sourceMetadataJson,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TracksTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtUrl: $albumArtUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('uri: $uri, ')
          ..write('sourcePluginId: $sourcePluginId, ')
          ..write('sourceMetadataJson: $sourceMetadataJson, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    artist,
    album,
    albumArtUrl,
    durationMs,
    uri,
    sourcePluginId,
    sourceMetadataJson,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TracksTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumArtUrl == this.albumArtUrl &&
          other.durationMs == this.durationMs &&
          other.uri == this.uri &&
          other.sourcePluginId == this.sourcePluginId &&
          other.sourceMetadataJson == this.sourceMetadataJson &&
          other.addedAt == this.addedAt);
}

class TracksTableCompanion extends UpdateCompanion<TracksTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String?> albumArtUrl;
  final Value<int?> durationMs;
  final Value<String> uri;
  final Value<String> sourcePluginId;
  final Value<String> sourceMetadataJson;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const TracksTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.uri = const Value.absent(),
    this.sourcePluginId = const Value.absent(),
    this.sourceMetadataJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksTableCompanion.insert({
    required String id,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtUrl = const Value.absent(),
    this.durationMs = const Value.absent(),
    required String uri,
    required String sourcePluginId,
    this.sourceMetadataJson = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       uri = Value(uri),
       sourcePluginId = Value(sourcePluginId);
  static Insertable<TracksTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumArtUrl,
    Expression<int>? durationMs,
    Expression<String>? uri,
    Expression<String>? sourcePluginId,
    Expression<String>? sourceMetadataJson,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumArtUrl != null) 'album_art_url': albumArtUrl,
      if (durationMs != null) 'duration_ms': durationMs,
      if (uri != null) 'uri': uri,
      if (sourcePluginId != null) 'source_plugin_id': sourcePluginId,
      if (sourceMetadataJson != null)
        'source_metadata_json': sourceMetadataJson,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? album,
    Value<String?>? albumArtUrl,
    Value<int?>? durationMs,
    Value<String>? uri,
    Value<String>? sourcePluginId,
    Value<String>? sourceMetadataJson,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return TracksTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      durationMs: durationMs ?? this.durationMs,
      uri: uri ?? this.uri,
      sourcePluginId: sourcePluginId ?? this.sourcePluginId,
      sourceMetadataJson: sourceMetadataJson ?? this.sourceMetadataJson,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumArtUrl.present) {
      map['album_art_url'] = Variable<String>(albumArtUrl.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (sourcePluginId.present) {
      map['source_plugin_id'] = Variable<String>(sourcePluginId.value);
    }
    if (sourceMetadataJson.present) {
      map['source_metadata_json'] = Variable<String>(sourceMetadataJson.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtUrl: $albumArtUrl, ')
          ..write('durationMs: $durationMs, ')
          ..write('uri: $uri, ')
          ..write('sourcePluginId: $sourcePluginId, ')
          ..write('sourceMetadataJson: $sourceMetadataJson, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTableTable extends PlaylistsTable
    with TableInfo<$PlaylistsTableTable, PlaylistsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverArtUrlMeta = const VerificationMeta(
    'coverArtUrl',
  );
  @override
  late final GeneratedColumn<String> coverArtUrl = GeneratedColumn<String>(
    'cover_art_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    coverArtUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_art_url')) {
      context.handle(
        _coverArtUrlMeta,
        coverArtUrl.isAcceptableOrUnknown(
          data['cover_art_url']!,
          _coverArtUrlMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverArtUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_art_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTableTable createAlias(String alias) {
    return $PlaylistsTableTable(attachedDatabase, alias);
  }
}

class PlaylistsTableData extends DataClass
    implements Insertable<PlaylistsTableData> {
  final String id;
  final String name;
  final String? description;
  final String? coverArtUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PlaylistsTableData({
    required this.id,
    required this.name,
    this.description,
    this.coverArtUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverArtUrl != null) {
      map['cover_art_url'] = Variable<String>(coverArtUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistsTableCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsTableCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverArtUrl: coverArtUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArtUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistsTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      coverArtUrl: serializer.fromJson<String?>(json['coverArtUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'coverArtUrl': serializer.toJson<String?>(coverArtUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaylistsTableData copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> coverArtUrl = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PlaylistsTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    coverArtUrl: coverArtUrl.present ? coverArtUrl.value : this.coverArtUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistsTableData copyWithCompanion(PlaylistsTableCompanion data) {
    return PlaylistsTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      coverArtUrl: data.coverArtUrl.present
          ? data.coverArtUrl.value
          : this.coverArtUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('coverArtUrl: $coverArtUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, coverArtUrl, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistsTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.coverArtUrl == this.coverArtUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsTableCompanion extends UpdateCompanion<PlaylistsTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> coverArtUrl;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PlaylistsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.coverArtUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistsTableCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.coverArtUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<PlaylistsTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? coverArtUrl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (coverArtUrl != null) 'cover_art_url': coverArtUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? coverArtUrl,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlaylistsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverArtUrl: coverArtUrl ?? this.coverArtUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverArtUrl.present) {
      map['cover_art_url'] = Variable<String>(coverArtUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('coverArtUrl: $coverArtUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTableTable extends PlaylistTracksTable
    with TableInfo<$PlaylistTracksTableTable, PlaylistTracksTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<String> playlistId = GeneratedColumn<String>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists_table (id)',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackSourcePluginIdMeta =
      const VerificationMeta('trackSourcePluginId');
  @override
  late final GeneratedColumn<String> trackSourcePluginId =
      GeneratedColumn<String>(
        'track_source_plugin_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    trackId,
    trackSourcePluginId,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistTracksTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('track_source_plugin_id')) {
      context.handle(
        _trackSourcePluginIdMeta,
        trackSourcePluginId.isAcceptableOrUnknown(
          data['track_source_plugin_id']!,
          _trackSourcePluginIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackSourcePluginIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    playlistId,
    trackId,
    trackSourcePluginId,
  };
  @override
  PlaylistTracksTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTracksTableData(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      trackSourcePluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_source_plugin_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistTracksTableTable createAlias(String alias) {
    return $PlaylistTracksTableTable(attachedDatabase, alias);
  }
}

class PlaylistTracksTableData extends DataClass
    implements Insertable<PlaylistTracksTableData> {
  final String playlistId;
  final String trackId;
  final String trackSourcePluginId;
  final int position;
  const PlaylistTracksTableData({
    required this.playlistId,
    required this.trackId,
    required this.trackSourcePluginId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<String>(playlistId);
    map['track_id'] = Variable<String>(trackId);
    map['track_source_plugin_id'] = Variable<String>(trackSourcePluginId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistTracksTableCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksTableCompanion(
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      trackSourcePluginId: Value(trackSourcePluginId),
      position: Value(position),
    );
  }

  factory PlaylistTracksTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTracksTableData(
      playlistId: serializer.fromJson<String>(json['playlistId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      trackSourcePluginId: serializer.fromJson<String>(
        json['trackSourcePluginId'],
      ),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<String>(playlistId),
      'trackId': serializer.toJson<String>(trackId),
      'trackSourcePluginId': serializer.toJson<String>(trackSourcePluginId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistTracksTableData copyWith({
    String? playlistId,
    String? trackId,
    String? trackSourcePluginId,
    int? position,
  }) => PlaylistTracksTableData(
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    trackSourcePluginId: trackSourcePluginId ?? this.trackSourcePluginId,
    position: position ?? this.position,
  );
  PlaylistTracksTableData copyWithCompanion(PlaylistTracksTableCompanion data) {
    return PlaylistTracksTableData(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      trackSourcePluginId: data.trackSourcePluginId.present
          ? data.trackSourcePluginId.value
          : this.trackSourcePluginId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksTableData(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('trackSourcePluginId: $trackSourcePluginId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(playlistId, trackId, trackSourcePluginId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTracksTableData &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.trackSourcePluginId == this.trackSourcePluginId &&
          other.position == this.position);
}

class PlaylistTracksTableCompanion
    extends UpdateCompanion<PlaylistTracksTableData> {
  final Value<String> playlistId;
  final Value<String> trackId;
  final Value<String> trackSourcePluginId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistTracksTableCompanion({
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.trackSourcePluginId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistTracksTableCompanion.insert({
    required String playlistId,
    required String trackId,
    required String trackSourcePluginId,
    required int position,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       trackSourcePluginId = Value(trackSourcePluginId),
       position = Value(position);
  static Insertable<PlaylistTracksTableData> custom({
    Expression<String>? playlistId,
    Expression<String>? trackId,
    Expression<String>? trackSourcePluginId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (trackSourcePluginId != null)
        'track_source_plugin_id': trackSourcePluginId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistTracksTableCompanion copyWith({
    Value<String>? playlistId,
    Value<String>? trackId,
    Value<String>? trackSourcePluginId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistTracksTableCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      trackSourcePluginId: trackSourcePluginId ?? this.trackSourcePluginId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<String>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (trackSourcePluginId.present) {
      map['track_source_plugin_id'] = Variable<String>(
        trackSourcePluginId.value,
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksTableCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('trackSourcePluginId: $trackSourcePluginId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PluginConfigsTableTable extends PluginConfigsTable
    with TableInfo<$PluginConfigsTableTable, PluginConfigsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginConfigsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [pluginId, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugin_configs_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginConfigsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId, key};
  @override
  PluginConfigsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginConfigsTableData(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PluginConfigsTableTable createAlias(String alias) {
    return $PluginConfigsTableTable(attachedDatabase, alias);
  }
}

class PluginConfigsTableData extends DataClass
    implements Insertable<PluginConfigsTableData> {
  final String pluginId;
  final String key;
  final String value;
  const PluginConfigsTableData({
    required this.pluginId,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PluginConfigsTableCompanion toCompanion(bool nullToAbsent) {
    return PluginConfigsTableCompanion(
      pluginId: Value(pluginId),
      key: Value(key),
      value: Value(value),
    );
  }

  factory PluginConfigsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginConfigsTableData(
      pluginId: serializer.fromJson<String>(json['pluginId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginId': serializer.toJson<String>(pluginId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  PluginConfigsTableData copyWith({
    String? pluginId,
    String? key,
    String? value,
  }) => PluginConfigsTableData(
    pluginId: pluginId ?? this.pluginId,
    key: key ?? this.key,
    value: value ?? this.value,
  );
  PluginConfigsTableData copyWithCompanion(PluginConfigsTableCompanion data) {
    return PluginConfigsTableData(
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginConfigsTableData(')
          ..write('pluginId: $pluginId, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pluginId, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginConfigsTableData &&
          other.pluginId == this.pluginId &&
          other.key == this.key &&
          other.value == this.value);
}

class PluginConfigsTableCompanion
    extends UpdateCompanion<PluginConfigsTableData> {
  final Value<String> pluginId;
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PluginConfigsTableCompanion({
    this.pluginId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PluginConfigsTableCompanion.insert({
    required String pluginId,
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : pluginId = Value(pluginId),
       key = Value(key),
       value = Value(value);
  static Insertable<PluginConfigsTableData> custom({
    Expression<String>? pluginId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PluginConfigsTableCompanion copyWith({
    Value<String>? pluginId,
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PluginConfigsTableCompanion(
      pluginId: pluginId ?? this.pluginId,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginConfigsTableCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTableTable tracksTable = $TracksTableTable(this);
  late final $PlaylistsTableTable playlistsTable = $PlaylistsTableTable(this);
  late final $PlaylistTracksTableTable playlistTracksTable =
      $PlaylistTracksTableTable(this);
  late final $PluginConfigsTableTable pluginConfigsTable =
      $PluginConfigsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracksTable,
    playlistsTable,
    playlistTracksTable,
    pluginConfigsTable,
  ];
}

typedef $$TracksTableTableCreateCompanionBuilder =
    TracksTableCompanion Function({
      required String id,
      required String title,
      Value<String?> artist,
      Value<String?> album,
      Value<String?> albumArtUrl,
      Value<int?> durationMs,
      required String uri,
      required String sourcePluginId,
      Value<String> sourceMetadataJson,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$TracksTableTableUpdateCompanionBuilder =
    TracksTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> artist,
      Value<String?> album,
      Value<String?> albumArtUrl,
      Value<int?> durationMs,
      Value<String> uri,
      Value<String> sourcePluginId,
      Value<String> sourceMetadataJson,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$TracksTableTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTableTable> {
  $$TracksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtUrl => $composableBuilder(
    column: $table.albumArtUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMetadataJson => $composableBuilder(
    column: $table.sourceMetadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TracksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTableTable> {
  $$TracksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtUrl => $composableBuilder(
    column: $table.albumArtUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uri => $composableBuilder(
    column: $table.uri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMetadataJson => $composableBuilder(
    column: $table.sourceMetadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTableTable> {
  $$TracksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumArtUrl => $composableBuilder(
    column: $table.albumArtUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get sourcePluginId => $composableBuilder(
    column: $table.sourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceMetadataJson => $composableBuilder(
    column: $table.sourceMetadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$TracksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTableTable,
          TracksTableData,
          $$TracksTableTableFilterComposer,
          $$TracksTableTableOrderingComposer,
          $$TracksTableTableAnnotationComposer,
          $$TracksTableTableCreateCompanionBuilder,
          $$TracksTableTableUpdateCompanionBuilder,
          (
            TracksTableData,
            BaseReferences<_$AppDatabase, $TracksTableTable, TracksTableData>,
          ),
          TracksTableData,
          PrefetchHooks Function()
        > {
  $$TracksTableTableTableManager(_$AppDatabase db, $TracksTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtUrl = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<String> sourcePluginId = const Value.absent(),
                Value<String> sourceMetadataJson = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksTableCompanion(
                id: id,
                title: title,
                artist: artist,
                album: album,
                albumArtUrl: albumArtUrl,
                durationMs: durationMs,
                uri: uri,
                sourcePluginId: sourcePluginId,
                sourceMetadataJson: sourceMetadataJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String?> albumArtUrl = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required String uri,
                required String sourcePluginId,
                Value<String> sourceMetadataJson = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksTableCompanion.insert(
                id: id,
                title: title,
                artist: artist,
                album: album,
                albumArtUrl: albumArtUrl,
                durationMs: durationMs,
                uri: uri,
                sourcePluginId: sourcePluginId,
                sourceMetadataJson: sourceMetadataJson,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TracksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTableTable,
      TracksTableData,
      $$TracksTableTableFilterComposer,
      $$TracksTableTableOrderingComposer,
      $$TracksTableTableAnnotationComposer,
      $$TracksTableTableCreateCompanionBuilder,
      $$TracksTableTableUpdateCompanionBuilder,
      (
        TracksTableData,
        BaseReferences<_$AppDatabase, $TracksTableTable, TracksTableData>,
      ),
      TracksTableData,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableTableCreateCompanionBuilder =
    PlaylistsTableCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<String?> coverArtUrl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PlaylistsTableTableUpdateCompanionBuilder =
    PlaylistsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String?> coverArtUrl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PlaylistsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaylistsTableTable,
          PlaylistsTableData
        > {
  $$PlaylistsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $PlaylistTracksTableTable,
    List<PlaylistTracksTableData>
  >
  _playlistTracksTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playlistTracksTable,
        aliasName: $_aliasNameGenerator(
          db.playlistsTable.id,
          db.playlistTracksTable.playlistId,
        ),
      );

  $$PlaylistTracksTableTableProcessedTableManager get playlistTracksTableRefs {
    final manager = $$PlaylistTracksTableTableTableManager(
      $_db,
      $_db.playlistTracksTable,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistTracksTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTableTable> {
  $$PlaylistsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverArtUrl => $composableBuilder(
    column: $table.coverArtUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistTracksTableRefs(
    Expression<bool> Function($$PlaylistTracksTableTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracksTable,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTableTable> {
  $$PlaylistsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverArtUrl => $composableBuilder(
    column: $table.coverArtUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTableTable> {
  $$PlaylistsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverArtUrl => $composableBuilder(
    column: $table.coverArtUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playlistTracksTableRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playlistTracksTable,
          getReferencedColumn: (t) => t.playlistId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaylistTracksTableTableAnnotationComposer(
                $db: $db,
                $table: $db.playlistTracksTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlaylistsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTableTable,
          PlaylistsTableData,
          $$PlaylistsTableTableFilterComposer,
          $$PlaylistsTableTableOrderingComposer,
          $$PlaylistsTableTableAnnotationComposer,
          $$PlaylistsTableTableCreateCompanionBuilder,
          $$PlaylistsTableTableUpdateCompanionBuilder,
          (PlaylistsTableData, $$PlaylistsTableTableReferences),
          PlaylistsTableData,
          PrefetchHooks Function({bool playlistTracksTableRefs})
        > {
  $$PlaylistsTableTableTableManager(
    _$AppDatabase db,
    $PlaylistsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverArtUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsTableCompanion(
                id: id,
                name: name,
                description: description,
                coverArtUrl: coverArtUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> coverArtUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistsTableCompanion.insert(
                id: id,
                name: name,
                description: description,
                coverArtUrl: coverArtUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistTracksTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistTracksTableRefs) db.playlistTracksTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistTracksTableRefs)
                    await $_getPrefetchedData<
                      PlaylistsTableData,
                      $PlaylistsTableTable,
                      PlaylistTracksTableData
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableTableReferences
                          ._playlistTracksTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistTracksTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.playlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTableTable,
      PlaylistsTableData,
      $$PlaylistsTableTableFilterComposer,
      $$PlaylistsTableTableOrderingComposer,
      $$PlaylistsTableTableAnnotationComposer,
      $$PlaylistsTableTableCreateCompanionBuilder,
      $$PlaylistsTableTableUpdateCompanionBuilder,
      (PlaylistsTableData, $$PlaylistsTableTableReferences),
      PlaylistsTableData,
      PrefetchHooks Function({bool playlistTracksTableRefs})
    >;
typedef $$PlaylistTracksTableTableCreateCompanionBuilder =
    PlaylistTracksTableCompanion Function({
      required String playlistId,
      required String trackId,
      required String trackSourcePluginId,
      required int position,
      Value<int> rowid,
    });
typedef $$PlaylistTracksTableTableUpdateCompanionBuilder =
    PlaylistTracksTableCompanion Function({
      Value<String> playlistId,
      Value<String> trackId,
      Value<String> trackSourcePluginId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlaylistTracksTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaylistTracksTableTable,
          PlaylistTracksTableData
        > {
  $$PlaylistTracksTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTableTable _playlistIdTable(_$AppDatabase db) =>
      db.playlistsTable.createAlias(
        $_aliasNameGenerator(
          db.playlistTracksTable.playlistId,
          db.playlistsTable.id,
        ),
      );

  $$PlaylistsTableTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<String>('playlist_id')!;

    final manager = $$PlaylistsTableTableTableManager(
      $_db,
      $_db.playlistsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistTracksTableTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTableTable> {
  $$PlaylistTracksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackSourcePluginId => $composableBuilder(
    column: $table.trackSourcePluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableTableFilterComposer get playlistId {
    final $$PlaylistsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlistsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableTableFilterComposer(
            $db: $db,
            $table: $db.playlistsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTableTable> {
  $$PlaylistTracksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackSourcePluginId => $composableBuilder(
    column: $table.trackSourcePluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableTableOrderingComposer get playlistId {
    final $$PlaylistsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlistsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableTableOrderingComposer(
            $db: $db,
            $table: $db.playlistsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTableTable> {
  $$PlaylistTracksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get trackSourcePluginId => $composableBuilder(
    column: $table.trackSourcePluginId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableTableAnnotationComposer get playlistId {
    final $$PlaylistsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlistsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistTracksTableTable,
          PlaylistTracksTableData,
          $$PlaylistTracksTableTableFilterComposer,
          $$PlaylistTracksTableTableOrderingComposer,
          $$PlaylistTracksTableTableAnnotationComposer,
          $$PlaylistTracksTableTableCreateCompanionBuilder,
          $$PlaylistTracksTableTableUpdateCompanionBuilder,
          (PlaylistTracksTableData, $$PlaylistTracksTableTableReferences),
          PlaylistTracksTableData,
          PrefetchHooks Function({bool playlistId})
        > {
  $$PlaylistTracksTableTableTableManager(
    _$AppDatabase db,
    $PlaylistTracksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playlistId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> trackSourcePluginId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksTableCompanion(
                playlistId: playlistId,
                trackId: trackId,
                trackSourcePluginId: trackSourcePluginId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playlistId,
                required String trackId,
                required String trackSourcePluginId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksTableCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                trackSourcePluginId: trackSourcePluginId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaylistTracksTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.playlistId,
                                referencedTable:
                                    $$PlaylistTracksTableTableReferences
                                        ._playlistIdTable(db),
                                referencedColumn:
                                    $$PlaylistTracksTableTableReferences
                                        ._playlistIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistTracksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistTracksTableTable,
      PlaylistTracksTableData,
      $$PlaylistTracksTableTableFilterComposer,
      $$PlaylistTracksTableTableOrderingComposer,
      $$PlaylistTracksTableTableAnnotationComposer,
      $$PlaylistTracksTableTableCreateCompanionBuilder,
      $$PlaylistTracksTableTableUpdateCompanionBuilder,
      (PlaylistTracksTableData, $$PlaylistTracksTableTableReferences),
      PlaylistTracksTableData,
      PrefetchHooks Function({bool playlistId})
    >;
typedef $$PluginConfigsTableTableCreateCompanionBuilder =
    PluginConfigsTableCompanion Function({
      required String pluginId,
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PluginConfigsTableTableUpdateCompanionBuilder =
    PluginConfigsTableCompanion Function({
      Value<String> pluginId,
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PluginConfigsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PluginConfigsTableTable> {
  $$PluginConfigsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PluginConfigsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginConfigsTableTable> {
  $$PluginConfigsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginConfigsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginConfigsTableTable> {
  $$PluginConfigsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PluginConfigsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginConfigsTableTable,
          PluginConfigsTableData,
          $$PluginConfigsTableTableFilterComposer,
          $$PluginConfigsTableTableOrderingComposer,
          $$PluginConfigsTableTableAnnotationComposer,
          $$PluginConfigsTableTableCreateCompanionBuilder,
          $$PluginConfigsTableTableUpdateCompanionBuilder,
          (
            PluginConfigsTableData,
            BaseReferences<
              _$AppDatabase,
              $PluginConfigsTableTable,
              PluginConfigsTableData
            >,
          ),
          PluginConfigsTableData,
          PrefetchHooks Function()
        > {
  $$PluginConfigsTableTableTableManager(
    _$AppDatabase db,
    $PluginConfigsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginConfigsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginConfigsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginConfigsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PluginConfigsTableCompanion(
                pluginId: pluginId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PluginConfigsTableCompanion.insert(
                pluginId: pluginId,
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PluginConfigsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginConfigsTableTable,
      PluginConfigsTableData,
      $$PluginConfigsTableTableFilterComposer,
      $$PluginConfigsTableTableOrderingComposer,
      $$PluginConfigsTableTableAnnotationComposer,
      $$PluginConfigsTableTableCreateCompanionBuilder,
      $$PluginConfigsTableTableUpdateCompanionBuilder,
      (
        PluginConfigsTableData,
        BaseReferences<
          _$AppDatabase,
          $PluginConfigsTableTable,
          PluginConfigsTableData
        >,
      ),
      PluginConfigsTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableTableManager get tracksTable =>
      $$TracksTableTableTableManager(_db, _db.tracksTable);
  $$PlaylistsTableTableTableManager get playlistsTable =>
      $$PlaylistsTableTableTableManager(_db, _db.playlistsTable);
  $$PlaylistTracksTableTableTableManager get playlistTracksTable =>
      $$PlaylistTracksTableTableTableManager(_db, _db.playlistTracksTable);
  $$PluginConfigsTableTableTableManager get pluginConfigsTable =>
      $$PluginConfigsTableTableTableManager(_db, _db.pluginConfigsTable);
}
