import 'dart:async';
import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import '../../core/services/vpn_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/power_button.dart';
import '../widgets/stats_card.dart';
import 'modes_screen.dart';
import 'purchase_screen.dart';

/// Главный экран — полная копия Android-приложения.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _vpn = VpnService();
  StreamSubscription? _vpnSub;

  bool _isConnected = false;
  bool _isConnecting = false;
  String _serverName = 'Автоподбор сервера';
  String _routingMode = 'Белые списки';
  double _downloadSpeed = 0.0;
  double _uploadSpeed = 0.0;
  int _ping = 0;
  String? _errorMessage;
  String _logs = '';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _vpnSub = _vpn.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _isConnected = status.isConnected;
        _isConnecting = status.isConnecting;
        _serverName = status.server.isNotEmpty ? status.server : 'Автоподбор сервера';
        _errorMessage = status.isConnected || status.isConnecting ? null : _errorMessage;
        _logs = status.logs;

        if (_isConnected) {
          _pulseController.repeat();
        } else if (!_isConnecting) {
          _pulseController.stop();
          _pulseController.reset();
        }
      });
    });
  }

  @override
  void dispose() {
    _vpnSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_isConnecting) return;

    if (_isConnected) {
      setState(() => _isConnecting = true);
      await _vpn.disconnect();
    } else {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
        _logs = '';
      });

      final success = await _vpn.connect();
      if (!success && mounted) {
        setState(() {
          _errorMessage = _vpn.statusMessage;
        });
      }
    }
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
              _buildHeader(),
              const SizedBox(height: 16),
              PowerButton(
                isConnected: _isConnected,
                isConnecting: _isConnecting,
                onTap: _toggleConnection,
                pulseController: _pulseController,
              ),
              const SizedBox(height: 24),
              _StatusCard(
                isConnected: _isConnected,
                isConnecting: _isConnecting,
                onTap: _toggleConnection,
              ),
              const SizedBox(height: 12),
              _ServerCard(
                serverName: _serverName,
                isConnected: _isConnected,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _RoutingCard(
                mode: _routingMode,
                onTap: _openModes,
              ),
              const SizedBox(height: 16),
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
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (_logs.isNotEmpty && !_isConnected) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _logs,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
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
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
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
  final bool isConnecting;
  final VoidCallback onTap;

  const _StatusCard({
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          if (isConnecting)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.goldAccent,
              ),
            )
          else
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
                  isConnecting
                      ? 'Подключение...'
                      : (isConnected ? 'VPN подключён' : 'VPN отключён'),
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