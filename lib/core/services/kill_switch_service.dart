import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_service.dart';
import 'vpn_service.dart';

/// Kill Switch для Windows.
///
/// Включается только явно. Пока защита активна, исходящий трафик разрешён
/// только ECLIPSE, sing-box и системному DNS/DHCP. При выходе из приложения
/// правила снимаются, а при следующем запуске выполняется восстановление —
/// чтобы сбой не оставил компьютер без сети.
class KillSwitchService {
  static final KillSwitchService _instance = KillSwitchService._internal();
  factory KillSwitchService() => _instance;
  KillSwitchService._internal();

  static const _ruleApp = 'ECLIPSE VPN Kill Switch App';
  static const _ruleCore = 'ECLIPSE VPN Kill Switch Core';
  static const _ruleDnsUdp = 'ECLIPSE VPN Kill Switch DNS UDP';
  static const _ruleDnsTcp = 'ECLIPSE VPN Kill Switch DNS TCP';
  static const _ruleDhcp = 'ECLIPSE VPN Kill Switch DHCP';
  static const _ruleLan = 'ECLIPSE VPN Kill Switch LAN';
  static const _markerKey = 'kill_switch_active';

  bool _active = false;
  bool get active => _active;
  bool get enabled => SettingsService().killSwitchEnabled;

  Future<void> _setMarker(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_markerKey, value);
  }

  Future<bool> _hasMarker() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_markerKey) ?? false;
  }

  Future<bool> isAdministrator() async {
    try {
      final result = await Process.run('net', ['session']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Вызывается при старте: снимает возможные правила прошлого сбоя.
  Future<void> recoverOnStartup() async {
    if (!Platform.isWindows) return;
    if (!await _hasMarker()) return;
    await _restore(quiet: true, force: true);
  }

  Future<void> enable() async {
    if (!await isAdministrator()) {
      throw const KillSwitchException('Нужны права администратора');
    }
    await SettingsService().setKillSwitch(true);
    if (VpnService().isConnected) {
      try {
        await _apply();
      } catch (_) {
        await SettingsService().setKillSwitch(false);
        rethrow;
      }
    }
  }

  Future<void> disable() async {
    await SettingsService().setKillSwitch(false);
    await _restore(quiet: false);
  }

  /// Вызывается после успешного подключения VPN.
  Future<void> onConnected() async {
    if (!enabled || _active) return;
    try {
      await _apply();
    } catch (_) {
      await SettingsService().setKillSwitch(false);
      rethrow;
    }
  }

  /// Вызывается при выходе из приложения.
  Future<void> onExit() async {
    await _restore(quiet: true);
  }

  Future<void> _apply() async {
    if (!Platform.isWindows) return;
    final exe = Platform.resolvedExecutable;
    final core = p.join(p.dirname(exe), 'sing-box.exe');
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final svchost = p.join(systemRoot, 'System32', 'svchost.exe');
    if (!File(core).existsSync()) {
      throw const KillSwitchException('sing-box.exe не найден');
    }
    if (!File(svchost).existsSync()) {
      throw const KillSwitchException('Системный DNS не найден');
    }

    await _deleteRules();
    final okApp = await _addProgramRule(_ruleApp, exe);
    final okCore = await _addProgramRule(_ruleCore, core);
    final okDns = await _addServiceRule(_ruleDnsUdp, svchost, 'udp', 53) &&
        await _addServiceRule(_ruleDnsTcp, svchost, 'tcp', 53);
    final okDhcp = await _addServiceRule(_ruleDhcp, svchost, 'udp', 67);
    final okLan = await _addLanRule();
    if (!okApp || !okCore || !okDns || !okDhcp || !okLan) {
      await _deleteRules();
      throw const KillSwitchException('Не удалось создать правила Firewall');
    }

    // Маркер ставим ДО смены политики: если приложение упадёт между этими
    // шагами, следующий запуск всё равно снимет блокировку.
    await _setMarker(true);
    final result = await Process.run('netsh', [
      'advfirewall',
      'set',
      'allprofiles',
      'firewallpolicy',
      'blockinbound,blockoutbound',
    ]);
    if (result.exitCode != 0) {
      await _deleteRules();
      await _setMarker(false);
      throw const KillSwitchException('Не удалось включить блокировку');
    }
    _active = true;
  }

  Future<void> _restore({required bool quiet, bool force = false}) async {
    if (!Platform.isWindows) return;
    if (!_active && !force) return;
    try {
      await _deleteRules();
      await Process.run('netsh', [
        'advfirewall',
        'set',
        'allprofiles',
        'firewallpolicy',
        'blockinbound,allowoutbound',
      ]);
    } catch (e) {
      if (!quiet) throw KillSwitchException('Не удалось снять блокировку: $e');
    } finally {
      _active = false;
      await _setMarker(false);
    }
  }

  Future<void> _deleteRules() async {
    for (final name in [_ruleApp, _ruleCore, _ruleDnsUdp, _ruleDnsTcp, _ruleDhcp, _ruleLan]) {
      await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'delete',
        'rule',
        'name=$name',
      ]);
    }
  }

  Future<bool> _addProgramRule(String name, String program) async {
    final result = await Process.run('netsh', [
      'advfirewall',
      'firewall',
      'add',
      'rule',
      'name=$name',
      'dir=out',
      'action=allow',
      'program="$program"',
      'enable=yes',
      'profile=any',
    ]);
    return result.exitCode == 0;
  }

  Future<bool> _addServiceRule(
    String name,
    String program,
    String protocol,
    int remotePort,
  ) async {
    final result = await Process.run('netsh', [
      'advfirewall',
      'firewall',
      'add',
      'rule',
      'name=$name',
      'dir=out',
      'action=allow',
      'program="$program"',
      'protocol=$protocol',
      'remoteport=$remotePort',
      'enable=yes',
      'profile=any',
    ]);
    return result.exitCode == 0;
  }

  Future<bool> _addLanRule() async {
    final result = await Process.run('netsh', [
      'advfirewall',
      'firewall',
      'add',
      'rule',
      'name=$_ruleLan',
      'dir=out',
      'action=allow',
      'remoteip=localsubnet',
      'enable=yes',
      'profile=any',
    ]);
    return result.exitCode == 0;
  }
}

class KillSwitchException implements Exception {
  final String message;
  const KillSwitchException(this.message);

  @override
  String toString() => message;
}
