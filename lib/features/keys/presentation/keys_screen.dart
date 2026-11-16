import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/account_api.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/api/keys_api.dart';
import '../../../core/api/shop_api.dart';
import '../../../core/theme/app_theme.dart';

/// Мои ключи: список и карточка ключа — как в Android.
class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key});

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen> {
  final _auth = AuthApi();
  List<AccountKeyDto> _keys = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _auth.getSession();
      if (!mounted) return;
      if (session == null || !session.loggedIn) {
        setState(() {
          _error = 'Нужно войти в аккаунт';
          _loading = false;
        });
        return;
      }
      setState(() {
        _keys = session.keys;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить ключи';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Мои ключи')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.goldAccent,
                  child: _keys.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 160),
                            Center(child: Text('Ключей пока нет', style: TextStyle(color: AppTheme.textMuted))),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _keys.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _keyCard(_keys[i]),
                        ),
                ),
    );
  }

  Widget _keyCard(AccountKeyDto key) {
    final limit = key.trafficLimitGb;
    final traffic = limit == null
        ? '${key.trafficUsedGb.toStringAsFixed(2)} ГБ'
        : '${key.trafficUsedGb.toStringAsFixed(2)} / ${limit.toStringAsFixed(0)} ГБ';
    final days = key.daysLeft;
    final expiry = days == null ? 'бессрочно' : (days < 0 ? 'истёк' : 'осталось $days дн.');
    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => KeyDetailScreen(accountKey: key)));
        _load();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: key.isActive ? AppTheme.goldAccent : AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key, color: key.isActive ? AppTheme.goldAccent : AppTheme.textMuted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(key.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text(key.isActive ? 'активен' : 'неактивен',
                    style: TextStyle(fontSize: 11, color: key.isActive ? AppTheme.successGreen : AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            if (key.serverName != null)
              Text(key.serverName!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Text('Трафик: $traffic', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Text('Срок: $expiry', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Карточка ключа: QR, ссылка подписки, устройства, переименование,
/// удаление и продление.
class KeyDetailScreen extends StatefulWidget {
  final AccountKeyDto accountKey;
  const KeyDetailScreen({super.key, required this.accountKey});

  @override
  State<KeyDetailScreen> createState() => _KeyDetailScreenState();
}

class _KeyDetailScreenState extends State<KeyDetailScreen> {
  final _account = AccountApi();
  final _keys = KeysApi();
  final _shop = ShopApi();
  KeyDevicesResponse? _devices;
  bool _loadingDevices = true;
  bool _renewing = false;
  bool _buyingCdn = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _keys.getKeyDevices(widget.accountKey.keyId);
      if (mounted) {
        setState(() {
          _devices = devices;
          _loadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: widget.accountKey.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Название ключа'),
        content: TextField(controller: controller, maxLength: 30),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final error = await _account.renameKey(widget.accountKey.keyId, name);
    if (!mounted) return;
    setState(() => _message = error ?? 'Название обновлено');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Удалить ключ?'),
        content: const Text('Удалить можно только неактивный ключ. Действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    final error = await _account.deleteKey(widget.accountKey.keyId);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _message = error);
  }

  Future<void> _renew() async {
    setState(() {
      _renewing = true;
      _message = 'Создаём платёж…';
    });
    try {
      final order = await _shop.createKeyRenewal(widget.accountKey.keyId);
      final url = order.qrUrl;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      setState(() => _message = 'Оплатите в браузере. Проверяем статус…');
      for (var i = 0; i < 20; i++) {
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        if (order.orderId == null) break;
        final check = await _shop.checkKeyRenewal(order.orderId!);
        if (check.status == 'paid') {
          setState(() {
            _message = 'Ключ продлён';
            _renewing = false;
          });
          return;
        }
      }
      if (mounted) setState(() => _message = 'Оплата ещё не подтверждена');
    } catch (e) {
      if (mounted) setState(() => _message = 'Не удалось создать продление');
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  Future<void> _buyCdn() async {
    setState(() {
      _buyingCdn = true;
      _message = 'Покупаем CDN-пакет…';
    });
    final error = await _account.buyCdn(widget.accountKey.keyId);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _buyingCdn = false;
      _message = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.accountKey;
    final subUrl = key.subUrl;
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: Text(key.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (key.serverName != null)
                Text(key.serverName!, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text('Трафик: ${key.trafficUsedGb.toStringAsFixed(2)}'
                  '${key.trafficLimitGb == null ? ' ГБ' : ' / ${key.trafficLimitGb!.toStringAsFixed(0)} ГБ'}'),
              Text('Срок: ${key.daysLeft == null ? 'бессрочно' : (key.daysLeft! < 0 ? 'истёк' : 'осталось ${key.daysLeft} дн.')}'),
            ],
          )),
          const SizedBox(height: 14),
          if (subUrl != null && subUrl.isNotEmpty)
            _card(Column(
              children: [
                const Text('QR для подключения', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: QrImageView(data: subUrl, size: 190),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: subUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ссылка подписки скопирована')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Скопировать ссылку'),
                ),
              ],
            )),
          const SizedBox(height: 14),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Устройства', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_loadingDevices)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
              else if (_devices == null || _devices!.devices.isEmpty)
                const Text('Устройства появятся после подключения', style: TextStyle(color: AppTheme.textMuted))
              else
                ..._devices!.devices.map((d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.devices, color: AppTheme.goldAccent),
                      title: Text(d.title),
                      subtitle: Text(d.info, style: const TextStyle(fontSize: 11)),
                      trailing: d.canDisconnect
                          ? IconButton(
                              icon: const Icon(Icons.link_off, color: AppTheme.errorRed),
                              onPressed: () async {
                                final err = await _keys.disconnectDevice(key.keyId, d.deviceId);
                                if (!mounted) return;
                                if (err == null) {
                                  _loadDevices();
                                } else {
                                  setState(() => _message = err);
                                }
                              },
                            )
                          : null,
                    )),
            ],
          )),
          const SizedBox(height: 14),
          if (key.cdn != null && (key.cdn!.hasPack || key.cdn!.canBuy))
            _card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CDN-пакет', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (key.cdn!.hasPack) ...[
                  Text(
                    'Статус: ${key.cdn!.packStatus}'
                    '${key.cdn!.expiresAt != null ? ' · до ${key.cdn!.expiresAt}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (key.cdn!.limitBytes > 0)
                    Text(
                      'Трафик: ${(key.cdn!.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}'
                      ' / ${(key.cdn!.limitBytes / (1024 * 1024 * 1024)).toStringAsFixed(0)} ГБ',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  const SizedBox(height: 8),
                ],
                if (key.cdn!.canBuy) ...[
                  Text(
                    '${key.cdn!.gb} ГБ на ${key.cdn!.days} дн. · ${key.cdn!.priceRub} ₽',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _buyingCdn ? null : _buyCdn,
                    child: Text(_buyingCdn ? 'Покупаем…' : 'Купить CDN за ${key.cdn!.priceRub} ₽'),
                  ),
                ],
              ],
            )),
          const SizedBox(height: 14),
          _card(Column(
            children: [
              ElevatedButton(
                onPressed: _renewing ? null : _renew,
                child: Text(_renewing ? 'Ожидаем оплату…' : 'Продлить'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _rename, child: const Text('Переименовать')),
              const SizedBox(height: 10),
              if (!key.isActive)
                OutlinedButton(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                  ),
                  child: const Text('Удалить ключ'),
                ),
            ],
          )),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: child,
      );
}
