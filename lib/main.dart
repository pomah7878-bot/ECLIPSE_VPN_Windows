import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'core/services/auth_service.dart';
import 'core/services/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Настройка окна
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(400, 600),
    minimumSize: Size(360, 500),
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
  
  // Инициализация трея
  final trayService = TrayService();
  await trayService.initialize();
  
  // Проверка авторизации
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  
  runApp(EclipseVPNApp(isLoggedIn: isLoggedIn, trayService: trayService));
}

class EclipseVPNApp extends StatelessWidget {
  final bool isLoggedIn;
  final TrayService trayService;
  
  const EclipseVPNApp({
    super.key, 
    required this.isLoggedIn,
    required this.trayService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECLIPSE VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: isLoggedIn 
          ? HomeScreen(trayService: trayService) 
          : const LoginScreen(),
    );
  }
}
