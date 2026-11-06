import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/main_screen.dart';
import 'core/api/auth_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка окна — вертикальный формат как на телефоне
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

  // Проверка сессии
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

class EclipseVPNApp extends StatelessWidget {
  final bool isLoggedIn;

  const EclipseVPNApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECLIPSE VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
