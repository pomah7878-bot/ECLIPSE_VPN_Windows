import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/login_screen.dart';
import '../../devices/presentation/devices_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../purchase/presentation/purchase_screen.dart';
import '../../support/presentation/support_screen.dart';

/// Оболочка с нижней навигацией как в Android-приложении:
/// Главная / Тариф / Устройства / Поддержка.
/// Вкладка «Главная» показывает вход, пока нет сессии.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _goTab(int index) {
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: ValueListenableBuilder<bool>(
        valueListenable: SessionService.loggedIn,
        builder: (_, loggedIn, __) {
          final screens = <Widget>[
            loggedIn
                ? HomeScreen(onOpenAccount: () => _goTab(1))
                : LoginContent(onLoggedIn: () => _goTab(0)),
            const PurchaseScreen(),
            const DevicesScreen(),
            const SupportScreen(),
          ];
          return IndexedStack(index: _selectedIndex, children: screens);
        },
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.navBackground,
          border: Border(
            top: BorderSide(color: AppTheme.cardBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _goTab,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Главная',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card),
                activeIcon: Icon(Icons.credit_card),
                label: 'Тариф',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.desktop_windows_outlined),
                activeIcon: Icon(Icons.desktop_windows),
                label: 'Устройства',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.headphones_outlined),
                activeIcon: Icon(Icons.headphones),
                label: 'Поддержка',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
