import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../database/daos/tracks_dao.dart';
import '../models/track.dart';
import '../plugins/source_plugin.dart';
import '../providers.dart';
import 'audio_handler.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final audioHandlerProvider = Provider<MixtapeAudioHandler>((ref) {
  throw UnimplementedError('Override in ProviderScope overrides');
});

// ── Combined position data ──────────────────────────────────────────────────

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration totalDuration;

  const PositionData({
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
  });
}

final positionDataProvider = StreamProvider<PositionData>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
    handler.player.positionStream,
    handler.player.bufferedPositionStream,
    handler.player.durationStream,
    (pos, buf, dur) => PositionData(
      position: pos,
      bufferedPosition: buf,
      // Temporary hack: some streams report a doubled duration.
      totalDuration: _halveDuration(dur ?? Duration.zero),
    ),
  );
});

Duration _halveDuration(Duration value) {
  if (value <= Duration.zero) return Duration.zero;
  return Duration(milliseconds: value.inMilliseconds ~/ 2);
}

// ── Playback state ──────────────────────────────────────────────────────────

final isPlayingProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.player.playingStream;
});

final currentTrackProvider = StateProvider<Track?>((ref) => null);

final queueProvider = StateProvider<List<Track>>((ref) => []);

final shuffleProvider = StateProvider<bool>((ref) => false);

final repeatModeProvider = StateProvider<LoopMode>((ref) => LoopMode.off);

/// `true` while the starting track of a new play request is being resolved.
final isResolvingProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioHandlerProvider).resolvingStream;
});

/// Emits user-friendly error messages when playback fails to start.
final playbackErrorProvider = StreamProvider<String?>((ref) {
  return ref.watch(audioHandlerProvider).errorStream;
});

// ── Player service ──────────────────────────────────────────────────────────

class PlayerService {
  final MixtapeAudioHandler _handler;
  final Ref _ref;

  PlayerService(this._handler, this._ref);

  Future<void> play(Track track, {List<Track>? queue}) async {
    final q = queue ?? [track];
    _ref.read(queueProvider.notifier).state = q;
    _ref.read(currentTrackProvider.notifier).state = track;
    await _handler.playTrack(track, queue: q);
  }

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    _ref.read(queueProvider.notifier).state = tracks;
    _ref.read(currentTrackProvider.notifier).state = tracks.isNotEmpty
        ? tracks[startIndex]
        : null;
    await _handler.playQueue(tracks, startIndex: startIndex);
  }

  Future<void> pause() => _handler.pause();
  Future<void> resume() => _handler.play();
  Future<void> stop() => _handler.stop();
  Future<void> seekTo(Duration position) => _handler.seek(position);
  Future<void> skipToNext() => _handler.skipToNext();
  Future<void> skipToPrevious() => _handler.skipToPrevious();

  Future<void> addToQueue(Track track) async {
    final current = List<Track>.from(_ref.read(queueProvider));
    current.add(track);
    _ref.read(queueProvider.notifier).state = current;
    await _handler.addToQueue(track);
  }

  Future<void> playNext(Track track) async {
    final current = List<Track>.from(_ref.read(queueProvider));
    final idx = (_handler.player.currentIndex ?? 0) + 1;
    current.insert(idx, track);
    _ref.read(queueProvider.notifier).state = current;
    await _handler.playNext(track);
  }

  Future<void> toggleShuffle() async {
    final current = _ref.read(shuffleProvider);
    _ref.read(shuffleProvider.notifier).state = !current;
    await _handler.setShuffleMode(
      !current ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  Future<void> cycleRepeatMode() async {
    final current = _ref.read(repeatModeProvider);
    final next = switch (current) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _ref.read(repeatModeProvider.notifier).state = next;
    await _handler.setRepeatMode(switch (next) {
      LoopMode.one => AudioServiceRepeatMode.one,
      LoopMode.all => AudioServiceRepeatMode.all,
      LoopMode.off => AudioServiceRepeatMode.none,
    });
  }

  Future<Track?> refetchTrackMetadata(Track track) async {
    final plugin = _handler.registry[track.sourcePluginId];
    if (plugin == null) return null;
    if (!plugin.capabilities.contains(PluginCapability.search)) return null;
    if (!await plugin.isConfigured()) return null;

    final query = [track.title, track.artist]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' ');
    if (query.isEmpty) return null;

    List<SourceResult> results;
    try {
      results = await plugin.search(query);
    } catch (_) {
      return null;
    }
    if (results.isEmpty) return null;

    final best = _pickBestMatch(track, results);
    if (best == null) return null;

    final updated = track.copyWith(
      id: best.id,
      title: best.title,
      artist: best.artist,
      album: best.album,
      albumArtUrl: best.thumbnailUrl,
      duration: best.duration,
      uri: best.uri,
      sourceMetadata: best.metadata,
    );

    _handler.updateTrackMetadata(track, updated);
    _updateProviders(track, updated);
    await _updateSavedTrackIfPresent(track, updated);
    return updated;
  }

  SourceResult? _pickBestMatch(Track original, List<SourceResult> results) {
    int score(SourceResult r) {
      var s = 0;
      if (r.id == original.id) s += 100;
      if (r.uri == original.uri) s += 90;

      final titleA = _normalize(original.title);
      final titleB = _normalize(r.title);
      if (titleA == titleB) {
        s += 50;
      } else if (titleA.isNotEmpty && titleB.contains(titleA)) {
        s += 30;
      }

      final artistA = _normalize(original.artist ?? '');
      final artistB = _normalize(r.artist ?? '');
      if (artistA.isNotEmpty && artistA == artistB) {
        s += 40;
      } else if (artistA.isNotEmpty && artistB.contains(artistA)) {
        s += 20;
      }

      if (r.thumbnailUrl != null && r.thumbnailUrl!.trim().isNotEmpty) {
        s += 10;
      }
      return s;
    }

    SourceResult? best;
    var bestScore = -1;
    for (final r in results) {
      final current = score(r);
      if (current > bestScore) {
        best = r;
        bestScore = current;
      }
    }

    if (bestScore < 40) return null;
    return best;
  }

  String _normalize(String v) {
    return v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  void _updateProviders(Track previous, Track updated) {
    final current = _ref.read(currentTrackProvider);
    if (current != null &&
        current.sourcePluginId == previous.sourcePluginId &&
        (current.id == previous.id || current.uri == previous.uri)) {
      _ref.read(currentTrackProvider.notifier).state = updated;
    }

    final queue = List<Track>.from(_ref.read(queueProvider));
    var changed = false;
    for (var i = 0; i < queue.length; i++) {
      final t = queue[i];
      if (t.sourcePluginId == previous.sourcePluginId &&
          (t.id == previous.id || t.uri == previous.uri)) {
        queue[i] = updated;
        changed = true;
      }
    }
    if (changed) {
      _ref.read(queueProvider.notifier).state = queue;
    }
  }

  Future<void> _updateSavedTrackIfPresent(Track previous, Track updated) async {
    final db = _ref.read(databaseProvider);
    final dao = TracksDao(db);
    final existing = await dao.getTrack(previous.id, previous.sourcePluginId);
    if (existing == null) return;

    if (previous.id != updated.id) {
      await dao.deleteTrack(previous.id, previous.sourcePluginId);
    }
    await dao.upsertTrack(updated);
  }
}

final playerServiceProvider = Provider<PlayerService>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return PlayerService(handler, ref);
});

// ── EQ providers (Android only) ─────────────────────────────────────────────

final androidEqualizerProvider = Provider<AndroidEqualizer?>((ref) {
  return ref.watch(audioHandlerProvider).androidEqualizer;
});

final androidLoudnessEnhancerProvider = Provider<AndroidLoudnessEnhancer?>((
  ref,
) {
  return ref.watch(audioHandlerProvider).androidLoudnessEnhancer;
});
