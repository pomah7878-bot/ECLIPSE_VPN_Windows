import 'dart:math' show cos, pi, sin;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Кнопка питания как в Android-приложении:
/// - отключено: тёмный круг, тонкое золотое кольцо, тонкие лучи,
///   золотая иконка питания и белая надпись «ПОДКЛЮЧИТЬ»
/// - подключено: яркое свечение, зелёный щит с галочкой,
///   золотая надпись «ПОДКЛЮЧЕНО» и белый таймер сессии
class PowerButton extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;
  final AnimationController pulseController;
  final Duration uptime;

  const PowerButton({
    super.key,
    required this.isConnected,
    this.isConnecting = false,
    required this.onTap,
    required this.pulseController,
    this.uptime = Duration.zero,
  });

  String get _uptimeText {
    final h = uptime.inHours.toString().padLeft(2, '0');
    final m = (uptime.inMinutes % 60).toString().padLeft(2, '0');
    final s = (uptime.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: SizedBox(
        width: 300,
        height: 300,
        child: AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            return CustomPaint(
              painter: _PowerButtonPainter(
                isConnected: isConnected,
                isConnecting: isConnecting,
                pulseValue:
                    pulseController.isAnimating ? pulseController.value : 0,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isConnecting)
                      const SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.goldAccent,
                        ),
                      )
                    else if (isConnected)
                      const Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.shield, color: Color(0xFF27c46d), size: 56),
                          Icon(Icons.check, color: Colors.white, size: 30),
                        ],
                      )
                    else
                      const Icon(Icons.power_settings_new,
                          color: AppTheme.goldAccent, size: 56),
                    const SizedBox(height: 10),
                    Text(
                      isConnecting
                          ? 'ПОДКЛЮЧЕНИЕ...'
                          : (isConnected ? 'ПОДКЛЮЧЕНО' : 'ПОДКЛЮЧИТЬ'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isConnected
                            ? AppTheme.goldAccent
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (isConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _uptimeText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
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
  final bool isConnecting;
  final double pulseValue;

  _PowerButtonPainter({
    required this.isConnected,
    required this.isConnecting,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - 46;
    final active = isConnected || isConnecting;

    // 1. Мягкое внешнее свечение (сильнее при подключении)
    final glowAlpha = active ? 0.38 - pulseValue * 0.10 : 0.16;
    final glowRadius = baseRadius + 34 + (active ? pulseValue * 10 : 0);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.goldAccent.withValues(alpha: glowAlpha.clamp(0.0, 1.0)),
          AppTheme.goldAccent
              .withValues(alpha: (glowAlpha * 0.4).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.45, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Тонкие лучи разной длины
    const rayCount = 64;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * 2 * pi - pi / 2;
      final len = 8.0 + ((i * 7) % 13) + (active ? pulseValue * 4 : 0);
      final inner = Offset(
        center.dx + (baseRadius + 7) * cos(angle),
        center.dy + (baseRadius + 7) * sin(angle),
      );
      final outer = Offset(
        center.dx + (baseRadius + 7 + len) * cos(angle),
        center.dy + (baseRadius + 7 + len) * sin(angle),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color =
              AppTheme.goldAccent.withValues(alpha: active ? 0.75 : 0.45)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );
    }

    // 3. Тёмный круг
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()..color = const Color(0xFF0a0d14),
    );

    // 4. Золотое кольцо
    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color =
            AppTheme.goldAccent.withValues(alpha: active ? 0.95 : 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isConnected ? 3.0 : 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _PowerButtonPainter oldDelegate) {
    return oldDelegate.isConnected != isConnected ||
        oldDelegate.isConnecting != isConnecting ||
        oldDelegate.pulseValue != pulseValue;
  }
}
