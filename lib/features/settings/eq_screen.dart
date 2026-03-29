import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/eq_service.dart';

class EqScreen extends ConsumerWidget {
  const EqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(eqProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          Switch(
            value: eq.enabled,
            onChanged: (v) => ref.read(eqProvider.notifier).setEnabled(v),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedOpacity(
        opacity: eq.enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !eq.enabled,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Platform badge
              if (!Platform.isAndroid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _InfoBanner(
                    icon: Icons.info_outline_rounded,
                    text: Platform.isIOS || Platform.isMacOS
                        ? 'Software EQ — presets shape audio processing. '
                              'For system-level EQ, use your device\'s audio settings.'
                        : 'Software EQ — applies presets to shape audio output.',
                  ),
                ),

              // ── Presets ─────────────────────────────────────────────────
              _SectionLabel('Presets'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: eqPresets.keys.map((name) {
                  final selected = eq.presetName == name;
                  return ChoiceChip(
                    label: Text(name),
                    selected: selected,
                    onSelected: (_) =>
                        ref.read(eqProvider.notifier).setPreset(name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ── Band sliders ────────────────────────────────────────────
              _SectionLabel('Bands'),
              ...List.generate(eqBandFrequencies.length, (i) {
                return _BandSlider(
                  frequency: eqBandFrequencies[i],
                  gain: eq.bandGains[i],
                  onChanged: (v) =>
                      ref.read(eqProvider.notifier).setBandGain(i, v),
                );
              }),
              const SizedBox(height: 24),

              // ── Bass / Loudness (Android only, uses native enhancer) ────
              if (Platform.isAndroid) ...[
                _SectionLabel('Bass / Loudness'),
                _BassBoostSlider(
                  gain: eq.bassBoost,
                  onChanged: (v) =>
                      ref.read(eqProvider.notifier).setBassBoost(v),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final double frequency;
  final double gain;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.frequency,
    required this.gain,
    required this.onChanged,
  });

  String _label(double hz) {
    if (hz >= 1000) {
      return '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k';
    }
    return hz.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _label(frequency),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Expanded(
            child: Slider(
              value: gain.clamp(-15, 15),
              min: -15,
              max: 15,
              divisions: 60,
              activeColor: colorScheme.primary,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BassBoostSlider extends StatelessWidget {
  final double gain;
  final ValueChanged<double> onChanged;

  const _BassBoostSlider({required this.gain, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.volume_up_rounded),
          Expanded(
            child: Slider(
              value: gain.clamp(0, 10),
              min: 0,
              max: 10,
              divisions: 20,
              label: '+${gain.toStringAsFixed(1)} dB',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '+${gain.toStringAsFixed(1)} dB',
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

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primaryContainer.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
