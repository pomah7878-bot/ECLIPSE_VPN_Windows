import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/keys_api.dart';

class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key});

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen> {
  final _keysApi = KeysApi();
  List<VpnKey> _keys = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final keys = await _keysApi.getKeys();
      setState(() {
        _keys = keys;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки ключей';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои ключи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadKeys,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadKeys,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_keys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.key_off_outlined,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет ключей',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Купите подписку в боте',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKeys,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _keys.length,
        itemBuilder: (context, i) {
          return _KeyCard(
            vpnKey: _keys[i],
            onImport: () => _importKey(_keys[i]),
          );
        },
      ),
    );
  }

  void _importKey(VpnKey key) {
    // TODO: Импорт ключа в sing-box
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Импорт ключа "${key.name}"...')),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final VpnKey vpnKey;
  final VoidCallback onImport;

  const _KeyCard({
    required this.vpnKey,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = vpnKey.daysLeft;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vpnKey.isActive ? AppTheme.success : AppTheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vpnKey.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (vpnKey.protocol != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vpnKey.protocol!,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (vpnKey.serverName != null) ...[
              Row(
                children: [
                  const Icon(Icons.public, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(vpnKey.serverName!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            if (daysLeft != null) ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    daysLeft > 0
                        ? 'Осталось $daysLeft дн.'
                        : 'Истёк',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: daysLeft > 7
                          ? AppTheme.textSecondary
                          : daysLeft > 0
                              ? AppTheme.primary
                              : AppTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            if (vpnKey.trafficUsedMb != null && vpnKey.trafficLimitMb != null) ...[
              Row(
                children: [
                  const Icon(Icons.data_usage, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatTraffic(vpnKey.trafficUsedMb!)} / ${_formatTraffic(vpnKey.trafficLimitMb!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Прогресс-бар трафика
              LinearProgressIndicator(
                value: vpnKey.trafficUsedMb! / vpnKey.trafficLimitMb!,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Показать QR
                    },
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text('QR'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Скопировать ссылку
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Копия'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onImport,
                    child: const Text('Импорт'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTraffic(int mb) {
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} ГБ';
    }
    return '$mb МБ';
  }
}
