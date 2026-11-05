import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// Экран добавления конфигурации по QR-коду или ссылке (аналог ScannerActivity в Android)
/// На Windows — ввод ссылки или вставка из буфера обмена
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _urlController = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить конфигурацию')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Иконка
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 40,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              'Добавить сервер',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Вставьте ссылку конфигурации\n(vless://, vmess://, hysteria2://)',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Поле ввода
            TextField(
              controller: _urlController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'vless://uuid@server:port?...',
                errorText: _error,
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            
            // Кнопка вставки из буфера
            OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.paste),
              label: const Text('Вставить из буфера'),
            ),
            const SizedBox(height: 24),
            
            // Кнопка добавления
            ElevatedButton(
              onPressed: _addConfig,
              child: const Text('Добавить сервер'),
            ),
            
            const Spacer(),
            
            // Подсказка
            Text(
              'Ссылку можно получить в боте или на сайте',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlController.text = data!.text!;
        _error = null;
      });
    }
  }

  void _addConfig() {
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      setState(() => _error = 'Введите ссылку конфигурации');
      return;
    }

    // Проверка формата
    if (!_isValidConfigUrl(url)) {
      setState(() => _error = 'Неверный формат ссылки');
      return;
    }

    // TODO: Сохранить конфигурацию
    Navigator.pop(context, url);
  }

  bool _isValidConfigUrl(String url) {
    final validPrefixes = ['vless://', 'vmess://', 'hysteria2://', 'trojan://', 'ss://'];
    return validPrefixes.any((prefix) => url.startsWith(prefix));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
