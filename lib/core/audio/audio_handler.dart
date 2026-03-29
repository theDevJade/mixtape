import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_file_cache.dart';
import '../models/track.dart';
import '../plugins/plugin_registry.dart';
import '../plugins/source_plugin.dart';

void _log(Object? message) {
  developer.log('${message ?? ''}', name: 'mixtape.audio');
}

/// Bridges just_audio with the system media controls via audio_service.
///
/// On Android, an [AndroidEqualizer] and [AndroidLoudnessEnhancer] are wired
/// into the [AudioPipeline] and exposed as public fields so the EQ screen can
/// modify them. On all other platforms these fields are null.
class MixtapeAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player;
  final PluginRegistry _registry;
  final AudioFileCache _audioFileCache = AudioFileCache.instance;
  final StreamProxy _proxy = StreamProxy();
  bool _cacheAudioFiles;
  double _volume;

  /// Non-null on Android only.
  final AndroidEqualizer? androidEqualizer;

  /// Non-null on Android only.
  final AndroidLoudnessEnhancer? androidLoudnessEnhancer;

  factory MixtapeAudioHandler(
    PluginRegistry registry, {
    bool cacheAudioFiles = false,
    double volume = 1.0,
  }) {
    if (Platform.isAndroid) {
      final eq = AndroidEqualizer();
      final loudness = AndroidLoudnessEnhancer();
      final player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [eq, loudness]),
      );
      return MixtapeAudioHandler._(
        registry,
        player,
        eq,
        loudness,
        cacheAudioFiles,
        volume,
      );
    }
    return MixtapeAudioHandler._(
      registry,
      AudioPlayer(),
      null,
      null,
      cacheAudioFiles,
      volume,
    );
  }

  MixtapeAudioHandler._(
    this._registry,
    this._player,
    this.androidEqualizer,
    this.androidLoudnessEnhancer,
    this._cacheAudioFiles,
    this._volume,
  ) {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    unawaited(_player.setVolume(_volume.clamp(0.0, 1.0)));
    _player.playbackEventStream.listen((event) {
      _log(
        '[PLAYER] event state=${_player.processingState.name} '
        'index=${event.currentIndex} '
        'pos=${event.updatePosition.inMilliseconds}ms '
        'buf=${event.bufferedPosition.inMilliseconds}ms '
        'duration=${event.duration?.inMilliseconds ?? -1}ms',
      );
    });
    _player.currentIndexStream.listen(_onIndexChanged);
  }

  Track? _currentTrack;
  List<Track> _trackQueue = [];

  /// Underlying concat source - allows inserting/removing tracks without
  /// rebuilding the entire playlist and interrupting playback.
  // ignore: deprecated_member_use
  ConcatenatingAudioSource? _concatSource;

  /// Parallel list tracking which queue indices have been fully resolved.
  List<bool> _resolved = [];

  /// Indices currently being resolved (prevents duplicate resolution).
  final Set<int> _resolvingIndices = {};

  /// Incremented when the queue is replaced, so in-flight resolutions for
  /// old queues know to discard their results.
  int _queueGeneration = 0;

  final _resolvingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String?>.broadcast();

  /// Emits `true` while the starting track is being resolved, `false` once done.
  Stream<bool> get resolvingStream => _resolvingController.stream;

  /// Emits user-friendly error messages when playback fails.
  Stream<String?> get errorStream => _errorController.stream;

  List<Track> get trackQueue => List.unmodifiable(_trackQueue);
  Track? get currentTrack => _currentTrack;
  AudioPlayer get player => _player;
  PluginRegistry get registry => _registry;

  void setCacheAudioFiles(bool enabled) {
    _cacheAudioFiles = enabled;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    _log('[PLAYER] volume set to ${(_volume * 100).round()}%');
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
  /// then resolves the rest in the background via [_resolveAtIndex].
  Future<void> _startQueue(
    List<Track> tracks, {
    required int startIndex,
  }) async {
    _trackQueue = tracks;
    _currentTrack = tracks[startIndex];
    _resolved = List.filled(tracks.length, false);
    _resolvingIndices.clear();
    final gen = ++_queueGeneration;

    _setResolving(true);
    try {
      _log(
        '[QUEUE] start gen=$gen size=${tracks.length} startIndex=$startIndex '
        'cache=$_cacheAudioFiles volume=${(_volume * 100).round()}%',
      );
      final startSource = await _buildSource(
        tracks[startIndex],
      ).timeout(const Duration(seconds: 30));
      _resolved[startIndex] = true;

      // Non-starting tracks use their raw URI as a placeholder; they'll be
      // swapped to resolved sources by _resolveAtIndex before being played.
      final sources = <AudioSource>[
        for (int i = 0; i < tracks.length; i++)
          i == startIndex ? startSource : _rawSource(tracks[i]),
      ];

      // ignore: deprecated_member_use
      _concatSource = ConcatenatingAudioSource(children: sources);
      await _player.setAudioSource(_concatSource!, initialIndex: startIndex);
      _log('[QUEUE] setAudioSource ok, starting playback');
      await _player.play();
      _log('[QUEUE] play() invoked successfully');
      _broadcastMediaItem(tracks[startIndex]);
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

    // Pre-resolve the immediately adjacent tracks in the background.
    unawaited(_resolveAtIndex(startIndex + 1, gen: gen));
    unawaited(_resolveAtIndex(startIndex + 2, gen: gen));
    if (startIndex > 0) unawaited(_resolveAtIndex(startIndex - 1, gen: gen));
  }

  Future<void> addToQueue(Track track) async {
    _trackQueue.add(track);
    _resolved.add(false);
    final concat = _concatSource;
    if (concat != null) {
      final newIdx = _trackQueue.length - 1;
      await concat.add(_rawSource(track));
      unawaited(_resolveAtIndex(newIdx, gen: _queueGeneration));
    }
  }

  Future<void> playNext(Track track) async {
    final currentIdx = _player.currentIndex ?? 0;
    final insertIdx = currentIdx + 1;
    _trackQueue.insert(insertIdx, track);
    _resolved.insert(insertIdx, false);
    final concat = _concatSource;
    if (concat != null) {
      await concat.insert(insertIdx, _rawSource(track));
      unawaited(_resolveAtIndex(insertIdx, gen: _queueGeneration));
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _trackQueue.length) return;
    await _player.seek(Duration.zero, index: index);
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
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffleModeEnabled(
      shuffleMode != AudioServiceShuffleMode.none,
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.group => LoopMode.all,
    };
    await _player.setLoopMode(loopMode);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Resolves track N in the background and replaces its placeholder in the
  /// concat source.  Silently skips if already resolved or being resolved.
  Future<void> _resolveAtIndex(int index, {required int gen}) async {
    if (index < 0 || index >= _trackQueue.length) return;
    if (index < _resolved.length && _resolved[index]) return;
    if (_resolvingIndices.contains(index)) return;
    _resolvingIndices.add(index);
    try {
      _log('[RESOLVE] begin index=$index gen=$gen');
      final source = await _buildSource(
        _trackQueue[index],
      ).timeout(const Duration(seconds: 30));
      // Discard if the queue was replaced while we were resolving.
      if (gen != _queueGeneration) {
        _log(
          '[RESOLVE] discard index=$index stale generation '
          'resolvedGen=$gen currentGen=$_queueGeneration',
        );
        return;
      }
      final concat = _concatSource;
      if (concat != null && index < concat.length) {
        await concat.removeAt(index);
        await concat.insert(index, source);
        if (index < _resolved.length) _resolved[index] = true;
        _log('[RESOLVE] swapped index=$index into concat source');
      }
    } catch (e, st) {
      _log('[RESOLVE] failed index=$index: $e');
      _log('[RESOLVE] stack index=$index: $st');
      // Resolution failed; the track will surface an error when played.
    } finally {
      _resolvingIndices.remove(index);
    }
  }

  /// Returns an [AudioSource] using the track's raw URI - no plugin resolution.
  /// Used as a placeholder until [_resolveAtIndex] swaps it for the real stream.
  AudioSource _rawSource(Track track) {
    final uri = track.uri;
    if (uri.startsWith('/')) return AudioSource.uri(Uri.parse('file://$uri'));
    if (uri.startsWith('file://')) return AudioSource.uri(Uri.parse(uri));
    return AudioSource.uri(Uri.parse(uri));
  }

  Future<AudioSource> _buildSource(Track track) async {
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
        }
      }

      // A YouTube page URL is not a playable media stream. If it stayed as a
      // page URL after stream resolvers, fail early with an actionable message.
      if (_isYouTubePageUrl(resolvedUri)) {
        throw Exception(
          'Cannot play YouTube page URL directly. '
          'Enable yt-dlp in Sources to resolve a playable stream URL.',
        );
      }
    }

    _log('[BUILD] uri: $resolvedUri');
    _log('[BUILD] headers: $headers'); // <-- are headers populated?
    _log('[BUILD] isHttp: ${resolvedUri.startsWith('http')}');
    _log(
      '[BUILD] track="${track.title}" plugin=${track.sourcePluginId} '
      'cache=$_cacheAudioFiles platform=${Platform.operatingSystem}',
    );

    if (resolvedUri.startsWith('/')) {
      return AudioSource.uri(Uri.parse('file://$resolvedUri'));
    }
    if (resolvedUri.startsWith('file://')) {
      return AudioSource.uri(Uri.parse(resolvedUri));
    }

    final stableTrackKey = track.id.isNotEmpty ? track.id : track.uri;
    final cacheKey = '${track.sourcePluginId}:$stableTrackKey';
    if (_cacheAudioFiles && resolvedUri.startsWith('http')) {
      final cachedPath = await _audioFileCache.getCachedFilePath(cacheKey);
      if (cachedPath != null) {
        _log('[BUILD] source=file-cache path=$cachedPath key=$cacheKey');
        return AudioSource.uri(Uri.file(cachedPath));
      }
    }

    var playbackUri = resolvedUri;
    var playbackHeaders = headers;

    // AVPlayer on macOS/iOS may ignore custom HTTP headers; route through a
    // local proxy that injects them before forwarding to the real source.
    if (headers.isNotEmpty && (Platform.isMacOS || Platform.isIOS)) {
      playbackUri = await _proxy.serve(resolvedUri, headers);
      playbackHeaders = const {};
      _log('[BUILD] using proxy uri=$playbackUri');
    }

    // Start a background cache write for future plays.
    if (_cacheAudioFiles && playbackUri.startsWith('http')) {
      unawaited(
        _audioFileCache.cacheInBackground(
          cacheKey: cacheKey,
          sourceUri: resolvedUri,
          headers: headers,
        ),
      );
    }

    _log(
      '[BUILD] source=AudioSource.uri uri=$playbackUri '
      'headers=${playbackHeaders.keys.toList()}',
    );

    return AudioSource.uri(
      Uri.parse(playbackUri),
      headers: playbackHeaders.isEmpty ? null : playbackHeaders,
    );
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

  void _onIndexChanged(int? index) {
    if (index != null && index < _trackQueue.length) {
      _currentTrack = _trackQueue[index];
      _broadcastMediaItem(_trackQueue[index]);
      // Eagerly resolve N+1, N+2, and N+3 so they're ready before the user reaches them.
      final gen = _queueGeneration;
      unawaited(_resolveAtIndex(index + 1, gen: gen));
      unawaited(_resolveAtIndex(index + 2, gen: gen));
      unawaited(_resolveAtIndex(index + 3, gen: gen));
    }
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

  PlaybackState _transformEvent(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
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
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }

  /// Called by Android Auto / MediaBrowserService to populate the media tree.
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
    await _player.dispose();
    await _proxy.close();
    await _resolvingController.close();
    await _errorController.close();
  }
}

/// Local HTTP proxy used to inject headers for platforms where AVPlayer does
/// not reliably forward `AudioSource.uri(headers: ...)` values.
class StreamProxy {
  HttpServer? _server;
  final Map<String, _ProxyTarget> _targets = {};
  int _nextId = 0;

  static const String _upstreamClosedMsg =
      'Connection closed while receiving data';

  Future<String> serve(String url, Map<String, String> headers) async {
    await _ensureServer();
    final id = (++_nextId).toString();
    _targets[id] = _ProxyTarget(url: url, headers: Map.of(headers));
    final local = 'http://127.0.0.1:${_server!.port}/stream/$id';
    _log(
      '[PROXY] register id=$id local=$local target=$url '
      'headerKeys=${headers.keys.toList()}',
    );
    return local;
  }

  Future<void> _ensureServer() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _log('[PROXY] server listening on 127.0.0.1:${_server!.port}');
    _server!.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final id =
        request.uri.pathSegments.length >= 2 &&
            request.uri.pathSegments.first == 'stream'
        ? request.uri.pathSegments[1]
        : null;
    final target = id != null ? _targets[id] : null;
    if (target == null) {
      _log(
        '[PROXY] miss path=${request.uri.path} '
        'query=${request.uri.query}',
      );
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final range = request.headers.value(HttpHeaders.rangeHeader);
    _log(
      '[PROXY] incoming id=$id method=${request.method} '
      'range=${range ?? '<none>'} ua=${request.headers.value('user-agent')}',
    );

    final client = HttpClient();
    try {
      final proxyRequest = await client.openUrl(
        request.method,
        Uri.parse(target.url),
      );

      target.headers.forEach(proxyRequest.headers.set);

      // Forward range for seeking support.
      if (range != null) {
        proxyRequest.headers.set(HttpHeaders.rangeHeader, range);
      }

      final proxyResponse = await proxyRequest.close();
      _log(
        '[PROXY] upstream id=$id status=${proxyResponse.statusCode} '
        'contentLength=${proxyResponse.contentLength} '
        'acceptRanges=${proxyResponse.headers.value('accept-ranges')}',
      );
      request.response.statusCode = proxyResponse.statusCode;
      proxyResponse.headers.forEach((name, values) {
        try {
          request.response.headers.set(name, values.join(','));
        } catch (_) {
          // Skip headers rejected by dart:io on the outbound side.
        }
      });
      await proxyResponse.pipe(request.response);
      _log('[PROXY] completed id=$id status=${request.response.statusCode}');
    } catch (e, st) {
      final expectedDisconnect = _isExpectedDisconnect(e);
      if (expectedDisconnect) {
        _log('[PROXY] stream closed id=$id (expected): $e');
      } else {
        _log('[PROXY] request failed id=$id: $e');
        _log('[PROXY] stack id=$id: $st');
      }
      // If bytes were already forwarded, status mutation may fail.
      if (!expectedDisconnect) {
        try {
          request.response.statusCode = HttpStatus.badGateway;
        } catch (_) {}
      }
      try {
        await request.response.close();
      } catch (_) {
        // Ignore close failures; the client may have already disconnected.
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
    _targets.clear();
  }

  bool _isExpectedDisconnect(Object error) {
    if (error is HttpException && error.message.contains(_upstreamClosedMsg)) {
      return true;
    }
    if (error is SocketException) {
      final msg = error.message.toLowerCase();
      return msg.contains('broken pipe') ||
          msg.contains('connection reset by peer') ||
          msg.contains('connection closed');
    }
    return false;
  }
}

class _ProxyTarget {
  final String url;
  final Map<String, String> headers;

  const _ProxyTarget({required this.url, required this.headers});
}
