import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Экран устройств — заглушка для полной совместимости с Android.
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: Center(
        child: Text(
          'Устройства',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
      ),
    );
  }
}
