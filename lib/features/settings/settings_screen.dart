import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_file_cache.dart';
import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../vr/vr_overlay_service.dart';
import 'eq_screen.dart';

final _audioCacheStatsProvider = FutureProvider<AudioCacheStats>((ref) async {
  final timer = Timer.periodic(const Duration(seconds: 3), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return AudioFileCache.instance.getStats();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final cacheStats = ref.watch(_audioCacheStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ──────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Theme'),
            trailing: SegmentedButton<Brightness>(
              selected: {settings.brightness},
              onSelectionChanged: (s) => notifier.setBrightness(s.first),
              segments: const [
                ButtonSegment(
                  value: Brightness.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: Brightness.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color Scheme',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColorScheme.values.map((scheme) {
                    final seeds = MixtapeTheme.schemeSeeds[scheme]!;
                    final color = settings.brightness == Brightness.dark
                        ? seeds.$1
                        : seeds.$2;
                    return GestureDetector(
                      onTap: () => notifier.setColorScheme(scheme),
                      child: Tooltip(
                        message: MixtapeTheme.schemeName(scheme),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: settings.colorScheme == scheme
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Font scale
          ListTile(
            leading: const Icon(Icons.text_fields_rounded),
            title: Text(
              'Font scale: ${settings.fontScale.toStringAsFixed(1)}×',
            ),
            subtitle: Slider(
              value: settings.fontScale,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              label: '${settings.fontScale.toStringAsFixed(1)}×',
              onChanged: notifier.setFontScale,
            ),
          ),

          // Background image
          ListTile(
            leading: const Icon(Icons.wallpaper_rounded),
            title: const Text('App background image'),
            subtitle: settings.backgroundImagePath != null
                ? Text(
                    settings.backgroundImagePath!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  )
                : const Text('None'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded),
                  tooltip: 'Choose image',
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                    );
                    if (result?.files.single.path != null) {
                      notifier.setBackgroundImage(result!.files.single.path!);
                    }
                  },
                ),
                if (settings.backgroundImagePath != null)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    tooltip: 'Remove image',
                    onPressed: () => notifier.setBackgroundImage(null),
                  ),
              ],
            ),
          ),

          // ── Player ──────────────────────────────────────────────────────────
          _SectionHeader('Player'),
          ListTile(
            leading: const Icon(Icons.layers_rounded),
            title: const Text('Background style'),
            trailing: DropdownButton<PlayerBackgroundStyle>(
              value: settings.playerBackgroundStyle,
              underline: const SizedBox.shrink(),
              items: PlayerBackgroundStyle.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(switch (s) {
                    PlayerBackgroundStyle.blur => 'Blur',
                    PlayerBackgroundStyle.gradient => 'Gradient',
                    PlayerBackgroundStyle.solid => 'Solid',
                  }),
                );
              }).toList(),
              onChanged: (s) {
                if (s != null) notifier.setPlayerBackgroundStyle(s);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.blur_on_rounded),
            title: const Text('Album art background blur'),
            value: settings.showAlbumColorInPlayer,
            onChanged: notifier.setShowAlbumColor,
          ),
          if (settings.showAlbumColorInPlayer)
            ListTile(
              leading: const Icon(Icons.blur_circular_rounded),
              title: const Text('Blur intensity'),
              subtitle: Slider(
                value: settings.playerBlurIntensity,
                min: 0,
                max: 100,
                divisions: 20,
                label: settings.playerBlurIntensity.toStringAsFixed(0),
                onChanged: notifier.setPlayerBlur,
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.lyrics_rounded),
            title: const Text('Show lyrics by default'),
            value: settings.showLyricsByDefault,
            onChanged: notifier.setShowLyricsByDefault,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_rounded),
            title: const Text('Use album art on player buttons'),
            subtitle: const Text(
              'Apply artwork texture to transport button backgrounds',
            ),
            value: settings.useArtworkOnPlayerButtons,
            onChanged: notifier.setUseArtworkOnPlayerButtons,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dashboard_customize_rounded),
            title: const Text('Rearrange player controls layout'),
            subtitle: const Text('Swap left/right control groups in player UI'),
            value: settings.rearrangePlayerControls,
            onChanged: notifier.setRearrangePlayerControls,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.ondemand_video_rounded),
            title: const Text('Show YouTube video in player when available'),
            subtitle: const Text(
              'Displays embedded video for YouTube tracks in Now Playing',
            ),
            value: settings.showYoutubeVideoInPlayer,
            onChanged: notifier.setShowYoutubeVideoInPlayer,
          ),

          // ── Playback ────────────────────────────────────────────────────────
          _SectionHeader('Playback'),
          SwitchListTile(
            secondary: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Crossfade'),
            value: settings.crossfadeEnabled,
            onChanged: notifier.setCrossfade,
          ),
          if (settings.crossfadeEnabled)
            ListTile(
              leading: const Icon(Icons.timer_rounded),
              title: Text(
                'Crossfade duration: ${settings.crossfadeDurationSeconds}s',
              ),
              subtitle: Slider(
                value: settings.crossfadeDurationSeconds.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '${settings.crossfadeDurationSeconds}s',
                onChanged: (v) => notifier.setCrossfadeDuration(v.toInt()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.volume_up_rounded),
            title: Text('Volume: ${(settings.volume * 100).round()}%'),
            subtitle: Slider(
              value: settings.volume,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(settings.volume * 100).round()}%',
              onChanged: notifier.setVolume,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.compress_rounded),
            title: const Text('Volume normalization'),
            subtitle: const Text('Normalize loudness across tracks'),
            value: settings.normalizeVolume,
            onChanged: notifier.setNormalizeVolume,
          ),

          // ── Output ─────────────────────────────────────────────────────────
          _SectionHeader('Output'),
          ListTile(
            leading: const Icon(Icons.high_quality_rounded),
            title: const Text('Stream quality'),
            subtitle: const Text('Preferred bitrate when sources support it'),
            trailing: DropdownButton<StreamQuality>(
              value: settings.streamQuality,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: StreamQuality.low,
                  child: Text('Low (64 kbps)'),
                ),
                DropdownMenuItem(
                  value: StreamQuality.medium,
                  child: Text('Medium (128 kbps)'),
                ),
                DropdownMenuItem(
                  value: StreamQuality.high,
                  child: Text('High (320 kbps)'),
                ),
              ],
              onChanged: (q) {
                if (q != null) notifier.setStreamQuality(q);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.equalizer_rounded),
            title: const Text('Equalizer'),
            subtitle: const Text('Bass, treble & band EQ'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const EqScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.offline_pin_rounded),
            title: const Text('Cache audio files on this device'),
            subtitle: Text(
              settings.cacheAudioFiles
                  ? 'Enabled - streamed tracks may be stored locally'
                  : 'Tap to enable (legal disclaimer required)',
            ),
            trailing: Switch(
              value: settings.cacheAudioFiles,
              onChanged: (_) => _toggleAudioCache(context, settings, notifier),
            ),
            onTap: () => _toggleAudioCache(context, settings, notifier),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_rounded),
            title: const Text('Cached audio storage'),
            subtitle: cacheStats.when(
              data: (stats) => Text(
                '${_formatBytes(stats.bytes)} in ${stats.fileCount} file${stats.fileCount == 1 ? '' : 's'}',
              ),
              loading: () => const Text('Calculating...'),
              error: (_, _) => const Text('Unable to read cache usage'),
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: cacheStats.maybeWhen(
                data: (stats) => stats.fileCount > 0
                    ? () => _clearAudioCache(context, ref)
                    : null,
                orElse: () => null,
              ),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear'),
            ),
          ),

          // ── Discord Rich Presence ────────────────────────────────────────
          if (!Platform.isAndroid && !Platform.isIOS) ...[
            _SectionHeader('Discord Rich Presence'),
            SwitchListTile(
              secondary: const Icon(Icons.discord, color: Color(0xFF5865F2)),
              title: const Text('Show now-playing on Discord'),
              subtitle: const Text('Requires a Discord application Client ID'),
              value: settings.discordRpcEnabled,
              onChanged: notifier.setDiscordRpcEnabled,
            ),
            if (settings.discordRpcEnabled)
              _DiscordClientIdTile(
                initialValue: settings.discordRpcClientId,
                onSaved: notifier.setDiscordRpcClientId,
              ),
          ],

          // ── SteamVR ───────────────────────────────────────────────────────
          if (!Platform.isAndroid && !Platform.isIOS) ...[
            _SectionHeader('SteamVR Overlay'),
            SwitchListTile(
              secondary: const Icon(Icons.vrpano_rounded),
              title: const Text('Enable SteamVR overlay'),
              subtitle: const Text('Show the player as a wrist overlay in VR'),
              value: settings.vrOverlayEnabled,
              onChanged: (v) {
                notifier.setVrOverlayEnabled(v);
                if (v) {
                  VrOverlayService.instance.maybeInit();
                } else {
                  VrOverlayService.instance.dispose();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.headset_rounded),
              title: const Text('Earbud ear side'),
              subtitle: const Text(
                'Which ear the overlay rests at when not grabbed',
              ),
              trailing: SegmentedButton<bool>(
                selected: {settings.vrEarRight},
                onSelectionChanged: (s) => notifier.setVrEarRight(s.first),
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.arrow_back_rounded),
                    label: Text('Left'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.arrow_forward_rounded),
                    label: Text('Right'),
                  ),
                ],
              ),
            ),
          ],

          // ── yt-dlp ────────────────────────────────────────────────────────
          if (!Platform.isAndroid && !Platform.isIOS) ...[
            _SectionHeader('yt-dlp Stream Resolver'),
            ListTile(
              leading: const Icon(Icons.download_for_offline_rounded),
              title: const Text('yt-dlp'),
              subtitle: Text(
                settings.ytdlpAcknowledged
                    ? 'Enabled - yt-dlp must be on your PATH'
                    : 'Tap to enable (legal disclaimer required)',
              ),
              trailing: Switch(
                value: settings.ytdlpAcknowledged,
                onChanged: (_) =>
                    _toggleYtdlp(context, ref, settings, notifier),
              ),
              onTap: () => _toggleYtdlp(context, ref, settings, notifier),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _toggleYtdlp(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) async {
    final db = ref.read(databaseProvider);
    final registry = ref.read(pluginRegistryProvider);
    const pluginId = 'com.mixtape.ytdlp';

    Future<void> setPluginAck(bool enabled) async {
      await db
          .into(db.pluginConfigsTable)
          .insertOnConflictUpdate(
            PluginConfigsTableCompanion.insert(
              pluginId: pluginId,
              key: 'ack',
              value: enabled ? 'true' : 'false',
            ),
          );
      final rows = await (db.select(
        db.pluginConfigsTable,
      )..where((c) => c.pluginId.equals(pluginId))).get();
      final config = {for (final r in rows) r.key: r.value};
      await registry[pluginId]?.initialize(config);
    }

    if (settings.ytdlpAcknowledged) {
      await notifier.setYtdlpAcknowledged(false);
      await setPluginAck(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _YtdlpDisclaimerDialog(),
    );
    if (confirmed == true) {
      await notifier.setYtdlpAcknowledged(true);
      await setPluginAck(true);
    }
  }

  Future<void> _toggleAudioCache(
    BuildContext context,
    AppSettings settings,
    AppSettingsNotifier notifier,
  ) async {
    if (settings.cacheAudioFiles) {
      notifier.setCacheAudioFiles(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _AudioCacheDisclaimerDialog(),
    );
    if (confirmed == true) {
      notifier.setCacheAudioFiles(true);
    }
  }

  Future<void> _clearAudioCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear cached audio?'),
        content: const Text(
          'This removes downloaded audio cache files stored on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final bytesRemoved = await AudioFileCache.instance.clearAll();
    ref.invalidate(_audioCacheStatsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cleared ${_formatBytes(bytesRemoved)} of cached audio',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
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

// ── Discord client ID text field ─────────────────────────────────────────────

class _DiscordClientIdTile extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onSaved;
  const _DiscordClientIdTile({
    required this.initialValue,
    required this.onSaved,
  });

  @override
  State<_DiscordClientIdTile> createState() => _DiscordClientIdTileState();
}

class _DiscordClientIdTileState extends State<_DiscordClientIdTile> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Discord Application Client ID',
                hintText: '123456789012345678',
                border: OutlineInputBorder(),
                helperText: 'Create an app at discord.com/developers',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => widget.onSaved(_ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── yt-dlp legal disclaimer dialog ───────────────────────────────────────────

class _YtdlpDisclaimerDialog extends StatelessWidget {
  const _YtdlpDisclaimerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange,
        size: 40,
      ),
      title: const Text('Legal Disclaimer'),
      content: const SingleChildScrollView(
        child: Text(
          'yt-dlp is a third-party tool that can download and/or stream media '
          'from various services.\n\n'
          'Mixtape integrates with yt-dlp only to resolve stream URLs for '
          'in-app playback. Mixtape does not host, store, distribute, or '
          'download any content on your behalf.\n\n'
          'By enabling this feature, YOU acknowledge that:\n'
          '  • You are solely responsible for ensuring your usage complies '
          'with the terms of service of any website or service accessed '
          'through yt-dlp.\n'
          '  • You are solely responsible for compliance with all applicable '
          'copyright laws in your jurisdiction.\n'
          '  • The Mixtape developers accept NO liability for any legal '
          'consequences arising from your use of yt-dlp.\n\n'
          'Only proceed if you understand and accept these terms.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('I Understand & Accept'),
        ),
      ],
    );
  }
}

// ── Audio cache legal disclaimer dialog ─────────────────────────────────────

class _AudioCacheDisclaimerDialog extends StatelessWidget {
  const _AudioCacheDisclaimerDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange,
        size: 40,
      ),
      title: const Text('Legal Disclaimer'),
      content: const SingleChildScrollView(
        child: Text(
          'When enabled, Mixtape may cache streamed audio files on your '
          'device to improve playback performance and reduce repeat '
          'network usage.\n\n'
          'By enabling this feature, YOU acknowledge that:\n'
          '  • You are solely responsible for ensuring your use of cached '
          'audio complies with the terms of service of each content source.\n'
          '  • You are solely responsible for compliance with all '
          'applicable copyright and licensing laws in your jurisdiction.\n'
          '  • The Mixtape developers accept NO liability for any legal '
          'consequences arising from your use of audio caching.\n\n'
          'Only proceed if you understand and accept these terms.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('I Understand & Accept'),
        ),
      ],
    );
  }
}
