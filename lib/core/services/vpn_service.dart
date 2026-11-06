import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../api/auth_api.dart';
import '../api/keys_api.dart';

/// Управление VPN через sing-box.exe на Windows.
///
/// Архитектура идентична Android (v2rayNG):
/// - Получаем inbound-конфиг с сервера (vless/vmess)
/// - Строим JSON конфиг для sing-box
/// - Запускаем sing-box.exe (он сам создаёт TUN через wintun.dll)
/// - Мониторим процесс
class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  Process? _process;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _statusMessage = 'Отключено';
  String _currentServer = '';
  String _logs = '';

  final _statusController = StreamController<VpnStatus>.broadcast();
  Stream<VpnStatus> get statusStream => _statusController.stream;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get statusMessage => _statusMessage;
  String get currentServer => _currentServer;
  String get logs => _logs;

  // ==================== ПОДКЛЮЧЕНИЕ ====================

  Future<bool> connect() async {
    if (_isConnecting || _isConnected) return false;

    _isConnecting = true;
    _logs = '';
    _updateStatus(message: 'Проверка ключей...');

    try {
      // 1. Сессия и ключи
      final session = await AuthApi().getSession();
      if (session == null || !session.loggedIn || session.keys.isEmpty) {
        _isConnecting = false;
        _updateStatus(message: 'Войдите в личный кабинет и купите ключ');
        return false;
      }

      final key = session.keys.firstWhere(
        (k) => k.isActive,
        orElse: () => session.keys.first,
      );

      // 2. Inbound-конфиги
      _updateStatus(message: 'Получение сервера...');
      final inbounds = await KeysApi().getKeyInbounds(key.keyId);
      if (inbounds.isEmpty) {
        _isConnecting = false;
        _updateStatus(message: 'Нет доступных серверов');
        return false;
      }

      final inbound = inbounds.first;
      _currentServer = key.serverName ?? inbound.protocol;

      // 3. Конфиг sing-box
      _updateStatus(message: 'Создание конфига...');
      final configPath = await _createConfig(inbound);
      _log('Config: $configPath');

      // 4. sing-box.exe
      final exePath = await _findSingBoxExe();
      if (exePath == null) {
        _isConnecting = false;
        _updateStatus(message: 'sing-box.exe не найден. Переустановите приложение.');
        return false;
      }
      _log('sing-box: $exePath');

      // 5. Проверка wintun.dll
      final wintunPath = p.join(File(exePath).parent.path, 'wintun.dll');
      if (!File(wintunPath).existsSync()) {
        _isConnecting = false;
        _updateStatus(message: 'wintun.dll не найден. Переустановите приложение.');
        _log('ERROR: wintun.dll missing at $wintunPath');
        return false;
      }
      _log('wintun.dll: OK');

      // 6. Запуск
      _updateStatus(message: 'Запуск VPN...');
      final success = await _startSingBox(exePath, configPath);

      if (success) {
        _isConnected = true;
        _isConnecting = false;
        _updateStatus(connected: true, message: 'VPN подключён');
        return true;
      } else {
        _isConnecting = false;
        _updateStatus(message: 'Ошибка запуска VPN. Логи:\n$_logs');
        return false;
      }
    } catch (e, st) {
      _isConnecting = false;
      _log('ERROR: $e\n$st');
      _updateStatus(message: 'Ошибка: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _stopSingBox();
    _isConnected = false;
    _isConnecting = false;
    _currentServer = '';
    _updateStatus(message: 'Отключено');
  }

  // ==================== SING-BOX PROCESS ====================

  Future<bool> _startSingBox(String exePath, String configPath) async {
    await _stopSingBox();

    try {
      _log('Starting sing-box...');

      _process = await Process.start(
        exePath,
        ['run', '-c', configPath, '--disable-color'],
        workingDirectory: File(exePath).parent.path,
      );

      // Читаем stdout/stderr для логов
      _process!.stdout.transform(utf8.decoder).listen((line) {
        _log('[sing-box] $line');
      });
      _process!.stderr.transform(utf8.decoder).listen((line) {
        _log('[sing-box ERR] $line');
      });

      // Ждём 4 секунды на инициализацию TUN
      await Future.delayed(const Duration(seconds: 4));

      // Проверяем, жив ли процесс
      final exitCode = await _process!.exitCode.timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => -999,
      );

      if (exitCode != -999) {
        _log('sing-box exited immediately with code $exitCode');
        return false;
      }

      _log('sing-box is running');
      return true;
    } catch (e) {
      _log('Failed to start sing-box: $e');
      return false;
    }
  }

  Future<void> _stopSingBox() async {
    if (_process != null) {
      _log('Stopping sing-box...');
      _process!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
      _process = null;
    }
    try {
      await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe']);
    } catch (_) {}
  }

  // ==================== CONFIG ====================

  Future<String> _createConfig(KeyInbound inbound) async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'sing-box'));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final configPath = p.join(dir.path, 'config.json');
    final link = inbound.link ?? '';

    Map<String, dynamic> proxy;
    if (link.startsWith('vless://')) {
      proxy = _parseVless(link);
    } else if (link.startsWith('vmess://')) {
      proxy = _parseVmess(link);
    } else if (inbound.config != null && inbound.config!.isNotEmpty) {
      try {
        proxy = jsonDecode(inbound.config!);
      } catch (_) {
        proxy = {'type': 'direct', 'tag': 'proxy'};
      }
    } else {
      proxy = {'type': 'direct', 'tag': 'proxy'};
    }

    final config = {
      'log': {'level': 'info'},
      'dns': {
        'servers': [
          {'tag': 'remote', 'address': 'tcp://8.8.8.8', 'detour': 'proxy'},
          {'tag': 'local', 'address': '223.5.5.5', 'detour': 'direct'},
        ],
        'rules': [
          {'geosite': 'cn', 'server': 'local'},
        ],
        'final': 'remote',
        'strategy': 'ipv4_only',
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'EclipseVPN',
          'inet4_address': '172.19.0.1/30',
          'inet6_address': 'fdfe:dcba:9876::1/126',
          'auto_route': true,
          'strict_route': false,
          'stack': 'gvisor',
          'sniff': true,
        }
      ],
      'outbounds': [
        proxy,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        {'type': 'dns', 'tag': 'dns-out'},
      ],
      'route': {
        'auto_detect_interface': true,
        'final': 'proxy',
        'rules': [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {'geoip': 'private', 'outbound': 'direct'},
          {'geosite': 'cn', 'outbound': 'direct'},
        ],
      },
    };

    await File(configPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );

    return configPath;
  }

  Map<String, dynamic> _parseVless(String url) {
    try {
      final uri = Uri.parse(url);
      final uuid = uri.userInfo;
      final host = uri.host;
      final port = uri.port;
      final params = uri.queryParameters;

      final out = <String, dynamic>{
        'type': 'vless',
        'tag': 'proxy',
        'server': host,
        'server_port': port,
        'uuid': uuid,
      };

      if (params['flow'] != null) out['flow'] = params['flow'];

      final sec = params['security'] ?? '';
      if (sec == 'tls' || sec == 'reality') {
        final tls = <String, dynamic>{
          'enabled': true,
          'server_name': params['sni'] ?? host,
        };
        if (sec == 'reality') {
          tls['reality'] = {
            'enabled': true,
            'public_key': params['pbk'] ?? '',
            'short_id': params['sid'] ?? '',
          };
          if (params['fp'] != null) {
            tls['utls'] = {'enabled': true, 'fingerprint': params['fp']};
          }
        }
        out['tls'] = tls;
      }

      final tType = params['type'] ?? 'tcp';
      if (tType != 'tcp') {
        final tr = <String, dynamic>{'type': tType};
        if (params['host'] != null) tr['host'] = [params['host']];
        if (params['path'] != null) tr['path'] = params['path'];
        out['transport'] = tr;
      }

      return out;
    } catch (e) {
      _log('VLESS parse error: $e');
      return {'type': 'direct', 'tag': 'proxy'};
    }
  }

  Map<String, dynamic> _parseVmess(String url) {
    try {
      final b64 = url.substring(8);
      final str = utf8.decode(base64Url.decode(base64Url.normalize(b64)));
      final v = jsonDecode(str);

      final out = <String, dynamic>{
        'type': 'vmess',
        'tag': 'proxy',
        'server': v['add'],
        'server_port': int.parse(v['port'].toString()),
        'uuid': v['id'],
        'security': v['scy'] ?? 'auto',
        'alter_id': v['aid'] ?? 0,
      };

      if (v['tls'] == 'tls') {
        out['tls'] = {
          'enabled': true,
          'server_name': v['sni'] ?? v['host'],
        };
      }

      final net = v['net'] ?? 'tcp';
      if (net != 'tcp') {
        final tr = <String, dynamic>{'type': net};
        if (v['host'] != null) tr['host'] = v['host'];
        if (v['path'] != null) tr['path'] = v['path'];
        out['transport'] = tr;
      }

      return out;
    } catch (e) {
      _log('VMESS parse error: $e');
      return {'type': 'direct', 'tag': 'proxy'};
    }
  }

  // ==================== HELPERS ====================

  Future<String?> _findSingBoxExe() async {
    // 1. Рядом с .exe приложения (Inno Setup)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final path = p.join(exeDir.path, 'sing-box.exe');
      if (File(path).existsSync()) return path;
    } catch (_) {}

    // 2. В PATH
    try {
      final r = await Process.run('where', ['sing-box.exe']);
      if (r.exitCode == 0) return r.stdout.toString().trim().split('\n').first.trim();
    } catch (_) {}

    // 3. Текущая директория
    final local = p.join(Directory.current.path, 'sing-box.exe');
    if (File(local).existsSync()) return local;

    return null;
  }

  void _log(String msg) {
    final line = '${DateTime.now().toIso8601String()} $msg';
    _logs += '$line\n';
    // ignore: avoid_print
    print(line);
  }

  void _updateStatus({bool connected = false, required String message}) {
    _statusMessage = message;
    _statusController.add(VpnStatus(
      isConnected: connected,
      isConnecting: _isConnecting,
      message: message,
      server: _currentServer,
      logs: _logs,
    ));
  }

  void dispose() {
    _statusController.close();
  }
}

class VpnStatus {
  final bool isConnected;
  final bool isConnecting;
  final String message;
  final String server;
  final String logs;

  VpnStatus({
    required this.isConnected,
    required this.isConnecting,
    required this.message,
    required this.server,
    this.logs = '',
  });
}