import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_api.dart';
import '../../../core/api/shop_api.dart';
import '../../../core/services/oauth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_theme.dart';

enum _PurchaseState {
  loginIdle,
  loginLoading,
  loadingTariffs,
  tariffsList,
  tariffsError,
  creatingPayment,
  waitingPayment,
  renewWaitingPayment,
  paymentFailed,
  success,
}

/// Личный кабинет / покупка VPN.
///
/// - Вход по коду из бота, OAuth (Google/Yandex)
/// - Список ключей + продление
/// - Тарифы + пробный период
/// - Оплата через ЮKassa: открытие страницы оплаты в браузере + поллинг статуса
/// - Привязка OAuth-аккаунта к боту (link-code)
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _authApi = AuthApi();
  final _shopApi = ShopApi();
  final _codeController = TextEditingController();
  final _linkCodeController = TextEditingController();

  _PurchaseState _state = _PurchaseState.loginIdle;
  String? _errorMessage;
  List<AccountKeyDto> _keys = [];
  List<TariffDto> _tariffs = [];
  bool _trialAvailable = false;
  bool _canLinkOauth = false;

  String? _orderId;
  String? _qrUrl;
  double? _amountRub;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    SessionService.loggedIn.addListener(_onSessionChanged);
    _silentCheckSession();
  }

  void _onSessionChanged() {
    if (mounted) _silentCheckSession();
  }

  @override
  void dispose() {
    SessionService.loggedIn.removeListener(_onSessionChanged);
    _codeController.dispose();
    _linkCodeController.dispose();
    _polling = false;
    super.dispose();
  }

  // ==================== ЛОГИКА ====================

  Future<void> _silentCheckSession() async {
    try {
      final session = await _authApi.getSession();
      if (!mounted) return;
      if (session != null && session.loggedIn) {
        SessionService.setLoggedIn(true);
        setState(() {
          _keys = session.keys;
          _canLinkOauth = session.canLinkOauth;
        });
        _loadTariffs();
      } else {
        SessionService.setLoggedIn(false);
        setState(() => _state = _PurchaseState.loginIdle);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _PurchaseState.loginIdle);
    }
  }

  Future<void> _login() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _state = _PurchaseState.loginLoading;
      _errorMessage = null;
    });

    try {
      await _authApi.loginWithCode(code);
      final session = await _authApi.getSession();
      if (!mounted) return;
      if (session != null && session.loggedIn) {
        SessionService.setLoggedIn(true);
        setState(() {
          _keys = session.keys;
          _canLinkOauth = session.canLinkOauth;
        });
        _loadTariffs();
      } else {
        setState(() {
          _state = _PurchaseState.loginIdle;
          _errorMessage = 'Сессия не создана';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.loginIdle;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.loginIdle;
          _errorMessage = 'Ошибка сети';
        });
      }
    }
  }

  Future<void> _oauthLogin(OAuthProvider provider) async {
    setState(() {
      _state = _PurchaseState.loginLoading;
      _errorMessage = null;
    });

    try {
      await OAuthService().signInWithProvider(provider);
      final session = await _authApi.getSession();
      if (!mounted) return;
      if (session != null && session.loggedIn) {
        SessionService.setLoggedIn(true);
        setState(() {
          _keys = session.keys;
          _canLinkOauth = session.canLinkOauth;
        });
        _loadTariffs();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.loginIdle;
          _errorMessage = 'Ошибка OAuth: $e';
        });
      }
    }
  }

  Future<void> _loadTariffs() async {
    setState(() => _state = _PurchaseState.loadingTariffs);
    try {
      final resp = await _shopApi.getTariffs();
      if (!mounted) return;
      setState(() {
        _tariffs = resp.tariffs;
        _trialAvailable = resp.trialAvailable;
        _state = _PurchaseState.tariffsList;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.tariffsError;
          _errorMessage = 'Не удалось загрузить тарифы';
        });
      }
    }
  }

  Future<void> _createTrial() async {
    setState(() => _state = _PurchaseState.creatingPayment);
    try {
      final resp = await _shopApi.createTrial();
      if (!mounted) return;
      if (resp.subUrl != null && resp.subUrl!.isNotEmpty) {
        setState(() => _state = _PurchaseState.success);
        await _silentCheckSession();
      } else {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage =
              resp.error ?? 'Не удалось активировать пробный период';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage = 'Ошибка активации пробного периода';
        });
      }
    }
  }

  Future<void> _createPayment(int tariffId) async {
    setState(() => _state = _PurchaseState.creatingPayment);
    try {
      final resp = await _shopApi.createPayment(tariffId);
      if (!mounted) return;
      _orderId = resp.orderId;
      _qrUrl = resp.qrUrl;
      _amountRub = resp.amountRub;
      setState(() => _state = _PurchaseState.waitingPayment);
      _openPaymentPage();
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage = e is ApiException ? e.message : 'Ошибка платежа';
        });
      }
    }
  }

  Future<void> _createRenewal(int keyId) async {
    setState(() => _state = _PurchaseState.creatingPayment);
    try {
      final resp = await _shopApi.createKeyRenewal(keyId);
      if (!mounted) return;
      _orderId = resp.orderId;
      _qrUrl = resp.qrUrl;
      _amountRub = resp.amountRub;
      setState(() => _state = _PurchaseState.renewWaitingPayment);
      _openPaymentPage();
      _startPolling(isRenew: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage = e is ApiException ? e.message : 'Ошибка продления';
        });
      }
    }
  }

  Future<void> _openPaymentPage() async {
    final url = _qrUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _startPolling({bool isRenew = false}) {
    final orderId = _orderId;
    if (orderId == null || _polling) return;
    _polling = true;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || !_polling) return false;

      try {
        final status = isRenew
            ? (await _shopApi.checkKeyRenewal(orderId)).status
            : (await _shopApi.checkPayment(orderId)).status;
        if (!mounted) return false;

        switch (status) {
          case 'paid':
            _polling = false;
            setState(() => _state = _PurchaseState.success);
            await _silentCheckSession();
            return false;
          case 'failed':
            _polling = false;
            setState(() {
              _state = _PurchaseState.paymentFailed;
              _errorMessage = isRenew ? 'Продление не прошло' : 'Платёж не прошёл';
            });
            return false;
          default:
            return true;
        }
      } catch (_) {
        return mounted && _polling;
      }
    });
  }

  Future<void> _linkBotCode() async {
    final code = _linkCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _errorMessage = null);
    try {
      final resp = await _authApi.linkBotCode(code);
      if (!mounted) return;
      if (resp.ok) {
        _linkCodeController.clear();
        await _silentCheckSession();
      } else {
        setState(() => _errorMessage = resp.message ?? 'Не удалось привязать');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Ошибка сети');
    }
  }

  Future<void> _logout() async {
    _polling = false;
    await _authApi.logout();
    SessionService.setLoggedIn(false);
    if (!mounted) return;
    setState(() {
      _keys = [];
      _tariffs = [];
      _codeController.clear();
      _state = _PurchaseState.loginIdle;
    });
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(title: const Text('Личный кабинет')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(child: _buildContent()),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _PurchaseState.loginIdle:
      case _PurchaseState.loginLoading:
        return _buildLoginSection();
      case _PurchaseState.loadingTariffs:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppTheme.goldAccent),
          ),
        );
      case _PurchaseState.tariffsError:
        return _buildError(_errorMessage ?? 'Ошибка', _loadTariffs);
      case _PurchaseState.tariffsList:
        return _buildTariffsSection();
      case _PurchaseState.creatingPayment:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppTheme.goldAccent),
          ),
        );
      case _PurchaseState.waitingPayment:
      case _PurchaseState.renewWaitingPayment:
        return _buildWaitingPayment(
            isRenew: _state == _PurchaseState.renewWaitingPayment);
      case _PurchaseState.paymentFailed:
        return _buildError(_errorMessage ?? 'Ошибка платежа', _loadTariffs);
      case _PurchaseState.success:
        return _buildSuccess();
    }
  }

  Widget _buildLoginSection() {
    final isLoading = _state == _PurchaseState.loginLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Введите код доступа из Telegram-бота или войдите через соцсети',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            hintText: 'Код доступа',
            prefixIcon: Icon(Icons.key, color: AppTheme.goldAccent),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
          enabled: !isLoading,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: isLoading ? null : _login,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.eclipseBlack),
                  )
                : const Text('Войти'),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text('или',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: Icons.g_mobiledata,
          label: 'Войти через Google',
          onPressed: isLoading ? null : () => _oauthLogin(OAuthProvider.google),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          icon: Icons.account_circle_outlined,
          label: 'Войти через Яндекс',
          onPressed: isLoading ? null : () => _oauthLogin(OAuthProvider.yandex),
        ),
      ],
    );
  }

  Widget _buildTariffsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_keys.isNotEmpty) ...[
          const Text(
            'Ваши ключи',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._keys.map((k) => _KeyCard(
                vpnKey: k,
                onRenew: () => _createRenewal(k.keyId),
              )),
          const SizedBox(height: 8),
        ],
        if (_canLinkOauth) ...[
          const Text(
            'Привязать аккаунт бота',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _linkCodeController,
                  decoration: const InputDecoration(
                    hintText: 'Код из бота',
                    prefixIcon: Icon(Icons.link, color: AppTheme.goldAccent),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _linkBotCode,
                  child: const Text('Привязать'),
                ),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorMessage!,
                  style:
                      const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
            ),
          const SizedBox(height: 20),
        ],
        const Text(
          'Выберите тариф',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (_trialAvailable) ...[
          const SizedBox(height: 12),
          _TrialCard(onTap: _createTrial),
        ],
        const SizedBox(height: 12),
        ..._tariffs.map((t) => _TariffCard(
              tariff: t,
              onBuy: () => _createPayment(t.id),
            )),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _logout,
            child: const Text('Выйти',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingPayment({bool isRenew = false}) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          isRenew ? 'Ожидание продления' : 'Ожидание оплаты',
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        if (_amountRub != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_amountRub!.toInt()} ₽',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.goldAccent),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _openPaymentPage,
            child: const Text('Открыть страницу оплаты'),
        ),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.goldAccent),
            ),
            SizedBox(width: 12),
            Text(
              'Проверяем статус платежа...',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            _polling = false;
            _loadTariffs();
          },
          child: const Text('Отмена',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
      ],
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Text(message,
            style: const TextStyle(color: AppTheme.errorRed, fontSize: 16),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Попробовать снова'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Готово!',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Подписка добавлена в ваш аккаунт.\nМожно подключаться к VPN.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loadTariffs,
            child: const Text('К моим ключам'),
          ),
        ),
      ],
    );
  }
}

// ==================== ВИДЖЕТЫ ====================

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppTheme.goldAccent),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(fontSize: 15, color: AppTheme.goldAccent)),
          ],
        ),
      ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final AccountKeyDto vpnKey;
  final VoidCallback onRenew;

  const _KeyCard({required this.vpnKey, required this.onRenew});

  @override
  Widget build(BuildContext context) {
    final days = vpnKey.daysLeft;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vpnKey.displayName,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          if (vpnKey.serverName != null)
            Text(
              vpnKey.serverName!,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  days != null ? 'Осталось $days дн.' : 'Без срока',
                  style: TextStyle(
                    fontSize: 14,
                    color: (days ?? 999) > 3
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                ),
              ),
              if (vpnKey.trafficLimitGb != null)
                Text(
                  '${vpnKey.trafficUsedGb.toStringAsFixed(1)} / '
                  '${vpnKey.trafficLimitGb!.toStringAsFixed(0)} GB',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onRenew,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.goldAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child:
                  const Text('Продлить', style: TextStyle(color: AppTheme.goldAccent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrialCard extends StatelessWidget {
  final VoidCallback onTap;

  const _TrialCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Пробный период',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.goldAccent),
          ),
          const SizedBox(height: 4),
          const Text(
            'Бесплатный доступ на 3 дня',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              child: const Text('Активировать'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final TariffDto tariff;
  final VoidCallback onBuy;

  const _TariffCard({required this.tariff, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: tariff.isCurrent
            ? Border.all(color: AppTheme.goldAccent, width: 1.5)
            : Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tariff.name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tariff.durationDays} дн.'
                  '${tariff.trafficLimitGb != null ? ' · ${tariff.trafficLimitGb!.toStringAsFixed(0)} GB' : ''}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tariff.priceFormatted,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.goldAccent),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onBuy,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Купить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
