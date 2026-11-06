import 'package:flutter/material.dart';
import '../../core/api/auth_api.dart';
import '../../core/services/oauth_service.dart';
import '../../core/theme/app_theme.dart';
import 'main_screen.dart';

/// Экран входа — полная копия Android-приложения.
///
/// Скриншот: https://eclipse.unlimited.bot.nu/static/app-preview/login.jpg
/// - Логотип затмения вверху
/// - Золотые кнопки Google / Yandex
/// - Темные кнопки "Код из Telegram-бота" / "Войти по номеру"
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeController = TextEditingController();
  final _authApi = AuthApi();
  final _oauthService = OAuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loginWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Введите код доступа');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authApi.loginWithCode(code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка сети. Проверьте подключение.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithOAuth(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _oauthService.signInWithProvider(provider);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка авторизации: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Код из Telegram-бота',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                hintText: 'Введите код',
                prefixIcon: Icon(Icons.key, color: AppTheme.goldAccent),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loginWithCode(),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loginWithCode();
            },
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.eclipseBlack),
                  )
                : const Text('Войти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Логотип затмения
              _EclipseLogo(),

              const SizedBox(height: 24),

              // Название
              const Text(
                'ECLIPSE',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: AppTheme.goldAccent,
                ),
              ),
              const Text(
                'Unlimited',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.goldLight,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'VPN без сложных настроек',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),

              const Spacer(flex: 3),

              // Кнопки входа
              _GoldButton(
                icon: Icons.g_mobiledata,
                label: 'Войти через Google',
                onPressed: () => _loginWithOAuth(OAuthProvider.google),
              ),

              const SizedBox(height: 12),

              _GoldButton(
                icon: Icons.account_circle_outlined,
                label: 'Войти через Яндекс',
                onPressed: () => _loginWithOAuth(OAuthProvider.yandex),
              ),

              const SizedBox(height: 12),

              _DarkButton(
                icon: Icons.telegram,
                label: 'Код из Telegram-бота',
                onPressed: _showCodeDialog,
              ),

              const SizedBox(height: 12),

              _DarkButton(
                icon: Icons.phone,
                label: 'Войти по номеру телефона',
                onPressed: () {
                  setState(() => _errorMessage = 'В разработке');
                },
              ),

              const SizedBox(height: 20),

              // Подсказка
              const Text(
                'Уже покупали через бота? Войдите кодом из бота — подписка и баланс подтянутся.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                  ),
                ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Логотип затмения — SVG-like через CustomPaint
class _EclipseLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _EclipsePainter(),
      ),
    );
  }
}

class _EclipsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Внешнее свечение (градиент)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.goldAccent.withOpacity(0.4),
          AppTheme.goldAccent.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius, glowPaint);

    // Солнце (золотой круг)
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        colors: [AppTheme.goldAccent, AppTheme.goldLight],
        center: Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.85));
    canvas.drawCircle(center, radius * 0.85, sunPaint);

    // Луна (темный круг, перекрывающая часть солнца)
    final moonPaint = Paint()..color = AppTheme.eclipseBlack;
    canvas.drawCircle(
      Offset(center.dx + radius * 0.25, center.dy - radius * 0.05),
      radius * 0.75,
      moonPaint,
    );

    // Корональное свечение (лучи)
    final rayPaint = Paint()
      ..color = AppTheme.goldAccent.withOpacity(0.15)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 24; i++) {
      final angle = (i / 24) * 2 * 3.14159;
      final inner = Offset(
        center.dx + (radius * 0.88) * cos(angle),
        center.dy + (radius * 0.88) * sin(angle),
      );
      final outer = Offset(
        center.dx + (radius * 1.15) * cos(angle),
        center.dy + (radius * 1.15) * sin(angle),
      );
      canvas.drawLine(inner, outer, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Золотая кнопка (Google / Yandex)
class _GoldButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _GoldButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.eclipseBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Темная кнопка (Telegram / Телефон)
class _DarkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _DarkButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: AppTheme.goldAccent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
