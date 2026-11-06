import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Экран поддержки — заглушка для полной совместимости с Android.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: Center(
        child: Text(
          'Поддержка',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
      ),
    );
  }
}
