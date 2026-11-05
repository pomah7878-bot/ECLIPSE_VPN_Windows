import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/shop_api.dart';
import '../../../core/api/promo_api.dart';
import '../../purchase/presentation/purchase_screen.dart';

/// Экран профиля пользователя (аналог личного кабинета в Android)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _shopApi = ShopApi();
  final _promoApi = PromoApi();

  double _balance = 0.0;
  ReferralStats _referralStats = ReferralStats.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final balance = await _shopApi.getBalance();
      final stats = await _promoApi.getReferralStats();
      
      setState(() {
        _balance = balance;
        _referralStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Баланс
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  
                  // Реферальная система
                  _buildReferralCard(),
                  const SizedBox(height: 16),
                  
                  // Быстрые действия
                  _buildQuickActions(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Баланс',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.primary,
                  onPressed: _showTopUpDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_balance.toStringAsFixed(2)} ₽',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Пополнить баланс или купить подписку',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Реферальная программа',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Приглашено',
                  value: '${_referralStats.totalReferrals}',
                ),
                _StatItem(
                  label: 'Активных',
                  value: '${_referralStats.activeReferrals}',
                ),
                _StatItem(
                  label: 'Заработано',
                  value: '${_referralStats.totalEarned.toStringAsFixed(0)} ₽',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyReferralLink,
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Поделиться ссылкой'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Быстрые действия',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        
        _ActionTile(
          icon: Icons.shopping_cart_outlined,
          title: 'Купить подписку',
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseScreen()),
            );
            if (result == true) _loadProfile();
          },
        ),
        
        _ActionTile(
          icon: Icons.history,
          title: 'История платежей',
          onTap: () {
            // TODO: История платежей
          },
        ),
        
        _ActionTile(
          icon: Icons.casino_outlined,
          title: 'Рулетка бонусов',
          onTap: _spinRoulette,
        ),
      ],
    );
  }

  void _showTopUpDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Пополнение баланса'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Сумма, ₽',
            prefixIcon: Icon(Icons.currency_ruble),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                // TODO: Создать платёж на пополнение
              }
            },
            child: const Text('Пополнить'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyReferralLink() async {
    final link = await _promoApi.getReferralLink();
    if (link != null) {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка скопирована')),
        );
      }
    }
  }

  Future<void> _spinRoulette() async {
    // TODO: Реализовать рулетку
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Рулетка скоро будет доступна')),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
