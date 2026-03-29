import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database.dart';
import 'plugins/plugin_registry.dart';

/// Global database provider - overridden in ProviderScope at startup.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in ProviderScope');
});

/// Global plugin registry provider - overridden in ProviderScope at startup.
final pluginRegistryProvider = Provider<PluginRegistry>((ref) {
  throw UnimplementedError('pluginRegistryProvider must be overridden in ProviderScope');
});
