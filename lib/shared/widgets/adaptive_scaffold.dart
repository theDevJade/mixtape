import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/player_service.dart';
import '../../features/home/home_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sources/sources_screen.dart';
import '../../features/player/widgets/mini_player.dart';
import '../../features/player/now_playing_screen.dart';

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Destination(this.label, this.icon, this.selectedIcon);
}

const _destinations = [
  _Destination('Home', Icons.home_outlined, Icons.home_rounded),
  _Destination('Search', Icons.search_outlined, Icons.search_rounded),
  _Destination(
    'Library',
    Icons.library_music_outlined,
    Icons.library_music_rounded,
  ),
  _Destination('Sources', Icons.hub_outlined, Icons.hub_rounded),
  _Destination('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

class AdaptiveScaffold extends ConsumerStatefulWidget {
  const AdaptiveScaffold({super.key});

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  int _selectedIndex = 0;

  static final _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const LibraryScreen(),
    const SourcesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackErrorProvider, (_, next) {
      if (next.hasValue && next.value != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.value!),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            showCloseIcon: true,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });

    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final body = _screens[_selectedIndex];

    return Scaffold(
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.music_note_rounded, size: 32),
                ),
              ),
              destinations: _destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: body),
                MiniPlayer(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
