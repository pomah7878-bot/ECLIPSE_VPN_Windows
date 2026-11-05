import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/tray_service.dart';
import '../../connection/presentation/connection_screen.dart';
import '../../keys/presentation/keys_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Главный экран с навигацией (аналог MainActivity в Android)
class HomeScreen extends StatefulWidget {
  final TrayService trayService;

  const HomeScreen({
    super.key,
    required this.trayService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    const ConnectionScreen(),
    const KeysScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  @override
  void dispose() {
    widget.trayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.power_settings_new),
            label: 'Подключение',
          ),
          NavigationDestination(
            icon: Icon(Icons.key),
            label: 'Ключи',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Профиль',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}
