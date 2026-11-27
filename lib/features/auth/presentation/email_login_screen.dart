import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/theme/app_theme.dart';

/// Вход по коду, присланному на email. Сервер ставит cookie-сессию.
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _auth = AuthApi();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _loading = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.emailStart(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Нет связи с сервером';
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите код из письма');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.emailVerify(_emailController.text.trim(), code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Нет связи с сервером';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Вход по email')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _codeSent
                ? 'Код отправлен на ${_emailController.text.trim()}. Он действует 10 минут.'
                : 'Введите email, на который оформлена подписка. Пришлём 6-значный код.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_codeSent,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.mail, color: AppTheme.goldAccent),
            ),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Код из письма'),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : (_codeSent ? _verify : _sendCode),
            child: Text(_loading
                ? 'Проверяем…'
                : (_codeSent ? 'Войти' : 'Отправить код')),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : _sendCode,
              child: const Text('Отправить код заново'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: AppTheme.errorRed, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
