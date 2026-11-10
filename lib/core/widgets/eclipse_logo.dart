import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Логотип затмения как в Android-приложении:
/// тёмный диск с золотой короной справа-сверху и мягким свечением.
class EclipseLogo extends StatelessWidget {
  final double size;

  const EclipseLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EclipseLogoPainter()),
    );
  }
}

class _EclipseLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Мягкое тёплое свечение вокруг
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.goldAccent.withValues(alpha: 0.35),
          AppTheme.goldAccent.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, glow);

    // Золотой диск со смещением вправо-вверх (источник короны)
    final coronaCenter =
        Offset(center.dx + r * 0.16, center.dy - r * 0.16);
    canvas.drawCircle(
      coronaCenter,
      r * 0.52,
      Paint()
        ..shader = const RadialGradient(
          colors: [AppTheme.goldLight, AppTheme.goldAccent],
          center: Alignment(0.4, -0.4),
        ).createShader(
            Rect.fromCircle(center: coronaCenter, radius: r * 0.52)),
    );

    // Тёмный диск затмения поверх — оставляет серп справа-сверху
    canvas.drawCircle(
      center,
      r * 0.5,
      Paint()..color = const Color(0xFF04060b),
    );

    // Тонкая корона-дуга по кромке серпа
    final corona = Paint()
      ..color = AppTheme.goldAccent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.015
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawArc(
      Rect.fromCircle(center: coronaCenter, radius: r * 0.52),
      -pi * 0.55,
      pi * 0.75,
      false,
      corona,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Маленький логотип для шапки главного экрана.
class EclipseLogoSmall extends StatelessWidget {
  const EclipseLogoSmall({super.key});

  @override
  Widget build(BuildContext context) {
    return const EclipseLogo(size: 40);
  }
}

/// Лучи вокруг кнопки питания (используется и в логотипе экрана входа).
double rayAngle(int index, int count) => (index / count) * 2 * pi - pi / 2;

Offset polar(Offset center, double radius, double angle) => Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
