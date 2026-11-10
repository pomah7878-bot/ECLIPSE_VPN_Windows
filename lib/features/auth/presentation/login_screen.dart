import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/eclipse_logo.dart';

/// Содержимое экрана входа — по Android-приложению:
/// логотип затмения, ECLIPSE / Unlimited, подзаголовок,
/// две золотые пилюли (Google / Яндекс), две контурные (код бота / телефон),
/// серая подсказка. Нижняя навигация рисуется оболочкой MainScreen.
class LoginContent extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const LoginContent({super.key, required this.onLoggedIn});

  @override
  State<LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<LoginContent> {
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

  void _finishLogin() {
    SessionService.setLoggedIn(true);
    widget.onLoggedIn();
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
      _finishLogin();
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
      _finishLogin();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Ошибка авторизации: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPhoneNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Вход по номеру телефона — в разработке'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          'Код из Telegram-бота',
          style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _codeController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Введите код',
            prefixIcon: Icon(Icons.key, color: AppTheme.goldAccent),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _loginWithCode();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loginWithCode();
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.eclipseBlack,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const EclipseLogo(size: 150),
                const SizedBox(height: 12),
                const Text(
                  'ECLIPSE',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppTheme.goldAccent,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Unlimited',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.goldAccent,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'VPN без сложных настроек',
                  style: TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 32),
                _PillButton(
                  label: 'Войти через Google',
                  gold: true,
                  onPressed: _isLoading
                      ? null
                      : () => _loginWithOAuth(OAuthProvider.google),
                ),
                const SizedBox(height: 14),
                _PillButton(
                  label: 'Войти через Яндекс',
                  gold: true,
                  onPressed: _isLoading
                      ? null
                      : () => _loginWithOAuth(OAuthProvider.yandex),
                ),
                const SizedBox(height: 14),
                _PillButton(
                  label: 'Код из Telegram-бота',
                  gold: false,
                  onPressed: _isLoading ? null : _showCodeDialog,
                ),
                const SizedBox(height: 14),
                _PillButton(
                  label: 'Войти по номеру телефона',
                  gold: false,
                  onPressed: _isLoading ? null : _showPhoneNotice,
                ),
                const SizedBox(height: 18),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.goldAccent),
                    ),
                  ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.errorRed, fontSize: 13),
                    ),
                  ),
                const Text(
                  'Уже покупали через бота? Войдите кодом из бота —\nподписка и баланс подтянутся.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Пилюля-кнопка как в Android: золотой градиент с тёмным текстом
/// или контур с золотой рамкой и белым текстом.
class _PillButton extends StatelessWidget {
  final String label;
  final bool gold;
  final VoidCallback? onPressed;

  const _PillButton({
    required this.label,
    required this.gold,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (gold) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(28),
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppTheme.eclipseBlack,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
