import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_service.dart';

// ── Data model ──────────────────────────────────────────────────────────────

/// Canonical band frequencies used across all platforms.
const eqBandFrequencies = <double>[60, 230, 910, 3600, 14000];

/// Named EQ presets: band gains in dB for [60 Hz, 230 Hz, 910 Hz, 3.6 kHz, 14 kHz]
const eqPresets = <String, List<double>>{
  'Flat': [0, 0, 0, 0, 0],
  'Bass Boost': [6, 4, 0, 0, 0],
  'Treble Boost': [0, 0, 0, 4, 6],
  'Rock': [4, 2, -1, 2, 4],
  'Pop': [-1, 2, 4, 2, -1],
  'Classical': [4, 2, -2, 2, 4],
  'Electronic': [4, 2, 0, 2, 4],
  'Hip-Hop': [5, 3, 0, -1, 1],
  'Jazz': [3, 0, 1, 2, 4],
  'Vocal': [-2, 0, 3, 3, 0],
  'Late Night': [3, 1, 0, 1, 2],
  'Loudness': [5, 3, -1, 0, 5],
};

/// Current EQ state, persisted via SharedPreferences.
class EqState {
  final bool enabled;
  final String presetName;
  final List<double> bandGains; // dB, same length as [eqBandFrequencies]
  final double bassBoost; // 0..10 dB (Android loudness enhancer)

  const EqState({
    this.enabled = false,
    this.presetName = 'Flat',
    this.bandGains = const [0, 0, 0, 0, 0],
    this.bassBoost = 0,
  });

  EqState copyWith({
    bool? enabled,
    String? presetName,
    List<double>? bandGains,
    double? bassBoost,
  }) {
    return EqState(
      enabled: enabled ?? this.enabled,
      presetName: presetName ?? this.presetName,
      bandGains: bandGains ?? this.bandGains,
      bassBoost: bassBoost ?? this.bassBoost,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'presetName': presetName,
    'bandGains': bandGains,
    'bassBoost': bassBoost,
  };

  factory EqState.fromJson(Map<String, dynamic> json) {
    return EqState(
      enabled: json['enabled'] as bool? ?? false,
      presetName: json['presetName'] as String? ?? 'Flat',
      bandGains:
          (json['bandGains'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0, 0, 0, 0, 0],
      bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ── Notifier ────────────────────────────────────────────────────────────────

class EqNotifier extends Notifier<EqState> {
  static const _prefsKey = 'eq_state';

  late SharedPreferences _prefs;

  @override
  EqState build() {
    _loadAsync();
    return const EqState();
  }

  Future<void> _loadAsync() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = EqState.fromJson(json);
        _applyToBackend();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  void _applyToBackend() {
    if (Platform.isAndroid) {
      _applyAndroidEq();
    }
    // On non-Android platforms the EQ state is still tracked; the UI reflects
    // the selected preset/bands. Actual DSP is applied if/when a software
    // audio processing path becomes available (e.g. via FFmpeg or native plugins).
  }

  void _applyAndroidEq() {
    final eq = ref.read(androidEqualizerProvider);
    final loudness = ref.read(androidLoudnessEnhancerProvider);
    if (eq == null) return;

    if (!state.enabled) {
      eq.setEnabled(false);
      loudness?.setEnabled(false);
      return;
    }

    eq.setEnabled(true);
    eq.parameters.then((params) {
      for (
        int i = 0;
        i < params.bands.length && i < state.bandGains.length;
        i++
      ) {
        final gain = state.bandGains[i].clamp(
          params.minDecibels,
          params.maxDecibels,
        );
        params.bands[i].setGain(gain);
      }
    });

    if (loudness != null) {
      loudness.setEnabled(state.bassBoost > 0);
      if (state.bassBoost > 0) {
        loudness.setTargetGain(state.bassBoost);
      }
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    _applyToBackend();
    await _persist();
  }

  Future<void> setPreset(String presetName) async {
    final gains = eqPresets[presetName];
    if (gains == null) return;
    state = state.copyWith(
      presetName: presetName,
      bandGains: List<double>.from(gains),
    );
    _applyToBackend();
    await _persist();
  }

  Future<void> setBandGain(int bandIndex, double gain) async {
    if (bandIndex < 0 || bandIndex >= state.bandGains.length) return;
    final newGains = List<double>.from(state.bandGains);
    newGains[bandIndex] = gain;

    // Find if this matches a preset
    String detectedPreset = 'Custom';
    for (final entry in eqPresets.entries) {
      if (_gainsMatch(newGains, entry.value)) {
        detectedPreset = entry.key;
        break;
      }
    }

    state = state.copyWith(bandGains: newGains, presetName: detectedPreset);
    _applyToBackend();
    await _persist();
  }

  Future<void> setBassBoost(double gain) async {
    state = state.copyWith(bassBoost: gain.clamp(0, 10));
    _applyToBackend();
    await _persist();
  }

  bool _gainsMatch(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.4) return false;
    }
    return true;
  }
}

final eqProvider = NotifierProvider<EqNotifier, EqState>(EqNotifier.new);
