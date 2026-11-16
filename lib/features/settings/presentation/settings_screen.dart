import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../../core/api/auth_api.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/services/auto_connect_service.dart';
import '../../../core/services/config_generator.dart';
import '../../../core/services/import_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../import/presentation/import_screen.dart';
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
  bool _autoconnect = false;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _autostart = SettingsService().autostartEnabled;
    _autoconnect = SettingsService().autoConnectEnabled;
  }

  Future<void> _toggleAutoConnect(bool value) async {
    await SettingsService().setAutoConnect(value);
    if (mounted) setState(() => _autoconnect = value);
    if (value) await AutoConnectService().tryNow();
  }

  Future<String?> _askPin(String title) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(hintText: '4–8 цифр', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('OK')),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }

  Future<void> _toggleAppLock() async {
    final lock = AppLockService();
    if (lock.enabled) {
      final pin = await _askPin('Введите текущий PIN');
      if (pin == null) return;
      if (!await lock.verify(pin)) {
        _snack('Неверный PIN');
        return;
      }
      await lock.disable();
      if (mounted) setState(() {});
      _snack('Блокировка выключена');
      return;
    }
    final first = await _askPin('Придумайте PIN');
    if (first == null || first.isEmpty) return;
    final second = await _askPin('Повторите PIN');
    if (second == null) return;
    if (first != second) {
      _snack('PIN не совпадает');
      return;
    }
    if (!await lock.setPin(first)) {
      _snack('PIN должен состоять из 4–8 цифр');
      return;
    }
    if (mounted) setState(() {});
    _snack('Блокировка включена');
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final info = await UpdateService().check();
      if (!mounted) return;
      if (info == null) {
        _snack('У вас последняя версия');
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: Text('Доступна версия ${info.version}'),
          content: Text('Скачать и установить обновление${info.sizeText.isNotEmpty ? ' (${info.sizeText})' : ''}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Позже')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Обновить')),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      final progress = ValueNotifier<double>(0);
      final dialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: const Text('Загрузка обновления'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value > 0 ? value : null, color: AppTheme.goldAccent),
                const SizedBox(height: 10),
                Text('${(value * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
      try {
        final path = await UpdateService().download(info, (p) => progress.value = p);
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        await UpdateService().runInstaller(path);
        exit(0);
      } catch (e) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _snack('Не удалось скачать обновление');
      } finally {
        progress.dispose();
        await dialog;
      }
    } catch (_) {
      _snack('Не удалось проверить обновление');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
              activeThumbColor: AppTheme.goldAccent,
              onChanged: _toggleAutostart,
            ),
          ),
          _tile(
            icon: Icons.bolt,
            title: 'Автоподключение',
            subtitle: _autoconnect ? 'VPN включается при появлении сети' : 'Выключено',
            trailing: Switch(
              value: _autoconnect,
              activeThumbColor: AppTheme.goldAccent,
              onChanged: _toggleAutoConnect,
            ),
          ),
          _tile(
            icon: Icons.link,
            title: 'Импорт подписки',
            subtitle: ImportService().isImported ? 'Импортированная подписка активна' : 'Ссылка или конфиг',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          _section('Безопасность'),
          _tile(
            icon: Icons.lock_outline,
            title: 'Блокировка приложения',
            subtitle: AppLockService().enabled ? 'Включена — PIN при запуске' : 'Выключена',
            onTap: _toggleAppLock,
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
            subtitle: _checkingUpdate ? 'Проверяем…' : 'Проверить и установить',
            onTap: _checkingUpdate ? null : _checkUpdate,
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
