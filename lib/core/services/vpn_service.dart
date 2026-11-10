import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/auth_api.dart';
import '../api/keys_api.dart';
import 'config_generator.dart';
import 'settings_service.dart';
import 'subscription_service.dart';

/// Состояние VPN-подключения.
enum VpnState { disconnected, connecting, connected, disconnecting, error }

/// Снимок состояния для UI.
class VpnStatus {
  final VpnState state;
  final String message;
  final String server;
  final double downloadMbps;
  final double uploadMbps;
  final int? pingMs;
  final Duration uptime;

  const VpnStatus({
    required this.state,
    this.message = '',
    this.server = '',
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.pingMs,
    this.uptime = Duration.zero,
  });

  bool get isConnected => state == VpnState.connected;
  bool get isConnecting =>
      state == VpnState.connecting || state == VpnState.disconnecting;
}

/// Управление VPN через sing-box.exe (TUN + wintun).
///
/// Цикл подключения:
/// 1. Сессия → активный ключ → inbound-конфиги сервера
/// 2. Парсинг ссылки (vless/vmess/trojan/hysteria2)
/// 3. Генерация конфига sing-box под выбранный режим маршрутизации
/// 4. Валидация `sing-box check` перед запуском
/// 5. Запуск процесса, мониторинг, реальная статистика трафика и пинга
class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  static const int _maxLogLines = 400;
  static const String _tunName = ConfigGenerator.tunInterfaceName;

  Process? _process;
  VpnState _state = VpnState.disconnected;
  String _message = 'Отключено';
  String _server = '';
  DateTime? _connectedAt;
  Timer? _statsTimer;
  Timer? _pingTimer;
  int? _pingMs;
  double _downMbps = 0;
  double _upMbps = 0;
  int _lastRecvBytes = 0;
  int _lastSentBytes = 0;
  DateTime? _lastStatsAt;
  final List<String> _logLines = [];

  final _statusController = StreamController<VpnStatus>.broadcast();
  Stream<VpnStatus> get statusStream => _statusController.stream;

  VpnState get state => _state;
  bool get isConnected => _state == VpnState.connected;
  bool get isBusy =>
      _state == VpnState.connecting || _state == VpnState.disconnecting;
  String get logs => _logLines.join('\n');

  VpnStatus get currentStatus => VpnStatus(
        state: _state,
        message: _message,
        server: _server,
        downloadMbps: _downMbps,
        uploadMbps: _upMbps,
        pingMs: _pingMs,
        uptime: _connectedAt == null
            ? Duration.zero
            : DateTime.now().difference(_connectedAt!),
      );

  // ==================== ПОДКЛЮЧЕНИЕ ====================

  Future<bool> connect() async {
    if (isBusy || isConnected) return false;

    _setState(VpnState.connecting, 'Проверка прав...');
    _logLines.clear();

    try {
      // 0. Права администратора (нужны для TUN-адаптера)
      if (!await _isAdministrator()) {
        _log('ERROR: приложение запущено без прав администратора');
        _setState(VpnState.error,
            'Нужны права администратора.\nПерезапустите приложение от имени администратора.');
        return false;
      }

      // 1. Сессия и активный ключ
      _setState(VpnState.connecting, 'Проверка ключей...');
      final session = await AuthApi().getSession();
      if (session == null || !session.loggedIn || session.keys.isEmpty) {
        _setState(VpnState.error, 'Войдите в личный кабинет и купите ключ');
        return false;
      }

      final key = session.keys.firstWhere(
        (k) => k.isActive,
        orElse: () => session.keys.first,
      );

      // 2. Сервер: подписка по sub_url (как в Android), fallback — inbounds API
      _setState(VpnState.connecting, 'Получение сервера...');
      String link = '';
      _server = key.serverName ?? '';

      final subUrl = key.subUrl;
      if (subUrl != null && subUrl.isNotEmpty) {
        try {
          final servers = await SubscriptionService().fetch(subUrl);
          if (servers.isNotEmpty) {
            link = servers.first.link;
            if (servers.first.name.isNotEmpty) _server = servers.first.name;
            _log('Подписка: серверов ${servers.length}, выбран «$_server»');
          }
        } catch (e) {
          _log('Подписка не загрузилась ($e), пробую inbounds API');
        }
      }

      if (link.isEmpty) {
        final inbounds = await KeysApi().getKeyInbounds(key.keyId);
        if (inbounds.isNotEmpty) {
          final inbound = inbounds.first;
          link = inbound.link ?? inbound.config ?? '';
          _server = inbound.remark ?? _server;
        }
      }

      if (link.isEmpty) {
        _setState(VpnState.error, 'Нет доступных серверов');
        return false;
      }
      if (_server.isEmpty) _server = 'Автоподбор сервера';

      // 3. Конфиг sing-box
      _setState(VpnState.connecting, 'Создание конфига...');
      final mode = SettingsService().routingMode;
      final config = ConfigGenerator.generate(link: link, mode: mode);
      if (config == null) {
        _log('ERROR: неподдерживаемый формат ссылки: ${_maskLink(link)}');
        _setState(VpnState.error, 'Сервер вернул неподдерживаемый конфиг');
        return false;
      }

      final configPath = await _writeConfig(config);
      _log('Config: $configPath (режим: ${mode.title})');

      // 4. sing-box.exe + wintun.dll
      final exePath = _findSingBoxExe();
      if (exePath == null) {
        _setState(VpnState.error,
            'sing-box.exe не найден.\nПереустановите приложение.');
        return false;
      }
      _log('sing-box: $exePath');

      final wintunPath = p.join(p.dirname(exePath), 'wintun.dll');
      if (!File(wintunPath).existsSync()) {
        _log('ERROR: wintun.dll не найден: $wintunPath');
        _setState(VpnState.error,
            'wintun.dll не найден.\nПереустановите приложение.');
        return false;
      }

      // 5. Валидация конфига до запуска
      final check = await Process.run(
          exePath, ['check', '-c', configPath],
          workingDirectory: p.dirname(exePath));
      if (check.exitCode != 0) {
        final err = '${check.stdout}${check.stderr}'.trim();
        _log('sing-box check FAILED: $err');
        _setState(VpnState.error, 'Конфиг не прошёл проверку:\n$err');
        return false;
      }
      _log('sing-box check: OK');

      // 6. Запуск
      _setState(VpnState.connecting, 'Запуск VPN...');
      final started = await _startProcess(exePath, configPath);
      if (!started) return false;

      _connectedAt = DateTime.now();
      _setState(VpnState.connected, 'VPN подключён');
      _startStats();
      return true;
    } catch (e, st) {
      _log('ERROR: $e\n$st');
      _setState(VpnState.error, 'Ошибка: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_state == VpnState.disconnected) return;
    _setState(VpnState.disconnecting, 'Отключение...');
    await _stopProcess();
    _stopStats();
    _connectedAt = null;
    _server = '';
    _setState(VpnState.disconnected, 'Отключено');
  }

  /// Переподключение с новым режимом маршрутизации.
  Future<bool> reconnectWithMode(RoutingMode mode) async {
    await SettingsService().setRoutingMode(mode);
    if (!isConnected) return false;
    await disconnect();
    return connect();
  }

  // ==================== ПРОЦЕСС ====================

  Future<bool> _startProcess(String exePath, String configPath) async {
    await _stopProcess();
    // Убиваем осиротевший sing-box (после force-kill приложения) и ждём,
    // пока wintun освободит TUN-адаптер, иначе «file already exists».
    await _killOrphanedSingBox();
    await _waitTunReleased();

    try {
      _process = await Process.start(
        exePath,
        ['run', '-c', configPath, '--disable-color'],
        workingDirectory: p.dirname(exePath),
      );

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _log('[sing-box] $line'));
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _log('[sing-box ERR] $line'));

      // Даём время на создание TUN-адаптера; если процесс умер — ошибка.
      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 4),
        onTimeout: () => _stillRunningSentinel,
      );

      if (exitCode != _stillRunningSentinel) {
        _log('sing-box завершился сразу, код $exitCode');
        _process = null;
        _setState(VpnState.error,
            'VPN не запустился (код $exitCode).\nСмотрите логи ниже.');
        return false;
      }

      _log('sing-box запущен');
      return true;
    } catch (e) {
      _log('Не удалось запустить sing-box: $e');
      _setState(VpnState.error, 'Не удалось запустить sing-box: $e');
      return false;
    }
  }

  static const int _stillRunningSentinel = -99999;

  Future<void> _stopProcess() async {
    final proc = _process;
    _process = null;
    if (proc != null) {
      _log('Остановка sing-box (pid ${proc.pid})...');
      try {
        await Process.run('taskkill', ['/PID', '${proc.pid}', '/T', '/F']);
      } catch (_) {
        try {
          proc.kill(ProcessSignal.sigterm);
        } catch (_) {}
      }
      await _waitTunReleased();
    }
  }

  /// Убивает sing-box, оставшийся без родительского приложения.
  Future<void> _killOrphanedSingBox() async {
    try {
      final r = await Process.run('taskkill', ['/IM', 'sing-box.exe', '/F']);
      if (r.exitCode == 0) _log('Осиротевший sing-box остановлен');
    } catch (_) {}
  }

  /// Ждёт, пока wintun удалит TUN-адаптер после смерти процесса (до 4 с).
  Future<void> _waitTunReleased() async {
    for (var i = 0; i < 8; i++) {
      if (!await _tunExists()) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _log('TUN-адаптер $_tunName всё ещё занят предыдущим процессом');
  }

  Future<bool> _tunExists() async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "if (Get-NetAdapter -Name '$_tunName' -ErrorAction SilentlyContinue) { 'yes' } else { 'no' }",
      ]);
      return '${r.stdout}'.trim() == 'yes';
    } catch (_) {
      return false;
    }
  }

  // ==================== СТАТИСТИКА ====================

  void _startStats() {
    _lastRecvBytes = 0;
    _lastSentBytes = 0;
    _lastStatsAt = null;
    _pingMs = null;
    _downMbps = 0;
    _upMbps = 0;

    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStats());
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollPing());
    _pollStats();
    _pollPing();
  }

  void _stopStats() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _downMbps = 0;
    _upMbps = 0;
    _pingMs = null;
  }

  /// Реальные счётчики трафика TUN-адаптера через Get-NetAdapterStatistics.
  Future<void> _pollStats() async {
    if (!isConnected) return;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "\$s = Get-NetAdapterStatistics -Name '$_tunName' -ErrorAction SilentlyContinue | Select-Object -First 1; "
            "if (\$s) { Write-Output ('{0} {1}' -f \$s.ReceivedBytes, \$s.SentBytes) }",
      ]);
      final out = '${result.stdout}'.trim();
      final parts = out.split(RegExp(r'\s+'));
      if (parts.length != 2) return;
      final recv = int.tryParse(parts[0]);
      final sent = int.tryParse(parts[1]);
      if (recv == null || sent == null) return;

      final now = DateTime.now();
      final prevAt = _lastStatsAt;
      if (prevAt != null) {
        final dt = now.difference(prevAt).inMilliseconds / 1000.0;
        if (dt > 0.1) {
          _downMbps = (recv - _lastRecvBytes) * 8 / dt / 1e6;
          _upMbps = (sent - _lastSentBytes) * 8 / dt / 1e6;
          if (_downMbps < 0) _downMbps = 0;
          if (_upMbps < 0) _upMbps = 0;
        }
      }
      _lastRecvBytes = recv;
      _lastSentBytes = sent;
      _lastStatsAt = now;
      _emit();
    } catch (e) {
      debugPrint('Stats poll error: $e');
    }
  }

  /// Пинг через TUN (ICMP к 1.1.1.1).
  Future<void> _pollPing() async {
    if (!isConnected) return;
    try {
      final result = await Process.run(
          'ping', ['-n', '1', '-w', '2000', '1.1.1.1']);
      final out = '${result.stdout}';
      final m = RegExp(r'(?:time|время)[=<](\d+)', caseSensitive: false)
          .firstMatch(out);
      _pingMs = m != null ? int.tryParse(m.group(1)!) : null;
      _emit();
    } catch (_) {
      _pingMs = null;
    }
  }

  // ==================== КОНФИГ ====================

  Future<String> _writeConfig(Map<String, dynamic> config) async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'sing-box'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final configPath = p.join(dir.path, 'config.json');
    await File(configPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
    return configPath;
  }

  String? _findSingBoxExe() {
    // 1. Рядом с .exe приложения (установщик кладёт туда же)
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final candidate = p.join(exeDir, 'sing-box.exe');
      if (File(candidate).existsSync()) return candidate;
      // 2. Подкаталог sing-box (портативная раскладка)
      final sub = p.join(exeDir, 'sing-box', 'sing-box.exe');
      if (File(sub).existsSync()) return sub;
    } catch (_) {}
    // 3. Текущая директория (разработка: flutter run)
    final local = p.join(Directory.current.path, 'sing-box.exe');
    if (File(local).existsSync()) return local;
    final localSub =
        p.join(Directory.current.path, 'sing-box', 'sing-box.exe');
    if (File(localSub).existsSync()) return localSub;
    return null;
  }

  // ==================== HELPERS ====================

  Future<bool> _isAdministrator() async {
    if (!Platform.isWindows) return true;
    try {
      final result = await Process.run('net', ['session']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _setState(VpnState state, String message) {
    _state = state;
    _message = message;
    if (state != VpnState.connected) _log('STATE: $state — $message');
    _emit();
  }

  void _emit() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }

  void _log(String msg) {
    final line =
        '${DateTime.now().toIso8601String().substring(11, 19)} $msg';
    _logLines.add(line);
    if (_logLines.length > _maxLogLines) {
      _logLines.removeRange(0, _logLines.length - _maxLogLines);
    }
    debugPrint('[VPN] $msg');
  }

  String _maskLink(String link) {
    if (link.length < 24) return link;
    return '${link.substring(0, 12)}...${link.substring(link.length - 8)}';
  }

  void dispose() {
    _stopStats();
    _statusController.close();
  }
}
