import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/support/presentation/support_screen.dart';

/// Проверка и загрузка обновления Windows с GitHub Releases.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const _repo = 'pomah7878-bot/ECLIPSE_VPN_Windows';

  Future<UpdateInfo?> check() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'ECLIPSE-VPN-Windows',
      },
    ));
    final response = await dio.get('https://api.github.com/repos/$_repo/releases/latest');
    if (response.statusCode != 200 || response.data is! Map) return null;
    final data = Map<String, dynamic>.from(response.data as Map);
    final tag = data['tag_name']?.toString() ?? '';
    final version = tag.replaceFirst(RegExp(r'^v'), '');
    if (version.isEmpty || !_isNewer(version, SupportScreen.appVersion)) return null;

    final assets = data['assets'];
    if (assets is! List) return null;
    Map<String, dynamic>? installer;
    for (final raw in assets) {
      if (raw is! Map) continue;
      final asset = Map<String, dynamic>.from(raw);
      final name = asset['name']?.toString() ?? '';
      if (name.toLowerCase().endsWith('.exe')) {
        installer = asset;
        break;
      }
    }
    if (installer == null) return null;
    final url = installer['browser_download_url']?.toString();
    if (url == null || url.isEmpty) return null;
    final digest = installer['digest']?.toString() ?? '';
    final sha = digest.startsWith('sha256:') ? digest.substring(7) : '';
    return UpdateInfo(
      version: version,
      url: url,
      sha256: sha,
      size: int.tryParse('${installer['size']}') ?? 0,
    );
  }

  Future<String> download(UpdateInfo info, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'ECLIPSE_VPN_Setup_${info.version}.exe');
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
    ));
    await dio.download(
      info.url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress(received / total);
      },
      deleteOnError: true,
    );
    if (info.sha256.isNotEmpty) {
      final file = File(path);
      final actual = (sha256.convert(await file.readAsBytes())).toString();
      if (actual != info.sha256.toLowerCase()) {
        await file.delete();
        throw const UpdateException('Контрольная сумма обновления не совпала');
      }
    }
    return path;
  }

  Future<void> runInstaller(String path) async {
    await Process.start(
      path,
      const ['/SILENT', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );
  }

  static bool _isNewer(String candidate, String current) {
    final a = candidate.split('.').map(int.tryParse).toList();
    final b = current.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? (a[i] ?? 0) : 0;
      final y = i < b.length ? (b[i] ?? 0) : 0;
      if (x > y) return true;
      if (x < y) return false;
    }
    return false;
  }
}

class UpdateInfo {
  final String version;
  final String url;
  final String sha256;
  final int size;

  UpdateInfo({
    required this.version,
    required this.url,
    required this.sha256,
    required this.size,
  });

  String get sizeText => size > 0 ? '${(size / 1048576).toStringAsFixed(1)} МБ' : '';
}

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}
