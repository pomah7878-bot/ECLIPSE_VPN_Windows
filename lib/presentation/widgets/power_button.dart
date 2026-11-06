import 'dart:math' show cos, sin, pi;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Анимированная кнопка питания с золотыми лучами.
///
/// Полная копия Android-приложения:
/// - В отключенном состоянии: золотой круг с иконкой питания
/// - В подключенном: пульсирующие лучи + зелёный щит + таймер
class PowerButton extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onTap;
  final AnimationController pulseController;

  const PowerButton({
    super.key,
    required this.isConnected,
    required this.onTap,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 260,
        height: 260,
        child: AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return CustomPaint(
              painter: _PowerButtonPainter(
                isConnected: isConnected,
                pulseValue: pulseController.isAnimating
                    ? pulseController.value
                    : 0,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Иконка
                    if (isConnected)
                      const Icon(
                        Icons.shield,
                        color: AppTheme.successGreen,
                        size: 48,
                      )
                    else
                      const Icon(
                        Icons.power_settings_new,
                        color: AppTheme.goldAccent,
                        size: 48,
                      ),
                    const SizedBox(height: 8),
                    // Текст
                    Text(
                      isConnected ? 'ПОДКЛЮЧЕНО' : 'ПОДКЛЮЧИТЬ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: isConnected
                            ? AppTheme.goldAccent
                            : AppTheme.textPrimary,
                      ),
                    ),
                    // Таймер (только при подключении)
                    if (isConnected)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '00:00:00',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PowerButtonPainter extends CustomPainter {
  final bool isConnected;
  final double pulseValue;

  _PowerButtonPainter({required this.isConnected, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - 20;

    // 1. Внешнее свечение (пульсирует при подключении)
    if (isConnected) {
      final glowRadius = baseRadius + 10 + (pulseValue * 15);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.goldAccent.withOpacity(0.3 - pulseValue * 0.15),
            AppTheme.goldAccent.withOpacity(0.1 - pulseValue * 0.05),
            Colors.transparent,
          ],
          stops: const [0.2, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // 2. Лучи (rays) — золотые линии вокруг круга
    final rayCount = isConnected ? 48 : 24;
    final rayInner = baseRadius - 8;
    final rayOuter = baseRadius + (isConnected ? 12 + pulseValue * 8 : 8);

    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 2 * pi - pi / 2;
      final inner = Offset(
        center.dx + rayInner * cos(angle),
        center.dy + rayInner * sin(angle),
      );
      final outer = Offset(
        center.dx + rayOuter * cos(angle),
        center.dy + rayOuter * sin(angle),
      );

      final opacity = isConnected
          ? 0.4 + pulseValue * 0.3
          : 0.25;
      final rayPaint = Paint()
        ..color = AppTheme.goldAccent.withOpacity(opacity)
        ..strokeWidth = isConnected ? 1.2 : 1.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(inner, outer, rayPaint);
    }

    // 3. Основной круг (фон кнопки)
    final circlePaint = Paint()
      ..color = AppTheme.eclipseBlack
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius - 4, circlePaint);

    // 4. Обводка круга
    final borderPaint = Paint()
      ..color = AppTheme.goldAccent.withOpacity(isConnected ? 0.8 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isConnected ? 3 : 2;
    canvas.drawCircle(center, baseRadius - 4, borderPaint);

    // 5. Внутреннее свечение (тонкое)
    final innerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.goldAccent.withOpacity(isConnected ? 0.15 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.7));
    canvas.drawCircle(center, baseRadius * 0.7, innerGlow);
  }

  @override
  bool shouldRepaint(covariant _PowerButtonPainter oldDelegate) {
    return oldDelegate.isConnected != isConnected ||
        oldDelegate.pulseValue != pulseValue;
  }
}
