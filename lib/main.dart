import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'core/api/api_client.dart';
import 'core/api/auth_api.dart';
import 'core/services/deeplink_service.dart';
import 'core/services/session_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/tray_service.dart';
import 'core/services/vpn_service.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/presentation/main_screen.dart';

Future<void> main(List<String> args) async {
  // Второй экземпляр, запущенный Windows по deep-link'у eclipsevpn://,
  // пересылает URL первому экземпляру и завершается.
  final deepLink = await DeepLinkService.handleLaunchArgs(args);
  if (deepLink != null) {
    await DeepLinkService.forwardToRunningInstance(deepLink);
    exit(0);
  }

  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(420, 800),
    minimumSize: Size(380, 720),
    maximumSize: Size(520, 940),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ECLIPSE VPN',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Инициализация сервисов до первого кадра
  await ApiClient().init();
  await SettingsService().init();
  await DeepLinkService.instance.startReceiver();
  await DeepLinkService.registerProtocolHandler();

  // Тихая проверка сохранённой cookie-сессии
  bool isLoggedIn = false;
  try {
    final session = await AuthApi().getSession();
    isLoggedIn = session?.loggedIn ?? false;
  } catch (_) {
    isLoggedIn = false;
  }
  SessionService.setLoggedIn(isLoggedIn);

  runApp(const EclipseVPNApp());
}

class EclipseVPNApp extends StatefulWidget {
  const EclipseVPNApp({super.key});

  @override
  State<EclipseVPNApp> createState() => _EclipseVPNAppState();
}

class _EclipseVPNAppState extends State<EclipseVPNApp> with WindowListener {
  final _vpn = VpnService();
  final _tray = TrayService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _tray.onQuit = _quit;
    _tray.init();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tray.dispose();
    _vpn.dispose();
    super.dispose();
  }

  /// Крестик окна — свернуть в трей, VPN продолжает работать.
  @override
  void onWindowClose() async {
    if (!await windowManager.isPreventClose()) return;
    await windowManager.hide();
  }

  Future<void> _quit() async {
    await _vpn.disconnect();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECLIPSE VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
