import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/config_generator.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/vpn_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/eclipse_logo.dart';
import '../../modes/presentation/modes_screen.dart';
import 'widgets/power_button.dart';
import 'widgets/stats_card.dart';

/// Главный экран — как в Android-приложении:
/// шапка с логотипом и профилем, кнопка питания, карточки статуса,
/// сервера и маршрутизации, три карточки статистики.
class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenAccount;

  const HomeScreen({super.key, required this.onOpenAccount});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _vpn = VpnService();
  StreamSubscription<VpnStatus>? _vpnSub;
  Timer? _uptimeTimer;

  VpnStatus _status = const VpnStatus(state: VpnState.disconnected);
  bool _showLogs = false;

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
      setState(() => _status = status);
      if (status.isConnected) {
        if (!_pulseController.isAnimating) _pulseController.repeat();
      } else if (!status.isConnecting) {
        _pulseController.stop();
        _pulseController.reset();
      }
    });

    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _status.isConnected) setState(() {});
    });
  }

  @override
  void dispose() {
    _vpnSub?.cancel();
    _uptimeTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_vpn.isBusy) return;
    if (_vpn.isConnected) {
      await _vpn.disconnect();
    } else {
      setState(() => _showLogs = false);
      final ok = await _vpn.connect();
      if (!ok && mounted) setState(() => _showLogs = true);
    }
  }

  void _openModes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ModesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = SettingsService().routingMode;
    final hasError = _status.state == VpnState.error;
    final hasLogs = _vpn.logs.isNotEmpty;

    return Container(
      color: AppTheme.eclipseBlack,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 4),
              PowerButton(
                isConnected: _status.isConnected,
                isConnecting: _status.isConnecting,
                onTap: _toggleConnection,
                pulseController: _pulseController,
                uptime: _status.uptime,
              ),
              const SizedBox(height: 16),
              _StatusCard(status: _status, onTap: _toggleConnection),
              const SizedBox(height: 12),
              _ServerCard(
                serverName: _status.server.isNotEmpty
                    ? _status.server
                    : 'Автоподбор сервера',
              ),
              const SizedBox(height: 12),
              _RoutingCard(mode: mode.title, onTap: _openModes),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: StatsCard(
                      icon: Icons.arrow_downward,
                      iconColor: AppTheme.successGreen,
                      value: _status.isConnected
                          ? (_status.downloadMbps / 8).toStringAsFixed(1)
                          : '0.0',
                      label: 'МБ/с',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatsCard(
                      icon: Icons.arrow_upward,
                      iconColor: AppTheme.errorRed,
                      value: _status.isConnected
                          ? (_status.uploadMbps / 8).toStringAsFixed(1)
                          : '0.0',
                      label: 'МБ/с',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatsCard(
                      topLabel: 'Ping',
                      value: _status.pingMs?.toString() ?? '--',
                      label: 'мс',
                    ),
                  ),
                ],
              ),
              if (hasError) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _status.message,
                    style: const TextStyle(
                        color: AppTheme.errorRed, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (hasLogs) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => setState(() => _showLogs = !_showLogs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showLogs ? 'Скрыть логи' : 'Показать логи',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Icon(
                        _showLogs ? Icons.expand_more : Icons.expand_less,
                        size: 16,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _vpn.logs));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Логи скопированы'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Text(
                          'Копировать',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.goldAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_showLogs && hasLogs)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(
                        _vpn.logs,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const EclipseLogoSmall(),
          const SizedBox(width: 10),
          const Text(
            'ECLIPSE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Unlimited',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppTheme.goldAccent,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onOpenAccount,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.goldAccent, width: 1.2),
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.goldAccent,
                size: 24,
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
  final VpnStatus status;
  final VoidCallback onTap;

  const _StatusCard({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final connected = status.isConnected;
    return _BaseCard(
      onTap: onTap,
      child: Row(
        children: [
          if (status.isConnecting)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.goldAccent),
            )
          else
            Icon(
              Icons.lock,
              color: connected ? AppTheme.successGreen : AppTheme.textMuted,
              size: 26,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.isConnecting
                      ? (connected ? 'Отключение...' : 'Подключение...')
                      : (connected
                          ? 'VPN подключён'
                          : (status.state == VpnState.error
                              ? 'Ошибка'
                              : 'VPN отключён')),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: connected
                        ? AppTheme.goldAccent
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? 'Трафик зашифрован'
                      : 'Нажмите кнопку для подключения',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  const _ServerCard({required this.serverName});

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      onTap: () {},
      child: Row(
        children: [
          Expanded(
            child: Text(
              serverName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.bolt, color: AppTheme.goldAccent, size: 24),
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
          Expanded(
            child: Text(
              'Маршрутизация: $mode',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppTheme.textSecondary, size: 22),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: child,
      ),
    );
  }
}
