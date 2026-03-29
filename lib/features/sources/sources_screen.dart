import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/plugins/source_plugin.dart';
import '../../core/database/database.dart';
import '../../shared/widgets/cover_art.dart';

final pluginConfigsProvider =
    FutureProvider.family<Map<String, String>, String>((ref, pluginId) async {
      final db = ref.watch(databaseProvider);
      final rows = await (db.select(
        db.pluginConfigsTable,
      )..where((c) => c.pluginId.equals(pluginId))).get();
      return {for (final r in rows) r.key: r.value};
    });

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(pluginRegistryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sources')),
      body: registry.plugins.isEmpty
          ? Center(
              child: Text(
                'No plugins registered',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: registry.plugins.length,
              itemBuilder: (context, i) {
                final plugin = registry.plugins[i];
                return _PluginCard(plugin: plugin);
              },
            ),
    );
  }
}

class _PluginCard extends ConsumerWidget {
  final MixtapeSourcePlugin plugin;
  const _PluginCard({required this.plugin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stream-resolver plugins (e.g. yt-dlp) get a dedicated enable/disable card.
    if (plugin.capabilities.contains(PluginCapability.streamResolve)) {
      return _ResolverPluginCard(plugin: plugin);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: plugin.iconUrl != null
            ? CoverArt(url: plugin.iconUrl, size: 44, borderRadius: 10)
            : CircleAvatar(child: Text(plugin.name[0].toUpperCase())),
        title: Text(
          plugin.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          plugin.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: plugin.configFields.isEmpty
            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
            : const Icon(Icons.settings_rounded),
        onTap: plugin.configFields.isEmpty
            ? null
            : () => _openSettings(context, ref, plugin),
      ),
    );
  }

  void _openSettings(
    BuildContext context,
    WidgetRef ref,
    MixtapeSourcePlugin plugin,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PluginSettingsScreen(plugin: plugin)),
    );
  }
}

// ── Resolver plugin card (e.g. yt-dlp) ───────────────────────────────────────
// These plugins don't browse/search - they intercept stream URL resolution.
// The card shows a toggle (with legal disclaimer on first enable) and an
// optional "Configure" row for extra settings (e.g. custom binary path).

class _ResolverPluginCard extends ConsumerWidget {
  final MixtapeSourcePlugin plugin;
  const _ResolverPluginCard({required this.plugin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(pluginConfigsProvider(plugin.id));

    return configAsync.when(
      loading: () => const Card(child: ListTile(title: Text('Loading…'))),
      error: (_, e) => const SizedBox.shrink(),
      data: (config) {
        final isEnabled = config['ack'] == 'true';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: plugin.iconUrl != null
                    ? CoverArt(url: plugin.iconUrl, size: 40, borderRadius: 10)
                    : CircleAvatar(child: Text(plugin.name[0].toUpperCase())),
                title: Text(
                  plugin.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isEnabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Active - resolves streams for all sources',
                          style: TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                value: isEnabled,
                onChanged: (v) => _toggle(context, ref, config, v),
              ),
              if (isEnabled &&
                  plugin.configFields
                      .where((f) => f.key != 'ack')
                      .isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Configure path'),
                  subtitle: config['ytdlp_path']?.isNotEmpty == true
                      ? Text(
                          config['ytdlp_path']!,
                          style: const TextStyle(fontSize: 12),
                        )
                      : const Text(
                          'Using system PATH',
                          style: TextStyle(fontSize: 12),
                        ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PluginSettingsScreen(plugin: plugin),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> currentConfig,
    bool enable,
  ) async {
    if (enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _YtdlpDisclaimerDialog(),
      );
      if (confirmed != true) return;
    }

    final db = ref.read(databaseProvider);
    final registry = ref.read(pluginRegistryProvider);

    await db
        .into(db.pluginConfigsTable)
        .insertOnConflictUpdate(
          PluginConfigsTableCompanion.insert(
            pluginId: plugin.id,
            key: 'ack',
            value: enable ? 'true' : 'false',
          ),
        );

    final newConfig = Map<String, String>.from(currentConfig)
      ..['ack'] = enable ? 'true' : 'false';
    await registry[plugin.id]?.initialize(newConfig);

    ref.invalidate(pluginConfigsProvider(plugin.id));
  }
}

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
          'yt-dlp is a third-party command-line tool that can retrieve media '
          'streams from various websites.\n\n'
          'Mixtape only uses yt-dlp to resolve a direct audio stream URL for '
          'in-app playback. Mixtape does not download, store, or redistribute '
          'any content.\n\n'
          'By enabling this feature YOU acknowledge that:\n\n'
          '• You are solely responsible for ensuring your use complies with '
          'the Terms of Service of any website accessed via yt-dlp.\n\n'
          '• You are solely responsible for compliance with all applicable '
          'copyright laws in your jurisdiction.\n\n'
          '• The Mixtape developers accept NO liability for any legal '
          'consequences arising from your use of yt-dlp.\n\n'
          'yt-dlp must be installed separately and on your system PATH '
          '(or configured below). Get it at github.com/yt-dlp/yt-dlp.',
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

class PluginSettingsScreen extends ConsumerStatefulWidget {
  final MixtapeSourcePlugin plugin;
  const PluginSettingsScreen({super.key, required this.plugin});

  @override
  ConsumerState<PluginSettingsScreen> createState() =>
      _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends ConsumerState<PluginSettingsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  @override
  void initState() {
    // Fix 2: moved initState inside the class, removed erroneous 'void' prefix
    super.initState();
    for (final field in widget.plugin.configFields) {
      // Fix 3: removed erroneous 'void' prefix
      _controllers[field.key] = TextEditingController();
    }
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final db = ref.read(databaseProvider);
    final rows = await (db.select(
      db.pluginConfigsTable,
    )..where((c) => c.pluginId.equals(widget.plugin.id))).get();
    for (final row in rows) {
      _controllers[row.key]?.text = row.value;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final registry = ref.read(pluginRegistryProvider);

    for (final entry in _controllers.entries) {
      await db
          .into(db.pluginConfigsTable)
          .insertOnConflictUpdate(
            PluginConfigsTableCompanion.insert(
              pluginId: widget.plugin.id,
              key: entry.key,
              value: entry.value.text,
            ),
          );
    }

    final config = {for (final e in _controllers.entries) e.key: e.value.text};
    await registry[widget.plugin.id]?.initialize(config);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fix 4: removed duplicate build method
    return Scaffold(
      appBar: AppBar(title: Text('${widget.plugin.name} Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ...widget.plugin.configFields.map((field) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextField(
                controller: _controllers[field.key],
                obscureText: field.isSecret,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.hint,
                  border: const OutlineInputBorder(),
                ),
              ),
            );
          }),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
