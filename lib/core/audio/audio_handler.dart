import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'audio_file_cache.dart';
import 'duration_correction.dart' as dc;
import '../models/track.dart';
import '../plugins/plugin_registry.dart';
import '../plugins/source_plugin.dart';

void _log(Object? message) {
  developer.log('${message ?? ''}', name: 'mixtape.audio');
}

/// Our own loop-mode enum, replacing just_audio's LoopMode.
enum LoopMode { off, one, all }

/// Bridges media_kit with the system media controls via audio_service.
///
/// Queue management is handled manually (one track at a time via
/// [Player.open]) to avoid playlist-manipulation bugs.  Auto-advance is
/// driven by [Player.stream.completed].
class MixtapeAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final Player _player;
  final PluginRegistry _registry;
  final AudioFileCache _audioFileCache = AudioFileCache.instance;
  bool _cacheAudioFiles;
  double _volume; // 0.0 – 1.0 (converted to 0–100 for media_kit)
  bool _boundaryMicroFadeEnabled = false;
  Duration _boundaryMicroFadeDuration = const Duration(milliseconds: 180);
  Timer? _boundaryFadeTimer;
  int _boundaryFadeToken = 0;

  factory MixtapeAudioHandler(
    PluginRegistry registry, {
    bool cacheAudioFiles = false,
    double volume = 1.0,
    bool crossfadeEnabled = false,
    int crossfadeDurationSeconds = 0,
  }) {
    return MixtapeAudioHandler._(
      registry,
      Player(),
      cacheAudioFiles,
      volume,
      crossfadeEnabled,
      crossfadeDurationSeconds,
    );
  }

  MixtapeAudioHandler._(
    this._registry,
    this._player,
    this._cacheAudioFiles,
    this._volume,
    bool crossfadeEnabled,
    int crossfadeDurationSeconds,
  ) {
    // Push PlaybackState updates on every relevant state change.
    _player.stream.playing.listen((_) => _broadcastPlaybackState());
    _player.stream.position.listen((_) {}); // keep stream alive
    _player.stream.buffering.listen((_) => _broadcastPlaybackState());

    // Auto-advance when a track finishes.
    _player.stream.completed.listen((completed) {
      if (completed) _advance();
    });

    unawaited(_player.setVolume((_volume * 100).clamp(0, 100)));
    unawaited(
      setCrossfade(
        enabled: crossfadeEnabled,
        durationSeconds: crossfadeDurationSeconds,
      ),
    );
  }

  Track? _currentTrack;
  List<Track> _trackQueue = [];
  int _currentIndex = 0;

  // Loop / shuffle state (managed by us, not by media_kit).
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleEnabled = false;
  List<int>? _shuffleOrder;

  /// Pre-resolved sources keyed by queue index.
  final Map<int, _ResolvedSource> _resolvedSources = {};

  /// Indices currently being resolved (prevents duplicates).
  final Set<int> _resolvingIndices = {};

  /// Incremented when the queue is replaced so in‑flight resolutions for old
  /// queues discard their results.
  int _queueGeneration = 0;

  /// Per-index retry counters for resolution failures.
  final Map<int, int> _resolveRetries = {};
  static const int _maxResolveRetries = 2;

  final _resolvingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String?>.broadcast();
  final _trackChangeController = StreamController<int>.broadcast();

  int? _lastNotifiedIndex;

  /// Emits `true` while the starting track is being resolved, `false` once done.
  Stream<bool> get resolvingStream => _resolvingController.stream;

  /// Emits user-friendly error messages when playback fails.
  Stream<String?> get errorStream => _errorController.stream;

  /// Emits the new queue index on real track changes.
  Stream<int> get trackChangeStream => _trackChangeController.stream;

  // ── Streams consumed by player_service / app ──────────────────────────────

  Stream<Duration> get positionStream => _player.stream.position;
  Stream<Duration> get bufferedPositionStream => _player.stream.buffer;
  Stream<Duration?> get durationStream =>
      _player.stream.duration.map((d) => d == Duration.zero ? null : d);
  Stream<bool> get playingStream => _player.stream.playing;

  // ── State accessors ───────────────────────────────────────────────────────

  List<Track> get trackQueue => List.unmodifiable(_trackQueue);
  Track? get currentTrack => _currentTrack;
  int? get currentIndex => _trackQueue.isEmpty ? null : _currentIndex;
  Duration get position => _player.state.position;
  Duration get bufferedPosition => _player.state.buffer;
  Duration? get duration {
    final d = _player.state.duration;
    return d == Duration.zero ? null : d;
  }

  bool get playing => _player.state.playing;
  double get speed => _player.state.rate;
  PluginRegistry get registry => _registry;
  double get currentVolume => _volume;

  void setCacheAudioFiles(bool enabled) {
    _cacheAudioFiles = enabled;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_boundaryFadeTimer != null) return;
    await _player.setVolume((_volume * 100).clamp(0, 100));
    _log('[PLAYER] volume set to ${(_volume * 100).round()}%');
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final clamped = speed.clamp(0.25, 3.0);
    await _player.setRate(clamped);
    _log('[PLAYER] speed set to ${clamped}x');
  }

  Future<void> setCrossfade({
    required bool enabled,
    required int durationSeconds,
  }) async {
    _boundaryMicroFadeEnabled = enabled;
    final ms = enabled
        ? (durationSeconds <= 0
              ? 180
              : (120 + (durationSeconds * 40)).clamp(120, 360))
        : 0;
    _boundaryMicroFadeDuration = Duration(milliseconds: ms);

    if (!enabled) {
      _boundaryFadeToken++;
      _boundaryFadeTimer?.cancel();
      _boundaryFadeTimer = null;
      await _player.setVolume((_volume * 100).clamp(0, 100));
    }

    _log('[PLAYER] boundary-fade=${enabled ? 'on' : 'off'} ms=$ms');
  }

  Future<void> _applyBoundaryMicroFade() async {
    if (!_boundaryMicroFadeEnabled) return;
    if (!_player.state.playing) return;

    _boundaryFadeToken++;
    final token = _boundaryFadeToken;
    _boundaryFadeTimer?.cancel();
    _boundaryFadeTimer = null;

    final totalMs = _boundaryMicroFadeDuration.inMilliseconds;
    if (totalMs <= 0) return;

    await _player.setVolume(0);

    const stepMs = 30;
    final steps = (totalMs / stepMs).ceil().clamp(1, 20);
    var step = 0;

    _boundaryFadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (
      timer,
    ) {
      if (token != _boundaryFadeToken) {
        timer.cancel();
        return;
      }

      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      final eased = t * t * (3 - 2 * t);
      _player.setVolume((_volume * eased * 100).clamp(0, 100));

      if (step >= steps) {
        timer.cancel();
        _boundaryFadeTimer = null;
        _player.setVolume((_volume * 100).clamp(0, 100));
      }
    });
  }

  void _setResolving(bool v) {
    if (!_resolvingController.isClosed) _resolvingController.add(v);
  }

  void _setError(String msg) {
    if (!_errorController.isClosed) _errorController.add(msg);
  }

  // ── Queue management ────────────────────────────────────────────────────────

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    final q = queue ?? [track];
    final rawIdx = q.indexOf(track);
    await _startQueue(q, startIndex: rawIdx < 0 ? 0 : rawIdx);
  }

  Future<void> playQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    await _startQueue(tracks, startIndex: startIndex);
  }

  /// Resolves only the starting track immediately so playback begins fast,
  /// then pre-resolves adjacent tracks in the background.
  Future<void> _startQueue(
    List<Track> tracks, {
    required int startIndex,
  }) async {
    _trackQueue = tracks;
    _currentTrack = tracks[startIndex];
    _currentIndex = startIndex;
    _lastNotifiedIndex = null;
    _resolvedSources.clear();
    _resolvingIndices.clear();
    _resolveRetries.clear();
    _shuffleOrder = null;
    final gen = ++_queueGeneration;

    if (_shuffleEnabled) {
      _buildShuffleOrder(startIndex);
    }

    _setResolving(true);
    try {
      _log(
        '[QUEUE] start gen=$gen size=${tracks.length} startIndex=$startIndex '
        'cache=$_cacheAudioFiles volume=${(_volume * 100).round()}%',
      );
      final resolved = await _resolveSource(
        tracks[startIndex],
      ).timeout(const Duration(seconds: 30));
      _resolvedSources[startIndex] = resolved;

      await _player.open(
        Media(resolved.uri, httpHeaders: resolved.headers),
        play: true,
      );
      _log('[QUEUE] open + play ok');
      _broadcastMediaItem(tracks[startIndex]);
      _broadcastPlaybackState();
      _notifyTrackChange(startIndex);
    } on TimeoutException {
      _log('[QUEUE] start timed out while resolving first source');
      _setError('Loading timed out. Check your network connection.');
      return;
    } catch (e, st) {
      _log('[QUEUE] start failed: $e');
      _log('[QUEUE] start stack: $st');
      _setError(_friendlyError(e));
      return;
    } finally {
      _setResolving(false);
    }

    // Pre-resolve adjacent tracks in the background.
    unawaited(_preResolve(startIndex + 1, gen: gen));
    unawaited(_preResolve(startIndex + 2, gen: gen));
    if (startIndex > 0) unawaited(_preResolve(startIndex - 1, gen: gen));
  }

  /// Auto-advance to the next track when playback completes.
  Future<void> _advance() async {
    if (_trackQueue.isEmpty) return;

    if (_loopMode == LoopMode.one) {
      // Repeat the same track.
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    final nextIndex = _nextIndex();
    if (nextIndex == null) {
      // End of queue, no repeat.
      _log('[QUEUE] reached end of queue');
      _broadcastPlaybackState();
      return;
    }

    await _playIndex(nextIndex);
  }

  /// Returns the next queue index (accounting for shuffle), or null if at end
  /// with loop off.
  int? _nextIndex() {
    if (_shuffleEnabled && _shuffleOrder != null) {
      final shufflePos = _shuffleOrder!.indexOf(_currentIndex);
      final nextShufflePos = shufflePos + 1;
      if (nextShufflePos < _shuffleOrder!.length) {
        return _shuffleOrder![nextShufflePos];
      }
      if (_loopMode == LoopMode.all) {
        return _shuffleOrder![0];
      }
      return null;
    }

    final next = _currentIndex + 1;
    if (next < _trackQueue.length) return next;
    if (_loopMode == LoopMode.all) return 0;
    return null;
  }

  /// Returns the previous queue index (accounting for shuffle), or null.
  int? _previousIndex() {
    if (_shuffleEnabled && _shuffleOrder != null) {
      final shufflePos = _shuffleOrder!.indexOf(_currentIndex);
      final prevShufflePos = shufflePos - 1;
      if (prevShufflePos >= 0) {
        return _shuffleOrder![prevShufflePos];
      }
      if (_loopMode == LoopMode.all) {
        return _shuffleOrder![_shuffleOrder!.length - 1];
      }
      return null;
    }

    final prev = _currentIndex - 1;
    if (prev >= 0) return prev;
    if (_loopMode == LoopMode.all) return _trackQueue.length - 1;
    return null;
  }

  /// Resolve, open, and play the track at [index].
  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _trackQueue.length) return;
    _currentIndex = index;
    _currentTrack = _trackQueue[index];

    final gen = _queueGeneration;

    try {
      final resolved =
          _resolvedSources[index] ??
          await _resolveSource(
            _trackQueue[index],
          ).timeout(const Duration(seconds: 30));
      if (gen != _queueGeneration) return; // queue replaced while resolving
      _resolvedSources[index] = resolved;

      await _player.open(
        Media(resolved.uri, httpHeaders: resolved.headers),
        play: true,
      );
      _broadcastMediaItem(_trackQueue[index]);
      _broadcastPlaybackState();
      _notifyTrackChange(index);

      unawaited(_applyBoundaryMicroFade());

      // Pre-resolve upcoming tracks.
      unawaited(_preResolve(index + 1, gen: gen));
      unawaited(_preResolve(index + 2, gen: gen));
      unawaited(_preResolve(index + 3, gen: gen));
    } on TimeoutException {
      _log('[PLAY] timed out resolving index=$index');
      _setError('Loading timed out. Check your network connection.');
    } catch (e, st) {
      _log('[PLAY] failed index=$index: $e');
      _log('[PLAY] stack: $st');
      _setError(_friendlyError(e));
    }
  }

  void _notifyTrackChange(int index) {
    if (index == _lastNotifiedIndex) return;
    _lastNotifiedIndex = index;
    _log(
      '[INDEX] track change: index=$index title="${_trackQueue[index].title}"',
    );
    if (!_trackChangeController.isClosed) {
      _trackChangeController.add(index);
    }
  }

  void _buildShuffleOrder(int startIndex) {
    final indices = List.generate(_trackQueue.length, (i) => i);
    indices.remove(startIndex);
    indices.shuffle();
    _shuffleOrder = [startIndex, ...indices];
  }

  Future<void> addToQueue(Track track) async {
    _trackQueue.add(track);
    if (_shuffleEnabled && _shuffleOrder != null) {
      _shuffleOrder!.add(_trackQueue.length - 1);
    }
    unawaited(_preResolve(_trackQueue.length - 1, gen: _queueGeneration));
  }

  Future<void> playNext(Track track) async {
    final insertIdx = _currentIndex + 1;
    _trackQueue.insert(insertIdx, track);
    // Shift resolved sources for indices >= insertIdx.
    final shifted = <int, _ResolvedSource>{};
    for (final entry in _resolvedSources.entries) {
      shifted[entry.key >= insertIdx ? entry.key + 1 : entry.key] = entry.value;
    }
    _resolvedSources
      ..clear()
      ..addAll(shifted);
    if (_shuffleEnabled && _shuffleOrder != null) {
      // Adjust shuffle indices.
      _shuffleOrder = _shuffleOrder!
          .map((i) => i >= insertIdx ? i + 1 : i)
          .toList();
      final shufflePos = _shuffleOrder!.indexOf(_currentIndex);
      _shuffleOrder!.insert(shufflePos + 1, insertIdx);
    }
    unawaited(_preResolve(insertIdx, gen: _queueGeneration));
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _trackQueue.length) return;
    await _playIndex(index);
  }

  // ── AudioHandler overrides ──────────────────────────────────────────────────

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    final dur = _player.state.duration;
    final clamped = dur > Duration.zero
        ? Duration(
            milliseconds: position.inMilliseconds.clamp(0, dur.inMilliseconds),
          )
        : position;
    await _player.seek(clamped);
  }

  @override
  Future<void> skipToNext() async {
    final next = _nextIndex();
    if (next != null) await _playIndex(next);
  }

  @override
  Future<void> skipToPrevious() async {
    // If more than 3 seconds in, restart the current track.
    if (_player.state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prev = _previousIndex();
    if (prev != null) await _playIndex(prev);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
    if (_shuffleEnabled) {
      _buildShuffleOrder(_currentIndex);
    } else {
      _shuffleOrder = null;
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.group => LoopMode.all,
    };
  }

  // ── Resolution helpers ──────────────────────────────────────────────────────

  /// Pre-resolves the track at [index] and stores the result.
  Future<void> _preResolve(int index, {required int gen}) async {
    if (index < 0 || index >= _trackQueue.length) return;
    if (_resolvedSources.containsKey(index)) return;
    if (_resolvingIndices.contains(index)) return;
    _resolvingIndices.add(index);
    try {
      _log('[RESOLVE] begin index=$index gen=$gen');
      final resolved = await _resolveSource(
        _trackQueue[index],
      ).timeout(const Duration(seconds: 30));
      if (gen != _queueGeneration) {
        _log('[RESOLVE] discard stale gen=$gen current=$_queueGeneration');
        return;
      }
      _resolvedSources[index] = resolved;
      _log('[RESOLVE] cached index=$index');
    } catch (e, st) {
      _log('[RESOLVE] failed index=$index: $e');
      _log('[RESOLVE] stack index=$index: $st');
      final retries = _resolveRetries[index] ?? 0;
      if (retries < _maxResolveRetries && gen == _queueGeneration) {
        _resolveRetries[index] = retries + 1;
        _log('[RESOLVE] scheduling retry ${retries + 1} for index=$index');
        Future.delayed(Duration(milliseconds: 500 * (retries + 1)), () {
          if (gen == _queueGeneration) {
            _resolvingIndices.remove(index);
            unawaited(_preResolve(index, gen: gen));
          }
        });
        return;
      }
    } finally {
      _resolvingIndices.remove(index);
    }
  }

  /// Resolves a track into a playable URI + headers.
  Future<_ResolvedSource> _resolveSource(Track track) async {
    final plugin = _registry[track.sourcePluginId];
    String resolvedUri = plugin != null
        ? await plugin.resolveStreamUrl(track.uri)
        : track.uri;
    Map<String, String> headers = plugin != null
        ? await plugin.resolveStreamHeaders(track.uri)
        : const {};

    if (resolvedUri.startsWith('http')) {
      final resolvers = _registry.pluginsWithCapability(
        PluginCapability.streamResolve,
      );
      for (final resolver in resolvers) {
        if (await resolver.isConfigured()) {
          final uriBeforeResolve = resolvedUri;
          resolvedUri = await resolver.resolveStreamUrl(uriBeforeResolve);
          headers = await resolver.resolveStreamHeaders(uriBeforeResolve);

          final hintedDuration = resolver.resolvedDuration(uriBeforeResolve);
          if (hintedDuration != null) {
            _applyResolvedDurationHint(track, hintedDuration);
          }
        }
      }

      if (_isYouTubePageUrl(resolvedUri)) {
        throw Exception(
          'Cannot play YouTube page URL directly. '
          'Enable yt-dlp in Sources to resolve a playable stream URL.',
        );
      }
    }

    _log('[BUILD] uri: $resolvedUri');
    _log('[BUILD] headers: $headers');
    _log(
      '[BUILD] track="${track.title}" plugin=${track.sourcePluginId} '
      'cache=$_cacheAudioFiles platform=${Platform.operatingSystem}',
    );

    // Check file-cache before using the network.
    final cacheKey = _stableTrackKey(track);
    if (_cacheAudioFiles && resolvedUri.startsWith('http')) {
      final cachedPath = await _audioFileCache.getCachedFilePath(cacheKey);
      if (cachedPath != null) {
        _log('[BUILD] source=file-cache path=$cachedPath key=$cacheKey');
        return _ResolvedSource(uri: 'file://$cachedPath', headers: const {});
      }
    }

    // Start a background cache write for future plays.
    if (_cacheAudioFiles && resolvedUri.startsWith('http')) {
      unawaited(
        _audioFileCache.cacheInBackground(
          cacheKey: cacheKey,
          sourceUri: resolvedUri,
          headers: headers,
        ),
      );
    }

    // Normalise local-file URIs.
    if (resolvedUri.startsWith('/')) {
      return _ResolvedSource(uri: 'file://$resolvedUri', headers: const {});
    }
    if (resolvedUri.startsWith('file://')) {
      return _ResolvedSource(uri: resolvedUri, headers: const {});
    }

    return _ResolvedSource(uri: resolvedUri, headers: headers);
  }

  String _stableTrackKey(Track track) {
    final stableKey = track.id.isNotEmpty ? track.id : track.uri;
    return '${track.sourcePluginId}:$stableKey';
  }

  bool _isDurationClearlyMismatched(Duration a, Duration b) =>
      dc.isDurationClearlyMismatched(a, b);

  void _applyResolvedDurationHint(Track reference, Duration hintedDuration) {
    if (hintedDuration <= Duration.zero) return;
    final key = _stableTrackKey(reference);

    for (var i = 0; i < _trackQueue.length; i++) {
      final current = _trackQueue[i];
      if (_stableTrackKey(current) != key) continue;

      final existing = current.duration;
      final shouldReplace =
          existing == null ||
          _isDurationClearlyMismatched(existing, hintedDuration);
      if (!shouldReplace) continue;

      final updated = current.copyWith(duration: hintedDuration);
      _trackQueue[i] = updated;
      if (_currentTrack == current) {
        _currentTrack = updated;
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('-11800') ||
        s.contains('-11850') ||
        s.contains('could not be completed') ||
        s.contains('Operation Stopped')) {
      return 'Cannot play this URL - the format isn\'t supported. '
          'For YouTube links, enable yt-dlp in Sources.';
    }
    if (s.contains('yt-dlp')) return s.replaceFirst('Exception: ', '');
    if (s.contains('404')) return 'Track not found (404)';
    if (s.contains('403')) return 'Access denied (403)';
    return 'Playback error: $s';
  }

  bool _isYouTubePageUrl(String uriText) {
    final uri = Uri.tryParse(uriText);
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host == 'youtu.be' || host.endsWith('.youtu.be')) return true;
    if (host.contains('youtube.com')) {
      if (path == '/watch' ||
          path.startsWith('/shorts/') ||
          path.startsWith('/live/')) {
        return true;
      }
    }
    return false;
  }

  void _broadcastMediaItem(Track track) {
    mediaItem.add(
      MediaItem(
        id: track.uri,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        artUri: track.albumArtUrl != null
            ? Uri.parse(track.albumArtUrl!)
            : null,
      ),
    );
  }

  void updateTrackMetadata(Track previous, Track updated) {
    final idx = _trackQueue.indexWhere((t) {
      return t.sourcePluginId == previous.sourcePluginId &&
          (t.id == previous.id || t.uri == previous.uri);
    });

    if (idx >= 0) {
      _trackQueue[idx] = updated;
    }

    final current = _currentTrack;
    if (current != null &&
        current.sourcePluginId == previous.sourcePluginId &&
        (current.id == previous.id || current.uri == previous.uri)) {
      _currentTrack = updated;
      _broadcastMediaItem(updated);
    }
  }

  void _broadcastPlaybackState() {
    final isPlaying = _player.state.playing;
    final isBuffering = _player.state.buffering;
    final isCompleted = _player.state.completed;

    final processingState = isBuffering
        ? AudioProcessingState.buffering
        : isCompleted
        ? AudioProcessingState.completed
        : AudioProcessingState.ready;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: _player.state.position,
        bufferedPosition: _player.state.buffer,
        speed: _player.state.rate,
        queueIndex: _currentIndex,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    const rootId = AudioService.browsableRootId;
    const recentId = AudioService.recentRootId;

    if (parentMediaId == rootId) {
      return [
        const MediaItem(id: '__queue__', title: 'Now Playing', playable: false),
      ];
    }

    if (parentMediaId == recentId || parentMediaId == '__queue__') {
      return _trackQueue
          .map(
            (t) => MediaItem(
              id: t.uri,
              title: t.title,
              artist: t.artist,
              album: t.album,
              duration: t.duration,
              artUri: t.albumArtUrl != null
                  ? Uri.tryParse(t.albumArtUrl!)
                  : null,
            ),
          )
          .toList();
    }

    return [];
  }

  Future<void> disposePlayer() async {
    _boundaryFadeToken++;
    _boundaryFadeTimer?.cancel();
    _boundaryFadeTimer = null;
    await _player.dispose();
    await _resolvingController.close();
    await _errorController.close();
    await _trackChangeController.close();
  }
}

class _ResolvedSource {
  final String uri;
  final Map<String, String> headers;

  const _ResolvedSource({required this.uri, required this.headers});
}
