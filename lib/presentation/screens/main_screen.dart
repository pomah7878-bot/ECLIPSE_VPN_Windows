import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';
import 'tariff_screen.dart';
import 'devices_screen.dart';
import 'support_screen.dart';

/// Главный экран с нижней навигацией.
///
/// Полностью копирует Android-приложение:
/// - 4 вкладки: Главная, Тариф, Устройства, Поддержка
/// - Золотая иконка активной вкладки
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TariffScreen(),
    DevicesScreen(),
    SupportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.eclipseBlack,
          border: Border(
            top: BorderSide(color: AppTheme.cardDarkSecondary, width: 1),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: AppTheme.eclipseBlack,
            selectedItemColor: AppTheme.goldAccent,
            unselectedItemColor: AppTheme.textMuted,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home, color: AppTheme.goldAccent),
                label: 'Главная',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card_outlined),
                activeIcon: Icon(Icons.credit_card, color: AppTheme.goldAccent),
                label: 'Тариф',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.devices_outlined),
                activeIcon: Icon(Icons.devices, color: AppTheme.goldAccent),
                label: 'Устройства',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.headset_mic_outlined),
                activeIcon: Icon(Icons.headset_mic, color: AppTheme.goldAccent),
                label: 'Поддержка',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
