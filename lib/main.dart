import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'core/api/auth_api.dart';
import 'core/services/vpn_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(420, 780),
    minimumSize: Size(380, 700),
    maximumSize: Size(500, 900),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ECLIPSE VPN',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final authApi = AuthApi();
  AccountSessionResponse? session;
  try {
    session = await authApi.getSession();
  } catch (_) {
    session = null;
  }
  final isLoggedIn = session?.loggedIn ?? false;

  runApp(EclipseVPNApp(isLoggedIn: isLoggedIn));
}

class EclipseVPNApp extends StatefulWidget {
  final bool isLoggedIn;
  const EclipseVPNApp({super.key, required this.isLoggedIn});

  @override
  State<EclipseVPNApp> createState() => _EclipseVPNAppState();
}

class _EclipseVPNAppState extends State<EclipseVPNApp> with WindowListener {
  final _vpn = VpnService();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _vpn.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() {
    _vpn.disconnect();
    windowManager.destroy();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECLIPSE VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: widget.isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}