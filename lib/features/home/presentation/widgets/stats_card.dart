import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Карточка статистики как в Android: иконка/метка сверху,
/// крупное значение, подпись снизу — всё выровнено влево.
class StatsCard extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String? topLabel;
  final String value;
  final String label;

  const StatsCard({
    super.key,
    this.icon,
    this.iconColor,
    this.topLabel,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topLabel != null)
            Text(
              topLabel!,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            )
          else if (icon != null)
            Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
