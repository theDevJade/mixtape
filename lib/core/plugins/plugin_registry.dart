import 'package:flutter/foundation.dart';
import 'source_plugin.dart';

/// Central registry that holds all loaded plugins.
/// Third-party plugins register themselves here at startup.
class PluginRegistry extends ChangeNotifier {
  final Map<String, MixtapeSourcePlugin> _plugins = {};

  List<MixtapeSourcePlugin> get plugins => _plugins.values.toList();

  MixtapeSourcePlugin? operator [](String id) => _plugins[id];

  void register(MixtapeSourcePlugin plugin) {
    _plugins[plugin.id] = plugin;
    notifyListeners();
  }

  void unregister(String id) {
    _plugins.remove(id);
    notifyListeners();
  }

  bool isRegistered(String id) => _plugins.containsKey(id);

  List<MixtapeSourcePlugin> pluginsWithCapability(PluginCapability cap) =>
      _plugins.values.where((p) => p.capabilities.contains(cap)).toList();

  Future<void> initializeAll(
      Map<String, Map<String, String>> configs) async {
    for (final plugin in _plugins.values) {
      final config = configs[plugin.id] ?? {};
      try {
        await plugin.initialize(config);
      } catch (e) {
        debugPrint('[PluginRegistry] Failed to initialize ${plugin.id}: $e');
      }
    }
  }

  Future<void> disposeAll() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
  }
}
