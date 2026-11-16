import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/split_tunnel_service.dart';
import '../../../core/theme/app_theme.dart';

/// Раздельный туннель: выбранные процессы ходят напрямую, мимо VPN.
class SplitTunnelScreen extends StatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  State<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends State<SplitTunnelScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add(String value) async {
    if (value.trim().isEmpty) return;
    await SplitTunnelService().add(value);
    _controller.clear();
    if (mounted) setState(() {});
  }

  Future<void> _pickRunning() async {
    final names = <String>{};
    try {
      final result = await Process.run('tasklist', ['/fo', 'csv', '/nh']);
      for (final line in '${result.stdout}'.split(RegExp(r'\r?\n'))) {
        final match = RegExp(r'^"([^"]+)"').firstMatch(line.trim());
        if (match != null) {
          final name = match.group(1)!.toLowerCase();
          if (name.endsWith('.exe')) names.add(name);
        }
      }
    } catch (_) {
      // tasklist недоступен — останется ручной ввод
    }
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Запущенные приложения'),
        children: [
          if (names.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Список недоступен'))
          else
            SizedBox(
              width: 360,
              height: 420,
              child: ListView(
                children: names
                    .map((name) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, name),
                          child: Text(name),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await _add(chosen);
  }

  Widget _modeTile(String title, SplitTunnelMode value) {
    final selected = SplitTunnelService().mode == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppTheme.goldAccent : AppTheme.textMuted,
      ),
      title: Text(title),
      onTap: () async {
        await SplitTunnelService().setMode(value);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = SplitTunnelService();
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Раздельный туннель')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Выбранные приложения будут ходить в интернет напрямую, остальной трафик — через VPN. '
            'Изменения применяются при следующем подключении.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          _modeTile('Выключен', SplitTunnelMode.off),
          _modeTile('Выбранные приложения мимо VPN', SplitTunnelMode.exclude),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'chrome.exe',
              prefixIcon: const Icon(Icons.apps, color: AppTheme.goldAccent),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _add(_controller.text),
              ),
            ),
            onSubmitted: _add,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickRunning,
                icon: const Icon(Icons.list, size: 18),
                label: const Text('Выбрать из запущенных'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (service.processes.isEmpty)
            const Text('Список пуст', style: TextStyle(color: AppTheme.textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: service.processes
                  .map((p) => Chip(
                        backgroundColor: AppTheme.cardDark,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        label: Text(p),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () async {
                          await service.remove(p);
                          if (mounted) setState(() {});
                        },
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
