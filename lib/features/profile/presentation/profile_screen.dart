import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/account_api.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../keys/presentation/keys_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../support/presentation/support_screen.dart';

/// Профиль клиента — как в Android: аккаунт, баланс, ключи, реферал,
/// промокод, история платежей, настройки и выход.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthApi();
  final _account = AccountApi();
  final _promoController = TextEditingController();

  AccountSessionResponse? _session;
  ReferralInfo? _referral;
  HistoryInfo? _history;
  bool _loading = true;
  String? _error;
  String? _promoMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _auth.getSession();
      if (session == null || !session.loggedIn) {
        SessionService.setLoggedIn(false);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      ReferralInfo? referral;
      HistoryInfo? history;
      try {
        referral = await _account.getReferral();
      } catch (_) {}
      try {
        history = await _account.getHistory();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _session = session;
        _referral = referral;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить профиль';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Выйти из аккаунта?'),
        content: const Text('VPN будет отключён. Войти снова можно в любой момент.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _auth.logout();
    } catch (_) {}
    SessionService.setLoggedIn(false);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    final error = await _account.applyPromo(code);
    if (!mounted) return;
    setState(() => _promoMessage = error ?? 'Промокод применён');
  }

  void _copy(String label, String? value) {
    if (value == null || value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label скопирован')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Профиль')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.goldAccent,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _accountCard(),
                      const SizedBox(height: 14),
                      _menuCard(),
                      const SizedBox(height: 14),
                      _referralCard(),
                      const SizedBox(height: 14),
                      _promoCard(),
                      const SizedBox(height: 14),
                      _historyCard(),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorRed,
                          side: const BorderSide(color: AppTheme.errorRed),
                        ),
                        child: const Text('Выйти'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _accountCard() {
    final session = _session!;
    final name = session.email?.isNotEmpty == true
        ? session.email!
        : (session.phone?.isNotEmpty == true ? session.phone! : 'ECLIPSE');
    final subtitle = switch (session.accountType) {
      'telegram' => 'Telegram-аккаунт',
      'phone' => 'Вход по телефону',
      'oauth' || 'oauth_new' => 'Вход через сервис',
      _ => 'Аккаунт сайта',
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          _avatar(session.avatarBase64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                Text('Баланс: ${session.balanceHuman ?? '0 ₽'}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.goldAccent, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  session.phone?.isNotEmpty == true
                      ? 'Телефон: ${session.phone}'
                      : 'Телефон не привязан',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
                if (session.email?.isNotEmpty == true && session.email != name) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Email: ${session.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? base64) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        return CircleAvatar(radius: 30, backgroundImage: MemoryImage(base64Decode(base64)));
      } catch (_) {}
    }
    return const CircleAvatar(
      radius: 30,
      backgroundColor: AppTheme.cardDarkSecondary,
      child: Icon(Icons.person, color: AppTheme.goldAccent, size: 30),
    );
  }

  Widget _menuCard() {
    return _card(Column(
      children: [
        _row(Icons.vpn_key_outlined, 'Мои ключи', 'трафик, QR, устройства', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const KeysScreen()));
        }),
        _divider(),
        _row(Icons.settings_outlined, 'Настройки', 'маршрутизация, автозапуск', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        }),
        _divider(),
        _row(Icons.support_agent, 'Поддержка', 'диагностика и помощь', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
        }),
      ],
    ));
  }

  Widget _referralCard() {
    final ref = _referral;
    if (ref == null || !ref.enabled) return const SizedBox.shrink();
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Реферальная программа', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        Text('Приглашено: ${ref.referralsCount}', style: const TextStyle(color: AppTheme.textSecondary)),
        if (ref.referralLink != null) ...[
          const SizedBox(height: 10),
          SelectableText(ref.referralLink!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _copy('Реферальная ссылка', ref.referralLink),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Скопировать ссылку'),
          ),
        ],
      ],
    ));
  }

  Widget _promoCard() {
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Промокод', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        TextField(
          controller: _promoController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Введите промокод'),
          onSubmitted: (_) => _applyPromo(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(onPressed: _applyPromo, child: const Text('Применить')),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () async {
                await _account.clearPromo();
                if (mounted) setState(() => _promoMessage = 'Промокод убран');
              },
              child: const Text('Убрать'),
            ),
          ],
        ),
        if (_promoMessage != null) ...[
          const SizedBox(height: 8),
          Text(_promoMessage!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ],
    ));
  }

  Widget _historyCard() {
    final history = _history;
    if (history == null || history.items.isEmpty) {
      return _card(const Text('История платежей пока пуста', style: TextStyle(color: AppTheme.textMuted)));
    }
    return _card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('История платежей', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        ...history.items.take(20).map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontSize: 13)),
                        Text(item.dateText, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Text(
                    item.amountText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.cents >= 0 ? AppTheme.successGreen : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    ));
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

  Widget _row(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.goldAccent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(color: AppTheme.cardBorder, height: 1);
}
