import 'dart:async';
import 'dart:io';

import 'import_service.dart';
import 'session_service.dart';
import 'settings_service.dart';
import 'vpn_service.dart';

/// Автоподключение: при старте приложения и при появлении сети.
/// Ручное отключение не перебивается, пока сеть не пропадёт и не вернётся.
class AutoConnectService {
  static final AutoConnectService _instance = AutoConnectService._internal();
  factory AutoConnectService() => _instance;
  AutoConnectService._internal();

  Timer? _timer;
  bool? _wasOnline;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check(initial: false));
    _check(initial: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> tryNow() async {
    final online = await _online();
    _wasOnline = online;
    if (online) await _connect();
  }

  Future<void> _check({required bool initial}) async {
    if (!SettingsService().autoConnectEnabled) {
      _wasOnline = null;
      return;
    }
    if (!SessionService.loggedIn.value && !ImportService().hasImport.value) {
      return;
    }
    final vpn = VpnService();
    if (vpn.isConnected || vpn.isBusy) return;

    final online = await _online();
    final appeared = online && _wasOnline == false;
    _wasOnline = online;
    if (online && (initial || appeared)) {
      await _connect();
    }
  }

  Future<void> _connect() async {
    final vpn = VpnService();
    if (vpn.isConnected || vpn.isBusy) return;
    await vpn.connect();
  }

  Future<bool> _online() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
