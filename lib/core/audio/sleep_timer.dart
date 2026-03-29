import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_handler.dart';
import 'player_service.dart';

class SleepTimerState {
  final Duration? remaining;
  final Duration? total;
  final bool endOfTrack;

  const SleepTimerState({this.remaining, this.total, this.endOfTrack = false});

  bool get isActive => remaining != null || endOfTrack;
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  final PlayerService _playerService;
  final MixtapeAudioHandler _handler;
  Timer? _timer;
  StreamSubscription<int>? _completedSub;

  SleepTimerNotifier(this._playerService, this._handler)
    : super(const SleepTimerState());

  void start(Duration duration) {
    cancel();
    state = SleepTimerState(remaining: duration, total: duration);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remaining;
      if (remaining == null) return;
      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _playerService.pause();
        cancel();
      } else {
        state = SleepTimerState(remaining: next, total: state.total);
      }
    });
  }

  void startEndOfTrack() {
    cancel();
    state = const SleepTimerState(endOfTrack: true);
    // Listen for track change — when the current track ends and advances, pause.
    _completedSub = _handler.trackChangeStream.listen((_) {
      _playerService.pause();
      cancel();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _completedSub?.cancel();
    _completedSub = null;
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _completedSub?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
      final playerService = ref.watch(playerServiceProvider);
      final handler = ref.watch(audioHandlerProvider);
      return SleepTimerNotifier(playerService, handler);
    });
