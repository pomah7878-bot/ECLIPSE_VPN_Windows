import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Экран тарифов — заглушка для полной совместимости с Android.
class TariffScreen extends StatelessWidget {
  const TariffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: Center(
        child: Text(
          'Тарифы',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
      ),
    );
  }
}
