import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/keys_api.dart';
import '../services/singbox_service.dart';
import '../services/config_generator.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final _singbox = SingboxService();
  final _keysApi = KeysApi();
  
  List<VpnKey> _keys = [];
  VpnKey? _selectedKey;
  List<KeyInbound> _inbounds = [];
  KeyInbound? _selectedInbound;
  
  bool _isLoadingKeys = true;
  String? _error;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadKeys();
    _singbox.addListener(_onStatusChanged);
  }

  void _onStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadKeys() async {
    setState(() {
      _isLoadingKeys = true;
      _error = null;
    });

    try {
      final keys = await _keysApi.getKeys();
      setState(() {
        _keys = keys.where((k) => k.isActive).toList();
        _isLoadingKeys = false;
        if (_keys.isNotEmpty && _selectedKey == null) {
          _selectedKey = _keys.first;
          _loadInbounds(_selectedKey!.id);
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки ключей';
        _isLoadingKeys = false;
      });
    }
  }

  Future<void> _loadInbounds(int keyId) async {
    try {
      final inbounds = await _keysApi.getKeyInbounds(keyId);
      setState(() {
        _inbounds = inbounds;
        if (inbounds.isNotEmpty) {
          _selectedInbound = inbounds.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading inbounds: $e');
    }
  }

  Future<void> _toggleConnection() async {
    if (_singbox.isConnected || _singbox.isConnecting) {
      await _singbox.disconnect();
      return;
    }

    if (_selectedInbound == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ключ для подключения')),
      );
      return;
    }

    // Генерируем конфиг
    final config = ConfigGenerator.fromKeyInbound(_selectedInbound!);
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать конфигурацию')),
      );
      return;
    }

    await _singbox.connect(config);
  }

  @override
  Widget build(BuildContext context) {
    final status = _singbox.status;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECLIPSE VPN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Настройки
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Выбор ключа
            if (!_isLoadingKeys && _keys.isNotEmpty)
              _buildKeySelector(),
            
            const Spacer(),
            
            // Кнопка подключения
            GestureDetector(
              onTap: _toggleConnection,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final color = _getStatusColor(status);
                  
                  return Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.1),
                      border: Border.all(color: color, width: 3),
                      boxShadow: status == VpnStatus.connected || status == VpnStatus.connecting
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new,
                        size: 70,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Статус
            Text(
              _getStatusText(status),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            
            if (_singbox.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _singbox.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_selectedKey != null)
              Text(
                'Сервер: ${_selectedKey!.serverName ?? "Unknown"}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            
            const Spacer(),
            
            // Статистика
            if (status == VpnStatus.connected) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(
                    icon: Icons.arrow_downward,
                    label: 'Загрузка',
                    value: _formatBytes(_singbox.downloadBytes),
                  ),
                  _StatItem(
                    icon: Icons.arrow_upward,
                    label: 'Отдача',
                    value: _formatBytes(_singbox.uploadBytes),
                  ),
                  _StatItem(
                    icon: Icons.timer,
                    label: 'Время',
                    value: _formatDuration(_singbox.connectedDuration),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VpnKey>(
          value: _selectedKey,
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          hint: const Text('Выберите ключ'),
          items: _keys.map((key) {
            return DropdownMenuItem(
              value: key,
              child: Text(
                '${key.name} • ${key.serverName ?? "Unknown"}',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (key) {
            setState(() {
              _selectedKey = key;
              _selectedInbound = null;
            });
            if (key != null) {
              _loadInbounds(key.id);
            }
          },
        ),
      ),
    );
  }

  Color _getStatusColor(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        return AppTheme.success;
      case VpnStatus.connecting:
        return AppTheme.primary;
      case VpnStatus.disconnecting:
        return AppTheme.primaryVariant;
      case VpnStatus.error:
        return AppTheme.error;
      case VpnStatus.disconnected:
        return AppTheme.primary;
    }
  }

  String _getStatusText(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        return 'Подключено';
      case VpnStatus.connecting:
        return 'Подключение...';
      case VpnStatus.disconnecting:
        return 'Отключение...';
      case VpnStatus.error:
        return 'Ошибка';
      case VpnStatus.disconnected:
        return 'Отключено';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '$bytes Б';
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _singbox.removeListener(_onStatusChanged);
    _singbox.dispose();
    super.dispose();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
