import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/import_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/app_theme.dart';

/// Импорт подписки по ссылке — гостевой режим без входа в аккаунт.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = ImportService().url ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _controller.text = text);
    }
  }

  Future<void> _import() async {
    final value = _controller.text.trim();
    if (!ImportService.looksSupported(value)) {
      setState(() => _error = 'Нужна ссылка на подписку или конфиг vless/vmess/trojan/hysteria2');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    if (value.startsWith('http://') || value.startsWith('https://')) {
      try {
        final servers = await SubscriptionService().fetch(value);
        if (servers.isEmpty) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'В подписке не найдено ни одного сервера';
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить подписку. Проверьте ссылку.';
        });
        return;
      }
    }
    await ImportService().setUrl(value);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    await ImportService().clear();
    if (!mounted) return;
    _controller.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final imported = ImportService().isImported;
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Импорт подписки')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Text(
              'Вставьте ссылку на подписку или одиночный конфиг. Это гостевой режим: '
              'аккаунт не нужен, но управлять ключом можно только в том сервисе, где он выдан.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'https://… или vless://…',
              prefixIcon: Icon(Icons.link, color: AppTheme.goldAccent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Вставить'),
              ),
              const Spacer(),
              if (imported)
                TextButton(
                  onPressed: _remove,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                  child: const Text('Удалить импорт'),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _import,
            child: Text(_loading ? 'Проверяем подписку…' : 'Импортировать'),
          ),
          if (imported) ...[
            const SizedBox(height: 12),
            const Text(
              'Импортированная подписка уже активна. При подключении приложение использует её вместо аккаунта.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
