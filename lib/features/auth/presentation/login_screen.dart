import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/tray_service.dart';
import '../../home/presentation/home_screen.dart';
import 'oauth_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeController = TextEditingController();
  final _authApi = AuthApi();
  final _oauthService = OAuthService();
  final _trayService = TrayService();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите код доступа');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _authApi.loginWithCode(code);
      
      if (result.ok && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(trayService: _trayService),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Ошибка соединения. Проверьте интернет.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _oauthService.signInWithProvider(provider);
      
      if (result.ok && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(trayService: _trayService),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              
              // Логотип
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 50,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Заголовок
              Text(
                'ECLIPSE VPN',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Введите код доступа из бота',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Поле ввода
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  hintText: 'Код доступа',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.key_outlined),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              
              // Кнопка входа
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Войти'),
              ),
              
              // OAuth-кнопки
              OAuthButtons(
                onSignIn: _signInWithOAuth,
                isLoading: _isLoading,
              ),
              
              const Spacer(flex: 3),
              
              // Подсказка
              Text(
                'Код можно получить в Telegram-боте',
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}