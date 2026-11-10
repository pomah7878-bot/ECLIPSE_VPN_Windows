import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/api/keys_api.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';

/// Вкладка «Устройства» — как в Android-приложении:
/// счётчик «Использовано: X из Y», карточки устройств ключа
/// (модель, ОС, «был в сети …») с кнопкой «Отключить».
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _keysApi = KeysApi();
  final _authApi = AuthApi();

  bool _loading = true;
  bool _loggedIn = false;
  String? _error;
  KeyDevicesResponse? _devices;

  @override
  void initState() {
    super.initState();
    SessionService.loggedIn.addListener(_onSessionChanged);
    _load();
  }

  void _onSessionChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    SessionService.loggedIn.removeListener(_onSessionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _authApi.getSession();
      if (!mounted) return;
      final loggedIn = session?.loggedIn ?? false;
      final key = loggedIn
          ? session!.keys.where((k) => k.isActive).isEmpty
              ? (session.keys.isEmpty ? null : session.keys.first)
              : session.keys.firstWhere((k) => k.isActive)
          : null;

      if (!loggedIn || key == null) {
        setState(() {
          _loggedIn = loggedIn;
          _devices = null;
          _loading = false;
        });
        return;
      }

      final devices = await _keysApi.getKeyDevices(key.keyId);
      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _devices = devices;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить устройства';
          _loading = false;
        });
      }
    }
  }

  Future<void> _disconnect(DeviceDto device) async {
    final key = await _activeKeyId();
    if (!mounted) return;
    if (key == null || device.deviceId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text('Отключить устройство?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '«${device.title}» потеряет доступ к VPN, слот освободится.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Отмена', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final error = await _keysApi.disconnectDevice(key, device.deviceId!);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
      );
    }
    await _load();
  }

  Future<int?> _activeKeyId() async {
    try {
      final session = await _authApi.getSession();
      if (session == null || !session.loggedIn || session.keys.isEmpty) {
        return null;
      }
      return session.keys
          .firstWhere((k) => k.isActive, orElse: () => session.keys.first)
          .keyId;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Мои устройства')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.goldAccent,
        backgroundColor: AppTheme.cardDark,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _buildContent(),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_loading) {
      return const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(color: AppTheme.goldAccent)),
      ];
    }

    if (!_loggedIn) {
      return const [
        SizedBox(height: 100),
        _Note(text: 'Устройства появятся после покупки подписки'),
      ];
    }

    if (_error != null && _devices == null) {
      return [
        const SizedBox(height: 100),
        _Note(text: _error!),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ),
      ];
    }

    final devices = _devices;
    if (devices == null) {
      return const [
        SizedBox(height: 100),
        _Note(text: 'Устройства появятся после покупки подписки'),
      ];
    }

    final items = <Widget>[
      _Note(text: 'Использовано: ${devices.counterText}'),
      const SizedBox(height: 12),
    ];

    for (final d in devices.devices) {
      items.add(_DeviceCard(device: d, onDisconnect: () => _disconnect(d)));
      items.add(const SizedBox(height: 10));
    }

    if (devices.devices.isEmpty) {
      items.add(
        _Note(
          text: devices.currentCount > 0
              ? 'Подключено устройств: ${devices.currentCount}. '
                  'Подробный список для этого аккаунта пока недоступен.'
              : 'Пока ни одно устройство не подключалось',
        ),
      );
    }

    return items;
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceDto device;
  final VoidCallback onDisconnect;

  const _DeviceCard({required this.device, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            device.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (device.info.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              device.info,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
          if (device.canDisconnect) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onDisconnect,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Отключить',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.goldAccent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
