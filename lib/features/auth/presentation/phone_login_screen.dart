import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/theme/app_theme.dart';

/// Вход по номеру телефона: звонок от/на сервисный номер, код или цифра.
/// Полностью серверный: после подтверждения сервер ставит cookie-сессию.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _auth = AuthApi();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Timer? _poll;

  bool _loading = false;
  PhoneRequestResponse? _request;
  String? _error;

  @override
  void dispose() {
    _poll?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestCall() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _auth.requestPhone(phone);
      if (!mounted) return;
      setState(() {
        _request = result;
        _loading = false;
      });
      if (!result.needsCode) _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Не удалось запросить звонок';
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check(null));
  }

  Future<void> _check(String? enteredCode) async {
    final request = _request;
    if (request?.callId == null) return;
    final result = await _auth.checkPhone(
      phone: _phoneController.text.trim(),
      callId: request!.callId!,
      enteredCode: enteredCode,
    );
    if (!mounted) return;
    if (result.verified) {
      _poll?.cancel();
      Navigator.pop(context, true);
      return;
    }
    if (result.message != null && result.message!.isNotEmpty && enteredCode != null) {
      setState(() => _error = result.message);
    }
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Введите код');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await _check(code);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Вход по номеру')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_request == null) ...[
            Text(
              'Введите номер телефона — сервис позвонит на него для подтверждения. '
              'Звонок бесплатный, номер используется только для входа.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '+7 999 123-45-67',
                prefixIcon: Icon(Icons.phone, color: AppTheme.goldAccent),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _requestCall,
              child: Text(_loading ? 'Запрашиваем звонок…' : 'Позвонить мне'),
            ),
          ] else
            _buildSteps(_request!),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: AppTheme.errorRed, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildSteps(PhoneRequestResponse request) {
    final method = request.method;
    String title;
    String detail;
    switch (method) {
      case 'pincode':
        title = 'Введите код на телефоне';
        detail = 'Мы звоним вам. Введите этот код с клавиатуры телефона:\n${request.pincode ?? ''}';
        break;
      case 'flash_call':
        title = 'Позвоните на сервисный номер';
        detail = request.allowedPhones.isEmpty
            ? 'Позвоните на номер из сообщения сервиса и не сбрасывайте до подтверждения.'
            : 'Позвоните на номер:\n${request.allowedPhones.join('\n')}\nи дождитесь подтверждения.';
        break;
      case 'flashcall_real':
        title = 'Введите 4 цифры';
        detail = 'Введите последние 4 цифры номера, с которого поступил звонок.';
        break;
      case 'voice_code':
        title = 'Введите код из звонка';
        detail = 'Робот продиктует код — введите его ниже.';
        break;
      case 'press_digit':
        title = 'Ответьте на звонок';
        detail = 'Ответьте на звонок и нажмите цифру, которую попросит робот.';
        break;
      default:
        title = 'Подтвердите номер';
        detail = 'Следуйте инструкциям сервиса.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(detail, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        if (request.needsCode) ...[
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Код'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _submitCode,
            child: const Text('Подтвердить'),
          ),
        ] else
          Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: AppTheme.goldAccent),
            ),
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            _poll?.cancel();
            setState(() {
              _request = null;
              _error = null;
            });
          },
          child: const Text('Запросить звонок заново'),
        ),
      ],
    );
  }
}
