import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_service.dart';
import 'vpn_service.dart';

/// Иконка в системном трее с реальным управлением VPN.
///
/// Меню: Показать / Подключить-Отключить / Автозапуск / Выход.
/// Клик по иконке — показать или скрыть окно.
class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  bool _initialized = false;
  StreamSubscription<VpnStatus>? _vpnSub;

  /// Callback полного выхода из приложения (вызывается из меню «Выход»).
  void Function()? onQuit;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await trayManager.setIcon('assets/icons/tray_icon.ico');
      await trayManager.setToolTip('ECLIPSE VPN — отключено');

      launchAtStartup.setup(
        appName: 'ECLIPSE VPN',
        appPath: Platform.resolvedExecutable,
      );

      trayManager.addListener(this);
      _initialized = true;

      _vpnSub = VpnService().statusStream.listen(_onVpnStatus);
      await _rebuildMenu();
    } catch (e) {
      debugPrint('Tray init error: $e');
    }
  }

  void _onVpnStatus(VpnStatus status) {
    if (!_initialized) return;
    trayManager
        .setToolTip(status.isConnected
            ? 'ECLIPSE VPN — подключено (${status.server})'
            : 'ECLIPSE VPN — отключено')
        .catchError((_) {});
    _rebuildMenu().catchError((_) {});
  }

  Future<void> _rebuildMenu() async {
    final vpn = VpnService();
    final autostart = SettingsService().autostartEnabled;

    final menu = Menu(
      items: [
        MenuItem(key: 'show', label: 'Показать'),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle',
          label: vpn.isConnected ? 'Отключить VPN' : 'Подключить VPN',
        ),
        MenuItem(
          key: 'autostart',
          label: 'Запускать с Windows',
          checked: autostart,
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Выход'),
      ],
    );
    await trayManager.setContextMenu(menu);
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
        await showWindow();
        break;
      case 'toggle':
        final vpn = VpnService();
        if (vpn.isConnected) {
          await vpn.disconnect();
        } else if (!vpn.isBusy) {
          await showWindow();
          vpn.connect();
        }
        break;
      case 'autostart':
        await _toggleAutostart();
        break;
      case 'quit':
        await quit();
        break;
    }
  }

  Future<void> _toggleAutostart() async {
    final settings = SettingsService();
    final newValue = !settings.autostartEnabled;
    try {
      if (newValue) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      await settings.setAutostart(newValue);
    } catch (e) {
      debugPrint('Autostart toggle error: $e');
    }
    await _rebuildMenu();
  }

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await showWindow();
    }
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Полный выход: остановить VPN, уничтожить трей и окно.
  Future<void> quit() async {
    await VpnService().disconnect();
    if (_initialized) {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
    await _vpnSub?.cancel();
    onQuit?.call();
    await windowManager.destroy();
    exit(0);
  }

  void dispose() {
    _vpnSub?.cancel();
    if (_initialized) trayManager.removeListener(this);
  }
}
