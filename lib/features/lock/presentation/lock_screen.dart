import 'package:flutter/material.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/eclipse_logo.dart';

/// Экран PIN-блокировки приложения.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await AppLockService().verify(pin);
    if (!mounted) return;
    if (ok) {
      AppLockService().unlock();
    } else {
      setState(() {
        _checking = false;
        _error = 'Неверный PIN';
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EclipseLogo(size: 92),
                const SizedBox(height: 20),
                const Text('ECLIPSE VPN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Введите PIN для входа', style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 20),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(hintText: '••••', counterText: ''),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: AppTheme.errorRed)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _checking ? null : _submit,
                    child: Text(_checking ? 'Проверяем…' : 'Войти'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
