import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/player_service.dart';

/// Named EQ presets: band gains in dB for [60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz]
const _presets = <String, List<double>>{
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
};

class EqScreen extends ConsumerStatefulWidget {
  const EqScreen({super.key});

  @override
  ConsumerState<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends ConsumerState<EqScreen> {
  String _selectedPreset = 'Flat';

  @override
  Widget build(BuildContext context) {
    final equalizer = ref.watch(androidEqualizerProvider);
    final loudness = ref.watch(androidLoudnessEnhancerProvider);
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: const Text('Equalizer')),
      body: !isAndroid
          ? _UnsupportedPlatform()
          : equalizer == null
          ? const Center(child: Text('EQ not available'))
          : _EqBody(
              equalizer: equalizer,
              loudness: loudness,
              selectedPreset: _selectedPreset,
              onPresetChanged: (name) {
                setState(() => _selectedPreset = name);
                _applyPreset(equalizer, name);
              },
            ),
    );
  }

  Future<void> _applyPreset(AndroidEqualizer eq, String name) async {
    final gains = _presets[name];
    if (gains == null) return;
    final params = await eq.parameters;
    for (int i = 0; i < params.bands.length && i < gains.length; i++) {
      await params.bands[i].setGain(gains[i]);
    }
  }
}

class _EqBody extends StatelessWidget {
  final AndroidEqualizer equalizer;
  final AndroidLoudnessEnhancer? loudness;
  final String selectedPreset;
  final ValueChanged<String> onPresetChanged;

  const _EqBody({
    required this.equalizer,
    required this.loudness,
    required this.selectedPreset,
    required this.onPresetChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AndroidEqualizerParameters>(
      future: equalizer.parameters,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final params = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Presets ──────────────────────────────────────────────────────
            _SectionLabel('Presets'),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presets.length,
                separatorBuilder: (_, idx) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final name = _presets.keys.elementAt(i);
                  final isSelected = name == selectedPreset;
                  return ChoiceChip(
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (_) => onPresetChanged(name),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Band sliders ─────────────────────────────────────────────────
            _SectionLabel('Bands'),
            ...params.bands.map(
              (band) => _BandSlider(
                band: band,
                minDecibels: params.minDecibels,
                maxDecibels: params.maxDecibels,
              ),
            ),

            const SizedBox(height: 24),

            // ── Loudness / Bass knob ─────────────────────────────────────────
            if (loudness != null) ...[
              _SectionLabel('Bass / Loudness'),
              _LoudnessSlider(loudness: loudness!),
            ],
          ],
        );
      },
    );
  }
}

class _BandSlider extends StatefulWidget {
  final AndroidEqualizerBand band;
  final double minDecibels;
  final double maxDecibels;
  const _BandSlider({
    required this.band,
    required this.minDecibels,
    required this.maxDecibels,
  });

  @override
  State<_BandSlider> createState() => _BandSliderState();
}

class _BandSliderState extends State<_BandSlider> {
  late double _gain;

  @override
  void initState() {
    super.initState();
    _gain = widget.band.gain;
  }

  String _label(double hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k';
    }
    return hz.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = widget.minDecibels;
    final max = widget.maxDecibels;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _label(widget.band.centerFrequency),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: Slider(
              value: _gain.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / 0.5).round(),
              activeColor: colorScheme.primary,
              onChanged: (v) => setState(() => _gain = v),
              onChangeEnd: (v) async {
                setState(() => _gain = v);
                await widget.band.setGain(v);
              },
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${_gain.toStringAsFixed(1)} dB',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoudnessSlider extends StatefulWidget {
  final AndroidLoudnessEnhancer loudness;
  const _LoudnessSlider({required this.loudness});

  @override
  State<_LoudnessSlider> createState() => _LoudnessSliderState();
}

class _LoudnessSliderState extends State<_LoudnessSlider> {
  double _gain = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.volume_up_rounded),
          Expanded(
            child: Slider(
              value: _gain.clamp(0, 10),
              min: 0,
              max: 10,
              divisions: 20,
              label: '+${_gain.toStringAsFixed(1)} dB',
              onChanged: (v) => setState(() => _gain = v),
              onChangeEnd: (v) async {
                setState(() => _gain = v);
                await widget.loudness.setTargetGain(v);
              },
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '+${_gain.toStringAsFixed(1)} dB',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _UnsupportedPlatform extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.equalizer_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Equalizer not available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'System-level EQ is only supported on Android.\n'
              'On other platforms, use your device\'s built-in audio settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
