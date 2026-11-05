import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class SingboxService extends ChangeNotifier {
  Process? _process;
  VpnStatus _status = VpnStatus.disconnected;
  String? _currentConfigPath;
  String? _errorMessage;
  
  // Статистика
  int _downloadBytes = 0;
  int _uploadBytes = 0;
  Duration _connectedDuration = Duration.zero;
  Timer? _statsTimer;
  DateTime? _connectedAt;

  VpnStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isConnecting => _status == VpnStatus.connecting;
  
  int get downloadBytes => _downloadBytes;
  int get uploadBytes => _uploadBytes;
  Duration get connectedDuration => _connectedDuration;

  /// Путь к sing-box исполняемому файлу
  Future<String> _getSingboxPath() async {
    // В production: sing-box.exe рядом с приложением
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final singboxExe = p.join(exeDir, 'sing-box.exe');
    
    if (await File(singboxExe).exists()) {
      return singboxExe;
    }
    
    // Fallback: в папке приложения
    final appDir = await getApplicationSupportDirectory();
    final fallbackPath = p.join(appDir.path, 'sing-box', 'sing-box.exe');
    
    if (await File(fallbackPath).exists()) {
      return fallbackPath;
    }
    
    throw Exception('sing-box.exe не найден. Переустановите приложение.');
  }

  /// Подключение с конфигурацией
  Future<void> connect(Map<String, dynamic> config) async {
    if (_status == VpnStatus.connected || _status == VpnStatus.connecting) {
      await disconnect();
    }

    _setStatus(VpnStatus.connecting);
    _errorMessage = null;

    try {
      // Сохраняем конфиг во временный файл
      final tempDir = await getTemporaryDirectory();
      final configFile = File(p.join(tempDir.path, 'eclipse_vpn_config.json'));
      await configFile.writeAsString(jsonEncode(config));
      _currentConfigPath = configFile.path;

      // Запускаем sing-box
      final singboxPath = await _getSingboxPath();
      
      _process = await Process.start(
        singboxPath,
        [
          'run',
          '-c', _currentConfigPath!,
          '--disable-color',
        ],
        mode: ProcessStartMode.normal,
      );

      // Слушаем stdout/stderr
      _process!.stdout.transform(utf8.decoder).listen(_onOutput);
      _process!.stderr.transform(utf8.decoder).listen(_onError);

      // Ждём запуска (sing-box пишет "started" в лог)
      await Future.delayed(const Duration(seconds: 2));
      
      // Проверяем, что процесс жив
      if (_process != null && _process!.kill(ProcessSignal.sigusr1)) {
        _setStatus(VpnStatus.connected);
        _connectedAt = DateTime.now();
        _startStatsTimer();
      } else {
        throw Exception('sing-box не запустился');
      }

    } catch (e) {
      _setStatus(VpnStatus.error);
      _errorMessage = e.toString();
      await _cleanup();
    }
  }

  /// Отключение
  Future<void> disconnect() async {
    if (_status == VpnStatus.disconnected) return;

    _setStatus(VpnStatus.disconnecting);
    _stopStatsTimer();

    try {
      // Graceful shutdown через SIGTERM
      _process?.kill(ProcessSignal.sigterm);
      
      // Ждём завершения с таймаутом
      await _process?.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          // Force kill
          _process?.kill(ProcessSignal.sigkill);
          return 0;
        },
      );
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    } finally {
      await _cleanup();
      _setStatus(VpnStatus.disconnected);
    }
  }

  void _onOutput(String data) {
    debugPrint('[sing-box] $data');
    
    // Парсим статистику из лога
    if (data.contains('download') || data.contains('upload')) {
      _parseStats(data);
    }
  }

  void _onError(String data) {
    debugPrint('[sing-box ERROR] $data');
    
    if (data.contains('error') || data.contains('failed')) {
      _errorMessage = data.trim();
    }
  }

  void _parseStats(String data) {
    // Парсим строки вида: "download: 1234567 upload: 890123"
    final downloadMatch = RegExp(r'download:\s*(\d+)').firstMatch(data);
    final uploadMatch = RegExp(r'upload:\s*(\d+)').firstMatch(data);
    
    if (downloadMatch != null) {
      _downloadBytes = int.tryParse(downloadMatch.group(1)!) ?? 0;
    }
    if (uploadMatch != null) {
      _uploadBytes = int.tryParse(uploadMatch.group(1)!) ?? 0;
    }
    notifyListeners();
  }

  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connectedAt != null) {
        _connectedDuration = DateTime.now().difference(_connectedAt!);
        notifyListeners();
      }
    });
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _connectedDuration = Duration.zero;
    _connectedAt = null;
  }

  Future<void> _cleanup() async {
    _process = null;
    
    // Удаляем временный конфиг
    if (_currentConfigPath != null) {
      try {
        await File(_currentConfigPath!).delete();
      } catch (_) {}
      _currentConfigPath = null;
    }
    
    _downloadBytes = 0;
    _uploadBytes = 0;
  }

  void _setStatus(VpnStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopStatsTimer();
    disconnect();
    super.dispose();
  }
}
