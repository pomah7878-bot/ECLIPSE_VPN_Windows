import 'package:flutter/material.dart';

import '../../../core/services/config_generator.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/vpn_service.dart';
import '../../../core/theme/app_theme.dart';

/// Экран режимов маршрутизации — выбор реально применяется к VPN.
class ModesScreen extends StatefulWidget {
  const ModesScreen({super.key});

  @override
  State<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends State<ModesScreen> {
  final _settings = SettingsService();
  final _vpn = VpnService();
  bool _isSwitching = false;

  Future<void> _selectMode(RoutingMode mode) async {
    if (_isSwitching || mode == _settings.routingMode) return;
    setState(() => _isSwitching = true);
    try {
      await _settings.setRoutingMode(mode);
      // Если VPN подключён — переподключаем с новым конфигом
      if (_vpn.isConnected) {
        await _vpn.disconnect();
        await _vpn.connect();
      }
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Режимы маршрутизации'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_isSwitching)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(color: AppTheme.goldAccent),
              ),
            ...RoutingMode.values.map(
              (mode) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ModeCard(
                  title: mode.title,
                  description: mode.description,
                  isSelected: mode == _settings.routingMode,
                  onTap: () => _selectMode(mode),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Режим можно изменить в любой момент.\n'
              'При смене режима активное подключение будет перезапущено.\n'
              'Списки российских ресурсов обновляются с сервера автоматически.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppTheme.goldAccent, width: 2)
              : Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppTheme.goldAccent
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppTheme.goldAccent, size: 24),
          ],
        ),
      ),
    );
  }
}
