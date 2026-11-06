import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/power_button.dart';
import '../widgets/stats_card.dart';
import 'modes_screen.dart';
import 'purchase_screen.dart';

/// Главный экран — полная копия Android-приложения.
///
/// Скриншоты: home.jpg (отключено), connected.jpg (подключено)
/// - Логотип + иконка профиля вверху
/// - Большая круглая кнопка питания с золотыми лучами
/// - Карточки: статус VPN, сервер, маршрутизация
/// - Статистика: скорость вниз/вверх, пинг
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isConnected = false;
  String _serverName = 'Автоподбор сервера';
  String _routingMode = 'Белые списки';
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  int _ping = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleConnection() {
    setState(() {
      _isConnected = !_isConnected;
      if (_isConnected) {
        _serverName = 'Германия';
        _ping = 15;
        _pulseController.repeat();
      } else {
        _serverName = 'Автоподбор сервера';
        _ping = 0;
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  void _openModes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ModesScreen()),
    );
  }

  void _openPurchase() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PurchaseScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Шапка: логотип + профиль
              _buildHeader(),

              const SizedBox(height: 16),

              // Кнопка питания
              PowerButton(
                isConnected: _isConnected,
                onTap: _toggleConnection,
                pulseController: _pulseController,
              ),

              const SizedBox(height: 24),

              // Карточка статуса VPN
              _StatusCard(
                isConnected: _isConnected,
                onTap: _toggleConnection,
              ),

              const SizedBox(height: 12),

              // Карточка сервера
              _ServerCard(
                serverName: _serverName,
                isConnected: _isConnected,
                onTap: () {},
              ),

              const SizedBox(height: 12),

              // Карточка маршрутизации
              _RoutingCard(
                mode: _routingMode,
                onTap: _openModes,
              ),

              const SizedBox(height: 16),

              // Статистика
              Row(
                children: [
                  Expanded(
                    child: StatsCard(
                      icon: Icons.arrow_downward,
                      iconColor: Colors.greenAccent,
                      value: _downloadSpeed.toStringAsFixed(1),
                      label: 'МБ/c',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatsCard(
                      icon: Icons.arrow_upward,
                      iconColor: Colors.redAccent,
                      value: _uploadSpeed.toStringAsFixed(1),
                      label: 'МБ/c',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatsCard(
                      icon: Icons.network_ping,
                      iconColor: AppTheme.goldAccent,
                      value: _ping > 0 ? '$_ping' : '--',
                      label: 'мс',
                    ),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // Логотип затмения (маленький)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [AppTheme.goldAccent, AppTheme.goldLight],
              ),
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.eclipseBlack,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Название
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ECLIPSE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Unlimited',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.goldAccent,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Иконка профиля / покупки
          GestureDetector(
            onTap: _openPurchase,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.goldAccent.withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                color: AppTheme.goldAccent,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== КАРТОЧКИ ====================

class _StatusCard extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onTap;

  const _StatusCard({required this.isConnected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.lock : Icons.lock_open,
            color: isConnected ? AppTheme.successGreen : AppTheme.textMuted,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'VPN подключён' : 'VPN отключён',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isConnected ? AppTheme.goldAccent : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Трафик зашифрован'
                      : 'Нажмите кнопку для подключения',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final String serverName;
  final bool isConnected;
  final VoidCallback onTap;

  const _ServerCard({
    required this.serverName,
    required this.isConnected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          if (isConnected)
            Container(
              width: 28,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFdd0000),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Center(
                child: Text(
                  'DE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            const Icon(
              Icons.bolt,
              color: AppTheme.goldAccent,
              size: 28,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              serverName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (isConnected)
            const Icon(
              Icons.bolt,
              color: AppTheme.goldAccent,
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _RoutingCard extends StatelessWidget {
  final String mode;
  final VoidCallback onTap;

  const _RoutingCard({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Маршрутизация',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            mode,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textMuted,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BaseCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}