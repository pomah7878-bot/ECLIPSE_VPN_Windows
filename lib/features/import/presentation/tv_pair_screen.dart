import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/tv_pair_api.dart';
import '../../../core/services/import_service.dart';
import '../../../core/theme/app_theme.dart';

/// Перенос подписки с телефона на Windows по QR-коду.
class TvPairScreen extends StatefulWidget {
  const TvPairScreen({super.key});

  @override
  State<TvPairScreen> createState() => _TvPairScreenState();
}

class _TvPairScreenState extends State<TvPairScreen> {
  final _api = TvPairApi();
  TvPairSession? _session;
  Timer? _poll;
  bool _loading = true;
  bool _received = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _create();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
      _received = false;
    });
    try {
      final session = await _api.create();
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось создать QR. Проверьте подключение.';
      });
    }
  }

  Future<void> _check() async {
    final session = _session;
    if (session == null || _received) return;
    try {
      final body = await _api.fetchBody(session);
      if (!mounted || body == null) return;
      await ImportService().setBody(body);
      _poll?.cancel();
      if (!mounted) return;
      setState(() => _received = true);
    } catch (_) {
      // сеть моргнула — следующий тик попробует снова
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Перенос с телефона')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Откройте ECLIPSE на телефоне, зайдите в профиль и выберите перенос подписки. '
            'Отсканируйте этот QR — подписка появится на компьютере.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          if (_loading)
            Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: AppTheme.goldAccent)))
          else if (_error != null)
            Column(
              children: [
                Text(_error!, style: TextStyle(color: AppTheme.errorRed)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _create, child: const Text('Повторить')),
              ],
            )
          else if (_received)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.goldAccent),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successGreen, size: 46),
                  const SizedBox(height: 10),
                  const Text('Подписка получена', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Нажмите «Готово» и подключитесь на главной.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Готово')),
                ],
              ),
            )
          else if (_session != null)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: QrImageView(data: _session!.url, size: 220),
                ),
                const SizedBox(height: 12),
                Text('Код: ${_session!.code}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent)),
                    SizedBox(width: 10),
                    Text('Ждём подписку с телефона…', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 14),
                TextButton(onPressed: _create, child: const Text('Обновить QR')),
              ],
            ),
        ],
      ),
    );
  }
}
