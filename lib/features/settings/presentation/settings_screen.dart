import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/auth_api.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../modes/presentation/modes_screen.dart';
import '../../support/presentation/support_screen.dart';

/// Настройки Windows-клиента: маршрутизация, автозапуск, версия, поддержка.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthApi();
  bool _autostart = false;

  @override
  void initState() {
    super.initState();
    _autostart = SettingsService().autostartEnabled;
  }

  Future<void> _toggleAutostart(bool value) async {
    try {
      if (value) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      await SettingsService().setAutostart(value);
    } catch (_) {
      // настройка не критична
    }
    if (mounted) setState(() => _autostart = value);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Выйти из аккаунта?'),
        content: const Text('VPN будет отключён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _auth.logout();
    } catch (_) {}
    SessionService.setLoggedIn(false);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final mode = SettingsService().routingMode;
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('VPN'),
          _tile(
            icon: Icons.alt_route,
            title: 'Маршрутизация',
            subtitle: mode.title,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModesScreen()),
            ).then((_) => setState(() {})),
          ),
          _tile(
            icon: Icons.power_settings_new,
            title: 'Автозапуск',
            subtitle: _autostart ? 'Включён' : 'Выключен',
            trailing: Switch(
              value: _autostart,
              activeColor: AppTheme.goldAccent,
              onChanged: _toggleAutostart,
            ),
          ),
          _section('Приложение'),
          _tile(
            icon: Icons.info_outline,
            title: 'Версия',
            subtitle: SupportScreen.appVersion,
          ),
          _tile(
            icon: Icons.system_update_alt,
            title: 'Обновление',
            subtitle: 'Скачать новую версию',
            onTap: () async {
              final uri = Uri.parse(
                'https://github.com/pomah7878-bot/ECLIPSE_VPN_Windows/releases/latest',
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          _tile(
            icon: Icons.support_agent,
            title: 'Поддержка и диагностика',
            subtitle: 'Отправить лог разработчику',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          _section('Аккаунт'),
          _tile(
            icon: Icons.logout,
            title: 'Выйти',
            subtitle: 'Завершить сессию',
            color: AppTheme.errorRed,
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
        child: Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color ?? AppTheme.goldAccent),
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppTheme.textMuted) : null),
      ),
    );
  }
}
