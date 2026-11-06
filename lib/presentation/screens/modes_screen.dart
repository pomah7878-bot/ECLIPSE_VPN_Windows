import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Экран режимов маршрутизации — копия Android (modes.jpg).
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.eclipseBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Режимы маршрутизации',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ModeCard(
              title: 'Умный',
              description: 'Российские сайты напрямую, остальной трафик через VPN',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _ModeCard(
              title: 'Белые списки',
              description: 'Для сетей с белыми списками: напрямую только разрешённые сервисы',
              isSelected: true,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _ModeCard(
              title: 'Как у всех',
              description: 'Весь трафик через VPN',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _ModeCard(
              title: 'Скрыть значок ECLIPSE',
              description: 'Убирает значок приложения из строки состояния',
              isSelected: false,
              onTap: () {},
            ),
            const SizedBox(height: 20),
            const Text(
              'Режим можно изменить в любой момент. Правила обновляются с сервера ECLIPSE.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppTheme.goldAccent, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.goldAccent : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: AppTheme.goldAccent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
