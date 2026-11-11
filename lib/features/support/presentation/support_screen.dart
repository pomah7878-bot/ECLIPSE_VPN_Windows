import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/support_api.dart';
import '../../../core/services/config_generator.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/vpn_service.dart';
import '../../../core/theme/app_theme.dart';

/// Вкладка «Поддержка» — чат с AI-помощником ECLIPSE, как в Android:
/// приветствие, пузыри сообщений, поле ввода с отправкой,
/// кнопка «Подготовить диагностику», эскалация к человеку.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  static const String appVersion = '0.2.1';

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const String _greeting =
      'Здравствуйте! Я AI-помощник ECLIPSE. Опишите проблему, можно приложить скриншот.';

  final _api = SupportApi();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [
    _Message(text: _greeting, mine: false),
  ];
  bool _sending = false;
  bool _escalate = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _prepareDiagnostics() {
    final vpn = VpnService();
    final status = vpn.currentStatus;
    final lines = vpn.logs.split('\n');
    final logTail = vpn.logs.isEmpty
        ? 'логи пусты'
        : lines.skip(lines.length > 25 ? lines.length - 25 : 0).join('\n');

    final report = [
      'Диагностика ECLIPSE VPN Windows ${SupportScreen.appVersion}',
      'ОС: ${Platform.operatingSystemVersion}',
      'VPN: ${status.state.name}, сервер: ${status.server.isEmpty ? "—" : status.server}',
      'Режим: ${SettingsService().routingMode.title}',
      'Логи (последние строки):',
      logTail,
    ].join('\n');

    final existing = _controller.text.trim();
    _controller.text = existing.isEmpty ? report : '$existing\n\n$report';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Диагностика готова. Проверьте текст перед отправкой'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _messages.add(_Message(text: text, mine: true));
      _escalate = false;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final reply = await _api.ask(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(text: reply.text, mine: false));
        _escalate = reply.escalate;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(text: e.message, mine: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Message(
          text: 'Не удалось получить ответ, попробуйте ещё раз',
          mine: false,
        ));
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse('https://t.me/EclipseVPNBot');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Поддержка')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(message: _messages[i]),
            ),
          ),
          if (_escalate)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: _openTelegram,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.goldAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.goldAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Помощник рекомендует обратиться к человеку.\n'
                    'Нажмите, чтобы открыть Telegram @EclipseVPNBot',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.goldAccent),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _prepareDiagnostics,
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: const Text('Подготовить диагностику'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Ваше сообщение',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.goldAccent),
                        )
                      : const Icon(Icons.send, color: AppTheme.goldAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool mine;

  _Message({required this.text, required this.mine});
}

class _Bubble extends StatelessWidget {
  final _Message message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: mine ? AppTheme.goldAccent : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mine ? Colors.transparent : AppTheme.cardBorder,
          ),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: mine ? AppTheme.eclipseBlack : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
