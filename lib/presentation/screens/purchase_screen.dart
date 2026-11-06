import 'package:flutter/material.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/shop_api.dart';
import '../../core/services/oauth_service.dart';
import '../../core/theme/app_theme.dart';

/// Экран личного кабинета / покупки VPN.
///
/// Полная копия Android PurchaseActivity:
/// - Вход по коду из бота
/// - OAuth (Google/Yandex/VK)
/// - Список ключей + импорт
/// - Тарифы + пробный период
/// - Оплата через ЮKassa (QR-код)
/// - Продление ключей
/// - Привязка OAuth к боту (link-code)
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

  // Payment polling
  String? _orderId;
  String? _qrUrl;
  double? _amountRub;
  int? _renewKeyId;

  @override
  void initState() {
    super.initState();
    _silentCheckSession();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _linkCodeController.dispose();
    super.dispose();
  }

  /// Тихая проверка сессии при открытии экрана
  Future<void> _silentCheckSession() async {
    try {
      final session = await _authApi.getSession();
      if (session != null && session.loggedIn) {
        setState(() {
          _keys = session.keys;
          _canLinkOauth = session.canLinkOauth;
        });
        _loadTariffs();
      } else {
        setState(() => _state = _PurchaseState.loginIdle);
      }
    } catch (_) {
      setState(() => _state = _PurchaseState.loginIdle);
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
      if (session != null && session.loggedIn) {
        setState(() {
          _keys = session.keys;
          _canLinkOauth = session.canLinkOauth;
        });
        _loadTariffs();
      } else {
        setState(() {
          _state = _PurchaseState.loginError;
          _errorMessage = 'Сессия не создана';
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _state = _PurchaseState.loginError;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _state = _PurchaseState.loginError;
        _errorMessage = 'Ошибка сети';
      });
    }
  }

  Future<void> _oauthLogin(OAuthProvider provider) async {
    setState(() {
      _state = _PurchaseState.loginLoading;
      _errorMessage = null;
    });

    try {
      final oauth = OAuthService();
      await oauth.signInWithProvider(provider);
      final session = await _authApi.getSession();
      if (session != null && session.loggedIn) {
        setState(() {
          _keys = session.keys;
          _canLinkOauth = session.canLinkOauth;
        });
        _loadTariffs();
      }
    } catch (e) {
      setState(() {
        _state = _PurchaseState.loginError;
        _errorMessage = 'Ошибка OAuth: $e';
      });
    }
  }

  Future<void> _loadTariffs() async {
    setState(() => _state = _PurchaseState.loadingTariffs);
    try {
      final resp = await _shopApi.getTariffs();
      setState(() {
        _tariffs = resp.tariffs;
        _trialAvailable = resp.trialAvailable;
        _state = _PurchaseState.tariffsList;
      });
    } catch (e) {
      setState(() {
        _state = _PurchaseState.tariffsError;
        _errorMessage = 'Не удалось загрузить тарифы';
      });
    }
  }

  Future<void> _createTrial() async {
    setState(() => _state = _PurchaseState.creatingPayment);
    try {
      final resp = await _shopApi.createTrial();
      final subUrl = resp.subUrl;
      if (subUrl != null && subUrl.isNotEmpty) {
        setState(() => _state = _PurchaseState.importSuccess);
      } else {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage = resp.error ?? 'Не удалось активировать пробный период';
        });
      }
    } catch (e) {
      setState(() {
        _state = _PurchaseState.paymentFailed;
        _errorMessage = 'Ошибка активации пробного периода';
      });
    }
  }

  Future<void> _createPayment(int tariffId) async {
    setState(() => _state = _PurchaseState.creatingPayment);
    try {
      final resp = await _shopApi.createPayment(tariffId);
      final orderId = resp.orderId;
      if (orderId != null && orderId.isNotEmpty) {
        setState(() {
          _orderId = orderId;
          _qrUrl = resp.qrUrl;
          _amountRub = resp.amountRub;
          _state = _PurchaseState.waitingPayment;
        });
        _startPolling(orderId);
      } else {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage = resp.error ?? 'Не удалось создать платёж';
        });
      }
    } catch (e) {
      setState(() {
        _state = _PurchaseState.paymentFailed;
        _errorMessage = 'Ошибка создания платежа';
      });
    }
  }

  void _startPolling(String orderId) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;

      try {
        final resp = await _shopApi.checkPayment(orderId);
        if (!mounted) return false;

        switch (resp.status) {
          case 'paid':
            setState(() => _state = _PurchaseState.importSuccess);
            return false;
          case 'failed':
            setState(() {
              _state = _PurchaseState.paymentFailed;
              _errorMessage = 'Платёж не прошёл';
            });
            return false;
          default:
            return true;
        }
      } catch (_) {
        return true;
      }
    });
  }

  Future<void> _createRenewal(int keyId) async {
    setState(() => _state = _PurchaseState.creatingPayment);
    try {
      final resp = await _shopApi.createKeyRenewal(keyId);
      final orderId = resp.orderId;
      if (orderId != null && orderId.isNotEmpty) {
        setState(() {
          _renewKeyId = keyId;
          _orderId = orderId;
          _qrUrl = resp.qrUrl;
          _amountRub = resp.amountRub;
          _state = _PurchaseState.renewWaitingPayment;
        });
        _startRenewPolling(orderId);
      } else {
        setState(() {
          _state = _PurchaseState.paymentFailed;
          _errorMessage = resp.message ?? 'Не удалось создать продление';
        });
      }
    } catch (e) {
      setState(() {
        _state = _PurchaseState.paymentFailed;
        _errorMessage = 'Ошибка создания продления';
      });
    }
  }

  void _startRenewPolling(String orderId) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;

      try {
        final resp = await _shopApi.checkKeyRenewal(orderId);
        if (!mounted) return false;

        switch (resp.status) {
          case 'paid':
            setState(() => _state = _PurchaseState.renewSuccess);
            return false;
          case 'failed':
            setState(() {
              _state = _PurchaseState.paymentFailed;
              _errorMessage = 'Продление не прошло';
            });
            return false;
          default:
            return true;
        }
      } catch (_) {
        return true;
      }
    });
  }

  Future<void> _linkBotCode() async {
    final code = _linkCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _errorMessage = null);
    try {
      final resp = await _authApi.linkBotCode(code);
      if (resp.ok) {
        _linkCodeController.clear();
        final session = await _authApi.getSession();
        if (session != null) {
          setState(() {
            _keys = session.keys;
            _canLinkOauth = session.canLinkOauth;
          });
        }
      } else {
        setState(() => _errorMessage = resp.message ?? 'Не удалось привязать');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Ошибка сети');
    }
  }

  Future<void> _logout() async {
    await _authApi.logout();
    setState(() {
      _keys = [];
      _tariffs = [];
      _codeController.clear();
      _state = _PurchaseState.loginIdle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.eclipseBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Личный кабинет',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _PurchaseState.loginIdle:
      case _PurchaseState.loginLoading:
      case _PurchaseState.loginError:
        return _buildLoginSection();
      case _PurchaseState.loadingAccount:
        return const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent));
      case _PurchaseState.accountOverview:
        return _buildAccountSection();
      case _PurchaseState.loadingTariffs:
        return const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent));
      case _PurchaseState.tariffsError:
        return _buildTariffsError();
      case _PurchaseState.tariffsList:
        return _buildTariffsSection();
      case _PurchaseState.creatingPayment:
        return const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent));
      case _PurchaseState.waitingPayment:
        return _buildWaitingPayment();
      case _PurchaseState.renewWaitingPayment:
        return _buildWaitingPayment(isRenew: true);
      case _PurchaseState.paymentFailed:
        return _buildPaymentFailed();
      case _PurchaseState.importSuccess:
        return _buildImportSuccess();
      case _PurchaseState.renewSuccess:
        return _buildRenewSuccess();
    }
  }

  // ==================== LOGIN ====================
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.eclipseBlack),
                  )
                : const Text('Войти'),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'или',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
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
        const SizedBox(height: 10),
        _SocialButton(
          icon: Icons.shield_outlined,
          label: 'Войти через VK',
          onPressed: isLoading ? null : () => _oauthLogin(OAuthProvider.vk),
        ),
      ],
    );
  }

  // ==================== ACCOUNT ====================
  Widget _buildAccountSection() {
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
        ],
        if (_keys.isEmpty)
          const Text(
            'У вас пока нет ключей',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        if (_canLinkOauth) ...[
          const SizedBox(height: 20),
          const Text(
            'Привязать аккаунт бота',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _linkCodeController,
            decoration: const InputDecoration(
              hintText: 'Код из бота',
              prefixIcon: Icon(Icons.link, color: AppTheme.goldAccent),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _linkBotCode,
              child: const Text('Привязать'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loadTariffs,
            child: Text(_keys.isEmpty ? 'Купить ключ' : 'Купить ещё'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _logout,
            child: const Text('Выйти', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ),
      ],
    );
  }

  // ==================== TARIFFS ====================
  Widget _buildTariffsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            onPressed: () => setState(() => _state = _PurchaseState.accountOverview),
            child: const Text('Назад к ключам', style: TextStyle(color: AppTheme.textMuted)),
          ),
        ),
      ],
    );
  }

  Widget _buildTariffsError() {
    return Column(
      children: [
        Text(_errorMessage ?? 'Ошибка', style: const TextStyle(color: AppTheme.errorRed)),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loadTariffs,
          child: const Text('Повторить'),
        ),
      ],
    );
  }

  // ==================== PAYMENT ====================
  Widget _buildWaitingPayment({bool isRenew = false}) {
    return Column(
      children: [
        Text(
          isRenew ? 'Ожидание продления' : 'Ожидание оплаты',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        if (_amountRub != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_amountRub!.toInt()} ₽',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.goldAccent),
            ),
          ),
        if (_qrUrl != null && _qrUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {}, // TODO: open URL
                child: const Text('Открыть страницу оплаты'),
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent),
            ),
            SizedBox(width: 12),
            Text(
              'Проверяем статус платежа...',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentFailed() {
    return Column(
      children: [
        Text(
          _errorMessage ?? 'Ошибка платежа',
          style: const TextStyle(color: AppTheme.errorRed, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: _loadTariffs,
            child: const Text('Попробовать снова'),
          ),
        ),
      ],
    );
  }

  Widget _buildImportSuccess() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Ключ получен!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Подписка добавлена в ваш аккаунт.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _state = _PurchaseState.accountOverview);
              _silentCheckSession();
            },
            child: const Text('К моим ключам'),
          ),
        ),
      ],
    );
  }

  Widget _buildRenewSuccess() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Ключ продлён!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _state = _PurchaseState.accountOverview);
              _silentCheckSession();
            },
            child: const Text('К моим ключам'),
          ),
        ),
      ],
    );
  }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ====================

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppTheme.goldAccent),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.goldAccent)),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vpnKey.displayName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          if (vpnKey.serverName != null)
            Text(
              vpnKey.serverName!,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  vpnKey.daysLeft != null ? 'Осталось ${vpnKey.daysLeft} дн.' : 'Без срока',
                  style: TextStyle(
                    fontSize: 14,
                    color: (vpnKey.daysLeft ?? 999) > 3 ? AppTheme.successGreen : AppTheme.errorRed,
                  ),
                ),
              ),
              if (vpnKey.trafficLimitGb != null)
                Text(
                  '${vpnKey.trafficUsedGb.toStringAsFixed(1)} / ${vpnKey.trafficLimitGb!.toStringAsFixed(0)} GB',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Продлить', style: TextStyle(color: AppTheme.goldAccent)),
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
        border: Border.all(color: AppTheme.goldAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Пробный период',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.goldAccent),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tariff.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '${tariff.durationDays} дн. — ${tariff.priceRub.toInt()} ₽',
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          if (tariff.trafficLimitGb != null)
            Text(
              'Лимит: ${tariff.trafficLimitGb!.toInt()} GB',
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onBuy,
              child: const Text('Купить'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PurchaseState {
  loginIdle,
  loginLoading,
  loginError,
  loadingAccount,
  accountOverview,
  loadingTariffs,
  tariffsError,
  tariffsList,
  creatingPayment,
  waitingPayment,
  renewWaitingPayment,
  paymentFailed,
  importSuccess,
  renewSuccess,
}