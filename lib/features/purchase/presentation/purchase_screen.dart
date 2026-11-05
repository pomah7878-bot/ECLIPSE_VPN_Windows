import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/tariffs_api.dart';
import '../../../core/api/shop_api.dart';
import '../../../core/api/promo_api.dart';

/// Экран покупки подписки (аналог PurchaseActivity в Android)
class PurchaseScreen extends StatefulWidget {
  final int? keyId;
  
  const PurchaseScreen({super.key, this.keyId});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _tariffsApi = TariffsApi();
  final _shopApi = ShopApi();
  final _promoApi = PromoApi();
  
  List<Tariff> _tariffs = [];
  Tariff? _selectedTariff;
  bool _isLoading = true;
  String? _error;
  
  final _promoController = TextEditingController();
  bool _promoApplied = false;
  String? _promoMessage;

  @override
  void initState() {
    super.initState();
    _loadTariffs();
  }

  Future<void> _loadTariffs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tariffs = await _tariffsApi.getTariffs();
      setState(() {
        _tariffs = tariffs.where((t) => t.isActive).toList();
        _isLoading = false;
        if (_tariffs.isNotEmpty) {
          _selectedTariff = _tariffs.first;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки тарифов';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    try {
      final result = await _promoApi.applyPromoCode(code);
      setState(() {
        _promoApplied = result.success;
        _promoMessage = result.message;
      });
      
      if (result.success) {
        // Пересчитываем цену
        _loadTariffs();
      }
    } catch (e) {
      setState(() {
        _promoApplied = false;
        _promoMessage = 'Ошибка применения промокода';
      });
    }
  }

  Future<void> _buyTariff() async {
    if (_selectedTariff == null) return;

    setState(() => _isLoading = true);

    try {
      final payment = await _shopApi.createPayment(
        tariffId: _selectedTariff!.id,
        keyId: widget.keyId,
        promoCode: _promoApplied ? _promoController.text.trim() : null,
      );

      // Открываем страницу оплаты в браузере
      if (payment.paymentUrl != null) {
        final uri = Uri.parse(payment.paymentUrl!);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Показываем диалог ожидания оплаты
        _showPaymentWaitingDialog(payment.paymentId);
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка создания платежа';
        _isLoading = false;
      });
    }
  }

  void _showPaymentWaitingDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentWaitingDialog(
        paymentId: paymentId,
        onComplete: () {
          Navigator.pop(context);
          Navigator.pop(context, true); // Возврат с результатом
        },
        onCancel: () {
          Navigator.pop(context);
          setState(() => _isLoading = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Покупка подписки')),
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
              onPressed: _loadTariffs,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Тарифы
          Text(
            'Выберите тариф',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          ..._tariffs.map((tariff) => _TariffCard(
            tariff: tariff,
            isSelected: _selectedTariff?.id == tariff.id,
            onSelect: () => setState(() => _selectedTariff = tariff),
          )),
          
          const SizedBox(height: 24),
          
          // Промокод
          _buildPromoCodeSection(),
          
          const SizedBox(height: 24),
          
          // Кнопка покупки
          ElevatedButton(
            onPressed: _selectedTariff == null ? null : _buyTariff,
            child: Text(
              _selectedTariff != null
                  ? 'Купить за ${_selectedTariff!.priceFormatted}'
                  : 'Выберите тариф',
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Информация
          Text(
            'После оплаты подписка активируется автоматически',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Промокод',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                decoration: InputDecoration(
                  hintText: 'Введите промокод',
                  errorText: _promoApplied == false && _promoMessage != null
                      ? _promoMessage
                      : null,
                  suffixIcon: _promoApplied
                      ? const Icon(Icons.check_circle, color: AppTheme.success)
                      : null,
                ),
                enabled: !_promoApplied,
              ),
            ),
            const SizedBox(width: 8),
            if (!_promoApplied)
              ElevatedButton(
                onPressed: _applyPromoCode,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 52),
                ),
                child: const Text('ОК'),
              ),
          ],
        ),
        if (_promoApplied && _promoMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _promoMessage!,
            style: const TextStyle(color: AppTheme.success),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }
}

class _TariffCard extends StatelessWidget {
  final Tariff tariff;
  final bool isSelected;
  final VoidCallback onSelect;

  const _TariffCard({
    required this.tariff,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Радио-кнопка
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tariff.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tariff.durationFormatted} • ${tariff.trafficLimitMb != null ? '${(tariff.trafficLimitMb! / 1024).toStringAsFixed(0)} ГБ' : 'Безлимит'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            Text(
              tariff.priceFormatted,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог ожидания оплаты
class _PaymentWaitingDialog extends StatefulWidget {
  final String paymentId;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _PaymentWaitingDialog({
    required this.paymentId,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<_PaymentWaitingDialog> createState() => _PaymentWaitingDialogState();
}

class _PaymentWaitingDialogState extends State<_PaymentWaitingDialog> {
  final _shopApi = ShopApi();
  bool _isChecking = false;
  String _status = 'waiting';

  @override
  void initState() {
    super.initState();
    _startChecking();
  }

  void _startChecking() {
    // Проверяем статус каждые 3 секунды
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      
      if (!mounted) return false;
      
      try {
        final status = await _shopApi.checkPayment(widget.paymentId);
        if (status.isCompleted) {
          setState(() => _status = 'completed');
          await Future.delayed(const Duration(seconds: 1));
          widget.onComplete();
          return false;
        }
      } catch (e) {
        // Игнорируем ошибки проверки
      }
      
      return mounted && _status == 'waiting';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Ожидание оплаты'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_status == 'waiting') ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Завершите оплату в браузере...'),
            const SizedBox(height: 8),
            Text(
              'Окно можно свернуть, мы уведомим о результате',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            const Icon(
              Icons.check_circle,
              color: AppTheme.success,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text('Оплата прошла успешно!'),
          ],
        ],
      ),
      actions: [
        if (_status == 'waiting')
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Отмена'),
          ),
      ],
    );
  }
}
