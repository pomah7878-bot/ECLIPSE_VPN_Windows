import 'package:shared_preferences/shared_preferences.dart';

enum SplitTunnelMode {
  off,
  exclude;

  String get title => switch (this) {
        SplitTunnelMode.off => 'Выключен',
        SplitTunnelMode.exclude => 'Выбранные приложения мимо VPN',
      };
}

/// Раздельный туннель для Windows: список процессов, которые ходят напрямую.
class SplitTunnelService {
  static final SplitTunnelService _instance = SplitTunnelService._internal();
  factory SplitTunnelService() => _instance;
  SplitTunnelService._internal();

  static const _modeKey = 'split_tunnel_mode';
  static const _listKey = 'split_tunnel_processes';

  SharedPreferences? _prefs;
  SplitTunnelMode _mode = SplitTunnelMode.off;
  List<String> _processes = [];

  SplitTunnelMode get mode => _mode;
  List<String> get processes => List.unmodifiable(_processes);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_modeKey);
    _mode = SplitTunnelMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => SplitTunnelMode.off,
    );
    _processes = _prefs?.getStringList(_listKey) ?? [];
  }

  Future<void> setMode(SplitTunnelMode value) async {
    _mode = value;
    await _prefs?.setString(_modeKey, value.name);
  }

  Future<void> add(String process) async {
    final name = process.trim();
    if (name.isEmpty) return;
    final exists = _processes.any(
      (p) => p.toLowerCase() == name.toLowerCase(),
    );
    if (!exists) {
      _processes.add(name);
      await _prefs?.setStringList(_listKey, _processes);
    }
  }

  Future<void> remove(String process) async {
    _processes.remove(process);
    await _prefs?.setStringList(_listKey, _processes);
  }
}
