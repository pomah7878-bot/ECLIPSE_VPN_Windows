import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../api/auth_api.dart';
import '../api/keys_api.dart';

/// Сервис управления VPN-подключением через sing-box.
///
/// Архитектура: Flutter UI ↔ sing-box.exe (TUN через wintun.dll)
/// - Загружает конфигурацию с сервера (sub_url или inbound)
/// - Создаёт config.json для sing-box
/// - Запускает/останавливает sing-box.exe
/// - Мониторит статус подключения
class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  Process? _singBoxProcess;
  bool _isConnected = false;
  String _statusMessage = 'Отключено';
  String _currentServer = '';

  final _statusController = StreamController<VpnStatus>.broadcast();
  Stream<VpnStatus> get statusStream => _statusController.stream;

  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;
  String get currentServer => _currentServer;

  // ==================== ПОДКЛЮЧЕНИЕ ====================

  /// Подключает VPN: получает конфиг с сервера, создаёт config.json, запускает sing-box.
  Future<bool> connect() async {
    try {
      _updateStatus(connecting: true, message: 'Получение конфигурации...');

      // 1. Проверяем сессию
      final authApi = AuthApi();
      final session = await authApi.getSession();
      if (session == null || !session.loggedIn || session.keys.isEmpty) {
        _updateStatus(connecting: false, message: 'Нет активных ключей');
        return false;
      }

      // 2. Берём первый активный ключ
      final key = session.keys.firstWhere(
        (k) => k.isActive,
        orElse: () => session.keys.first,
      );

      // 3. Получаем inbound-конфиги ключа
      final keysApi = KeysApi();
      final inbounds = await keysApi.getKeyInbounds(key.keyId);
      if (inbounds.isEmpty) {
        _updateStatus(connecting: false, message: 'Нет доступных серверов');
        return false;
      }

      final inbound = inbounds.first;
      _currentServer = key.serverName ?? inbound.protocol;

      // 4. Создаём config.json для sing-box
      _updateStatus(connecting: true, message: 'Создание конфига...');
      final configPath = await _createSingBoxConfig(inbound);

      // 5. Запускаем sing-box
      _updateStatus(connecting: true, message: 'Запуск sing-box...');
      final success = await _startSingBox(configPath);

      if (success) {
        _isConnected = true;
        _updateStatus(connected: true, message: 'VPN подключён');
        return true;
      } else {
        _updateStatus(connecting: false, message: 'Ошибка запуска sing-box');
        return false;
      }
    } catch (e) {
      _updateStatus(connecting: false, message: 'Ошибка: $e');
      return false;
    }
  }

  /// Отключает VPN: останавливает sing-box.
  Future<void> disconnect() async {
    await _stopSingBox();
    _isConnected = false;
    _currentServer = '';
    _updateStatus(connected: false, message: 'Отключено');
  }

  // ==================== SING-BOX PROCESS ====================

  Future<bool> _startSingBox(String configPath) async {
    await _stopSingBox();

    // Путь к sing-box.exe (рядом с .exe приложения или в PATH)
    final exePath = await _findSingBoxExe();
    if (exePath == null || !File(exePath).existsSync()) {
      throw Exception('sing-box.exe не найден');
    }

    try {
      _singBoxProcess = await Process.start(
        exePath,
        ['run', '-c', configPath],
        mode: ProcessStartMode.detachedWithStdio,
      );

      // Даём 2 секунды на инициализацию TUN
      await Future.delayed(const Duration(seconds: 2));

      // Проверяем, не упал ли процесс
      if (_singBoxProcess != null) {
        // Попытка получить exitCode — если null, процесс жив
        final exitCode = await _singBoxProcess!.exitCode.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => -999, // ещё работает
        );
        if (exitCode != -999) {
          throw Exception('sing-box завершился с кодом $exitCode');
        }
      }

      return true;
    } catch (e) {
      await _stopSingBox();
      rethrow;
    }
  }

  Future<void> _stopSingBox() async {
    if (_singBoxProcess != null) {
      _singBoxProcess!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
      _singBoxProcess = null;
    }

    // На всякий случай убиваем все процессы sing-box.exe
    try {
      await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe']);
    } catch (_) {}
  }

  // ==================== CONFIG ====================

  /// Создаёт config.json для sing-box из inbound-конфигурации.
  ///
  /// Поддерживает:
  /// - vless:// ссылки
  /// - vmess:// ссылки
  /// - Готовый JSON config (если сервер отдаёт sing-box формат)
  Future<String> _createSingBoxConfig(KeyInbound inbound) async {
    final appDir = await getApplicationSupportDirectory();
    final configDir = Directory(p.join(appDir.path, 'sing-box'));
    if (!configDir.existsSync()) configDir.createSync(recursive: true);

    final configPath = p.join(configDir.path, 'config.json');
    final link = inbound.link ?? '';

    Map<String, dynamic> singBoxConfig;

    if (link.startsWith('vless://')) {
      singBoxConfig = _buildConfigFromVless(link);
    } else if (link.startsWith('vmess://')) {
      singBoxConfig = _buildConfigFromVmess(link);
    } else if (inbound.config != null && inbound.config!.isNotEmpty) {
      // Если сервер отдаёт готовый JSON
      try {
        singBoxConfig = jsonDecode(inbound.config!);
      } catch (_) {
        singBoxConfig = _buildFallbackConfig(link);
      }
    } else {
      singBoxConfig = _buildFallbackConfig(link);
    }

    // Добавляем TUN inbound если нет
    if (!singBoxConfig.containsKey('inbounds')) {
      singBoxConfig['inbounds'] = [_tunInbound()];
    }

    // Добавляем route если нет
    if (!singBoxConfig.containsKey('route')) {
      singBoxConfig['route'] = _defaultRoute();
    }

    // Добавляем log
    singBoxConfig['log'] = {'level': 'warn'};

    final configFile = File(configPath);
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(singBoxConfig),
    );

    return configPath;
  }

  /// Парсит vless:// URL и строит sing-box конфиг.
  Map<String, dynamic> _buildConfigFromVless(String url) {
    // vless://uuid@host:port?type=tcp&security=reality&sni=...&pbk=...&fp=...#name
    try {
      final uri = Uri.parse(url);
      final uuid = uri.userInfo;
      final host = uri.host;
      final port = uri.port;
      final params = uri.queryParameters;

      return {
        'outbounds': [
          {
            'type': 'vless',
            'tag': 'proxy',
            'server': host,
            'server_port': port,
            'uuid': uuid,
            'flow': params['flow'] ?? 'xtls-rprx-vision',
            'tls': _buildTls(params),
            'transport': _buildTransport(params),
          },
          {'type': 'direct', 'tag': 'direct'},
          {'type': 'block', 'tag': 'block'},
        ],
      };
    } catch (_) {
      return _buildFallbackConfig(url);
    }
  }

  /// Парсит vmess:// URL (base64) и строит sing-box конфиг.
  Map<String, dynamic> _buildConfigFromVmess(String url) {
    try {
      final b64 = url.substring(8); // убираем vmess://
      final jsonStr = utf8.decode(base64Url.decode(base64Url.normalize(b64)));
      final vmess = jsonDecode(jsonStr);

      return {
        'outbounds': [
          {
            'type': 'vmess',
            'tag': 'proxy',
            'server': vmess['add'],
            'server_port': int.parse(vmess['port'].toString()),
            'uuid': vmess['id'],
            'security': vmess['scy'] ?? 'auto',
            'alter_id': vmess['aid'] ?? 0,
            'tls': (vmess['tls'] == 'tls')
                ? {'enabled': true, 'server_name': vmess['sni'] ?? vmess['host']}
                : null,
            'transport': _buildTransport({
              'type': vmess['net'] ?? 'tcp',
              'host': vmess['host'],
              'path': vmess['path'],
            }),
          },
          {'type': 'direct', 'tag': 'direct'},
          {'type': 'block', 'tag': 'block'},
        ],
      };
    } catch (_) {
      return _buildFallbackConfig(url);
    }
  }

  Map<String, dynamic> _buildFallbackConfig(String link) {
    return {
      'outbounds': [
        {
          'type': 'direct',
          'tag': 'proxy',
        },
      ],
    };
  }

  Map<String, dynamic> _buildTls(Map<String, String> params) {
    final security = params['security'] ?? '';
    if (security == 'reality' || security == 'tls') {
      final tls = <String, dynamic>{
        'enabled': true,
        'server_name': params['sni'] ?? params['host'] ?? '',
      };
      if (security == 'reality') {
        tls['reality'] = {
          'enabled': true,
          'public_key': params['pbk'] ?? '',
          'short_id': params['sid'] ?? '',
        };
        if (params['fp'] != null) {
          tls['utls'] = {'enabled': true, 'fingerprint': params['fp']};
        }
      }
      return tls;
    }
    return null;
  }

  Map<String, dynamic>? _buildTransport(Map<String, String?> params) {
    final transportType = params['type'] ?? 'tcp';
    if (transportType == 'tcp') return null;

    final transport = <String, dynamic>{'type': transportType};
    if (params['host'] != null) transport['host'] = params['host'];
    if (params['path'] != null) transport['path'] = params['path'];
    return transport;
  }

  Map<String, dynamic> _tunInbound() {
    return {
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': 'EclipseVPN',
      'inet4_address': '172.19.0.1/30',
      'auto_route': true,
      'strict_route': false,
      'sniff': true,
    };
  }

  Map<String, dynamic> _defaultRoute() {
    return {
      'auto_detect_interface': true,
      'final': 'proxy',
      'rules': [
        {'protocol': 'dns', 'outbound': 'dns-out'},
      ],
    };
  }

  // ==================== HELPERS ====================

  Future<String?> _findSingBoxExe() async {
    // 1. Рядом с .exe приложения
    try {
      final appDir = await getApplicationSupportDirectory();
      final nearExe = p.join(appDir.parent.path, 'sing-box.exe');
      if (File(nearExe).existsSync()) return nearExe;
    } catch (_) {}

    // 2. В PATH
    try {
      final result = await Process.run('where', ['sing-box.exe']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim().split('\n').first.trim();
      }
    } catch (_) {}

    // 3. Рядом с Flutter .exe (Release)
    try {
      final appDir = await getApplicationSupportDirectory();
      final releasePath = p.join(
        appDir.parent.parent.path,
        'sing-box.exe',
      );
      if (File(releasePath).existsSync()) return releasePath;
    } catch (_) {}

    return null;
  }

  void _updateStatus({
    bool connecting = false,
    bool connected = false,
    required String message,
  }) {
    _statusMessage = message;
    _statusController.add(VpnStatus(
      isConnected: connected,
      isConnecting: connecting,
      message: message,
      server: _currentServer,
    ));
  }

  void dispose() {
    _statusController.close();
  }
}

// ==================== STATUS ====================

class VpnStatus {
  final bool isConnected;
  final bool isConnecting;
  final String message;
  final String server;

  VpnStatus({
    required this.isConnected,
    required this.isConnecting,
    required this.message,
    required this.server,
  });
}