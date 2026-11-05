import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class TrayService with TrayListener {
  bool _isInitialized = false;
  bool _isWindowVisible = true;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Иконка для трея
    String iconPath = 'assets/icons/tray_icon.ico';
    
    // Для Windows используем .ico
    if (Platform.isWindows) {
      iconPath = 'assets/icons/tray_icon.ico';
    }
    
    try {
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('ECLIPSE VPN');
      
      final menu = Menu(
        items: [
          MenuItem(
            key: 'show',
            label: 'Показать',
          ),
          MenuItem(
            key: 'connect',
            label: 'Подключиться',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'autostart',
            label: 'Автозапуск',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Выход',
          ),
        ],
      );
      
      await trayManager.setContextMenu(menu);
      trayManager.addListener(this);
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('Tray init error: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    _toggleWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _showWindow();
        break;
      case 'connect':
        // TODO: Вызвать подключение/отключение
        break;
      case 'autostart':
        await _toggleAutostart();
        break;
      case 'quit':
        await _quit();
        break;
    }
  }

  Future<void> _toggleWindow() async {
    if (_isWindowVisible) {
      await _hideWindow();
    } else {
      await _showWindow();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _isWindowVisible = true;
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
    _isWindowVisible = false;
  }

  Future<void> _toggleAutostart() async {
    final isEnabled = await launchAtStartup.isEnabled();
    if (isEnabled) {
      await launchAtStartup.disable();
    } else {
      await launchAtStartup.enable();
    }
    // TODO: Обновить чекбокс в меню
  }

  Future<void> _quit() async {
    await trayManager.destroy();
    await windowManager.destroy();
    exit(0);
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
