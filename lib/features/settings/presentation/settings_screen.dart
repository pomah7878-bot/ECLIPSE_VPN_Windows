import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/presentation/login_screen.dart';
import '../../perappproxy/presentation/per_app_proxy_screen.dart';
import '../../logs/presentation/logs_screen.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../about/presentation/about_screen.dart';

/// Экран настроек (аналог SettingsActivity в Android)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _routingService = RoutingService();
  final _authService = AuthService();
  
  String _currentRouting = RoutingService.routingEclipse;
  bool _autoConnect = false;
  bool _launchAtStartup = false;
  bool _showNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: Загрузить из SharedPreferences
    setState(() {
      _currentRouting = _routingService.currentRouting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Маршрутизация
          _buildSectionHeader('Маршрутизация'),
          _buildRoutingSelector(),
          const SizedBox(height: 24),
          
          // Подключение
          _buildSectionHeader('Подключение'),
          SwitchListTile(
            title: const Text('Автоподключение'),
            subtitle: const Text('Подключаться при запуске приложения'),
            value: _autoConnect,
            onChanged: (v) => setState(() => _autoConnect = v),
          ),
          SwitchListTile(
            title: const Text('Запускать при старте Windows'),
            value: _launchAtStartup,
            onChanged: (v) => setState(() => _launchAtStartup = v),
          ),
          const SizedBox(height: 24),
          
          // Уведомления
          _buildSectionHeader('Уведомления'),
          SwitchListTile(
            title: const Text('Показывать уведомления'),
            subtitle: const Text('Статус подключения, окончание подписки'),
            value: _showNotifications,
            onChanged: (v) => setState(() => _showNotifications = v),
          ),
          const SizedBox(height: 24),
          
          // Прокси для приложений
          _buildSectionHeader('Приложения'),
          ListTile(
            title: const Text('Прокси для приложений'),
            subtitle: const Text('Выборочное проксирование'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerAppProxyScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Инструменты
          _buildSectionHeader('Инструменты'),
          ListTile(
            title: const Text('Логи'),
            subtitle: const Text('Просмотр журнала работы'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Резервная копия'),
            subtitle: const Text('Экспорт и импорт настроек'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // О приложении
          _buildSectionHeader('О приложении'),
          ListTile(
            title: const Text('Версия'),
            trailing: Text('0.1.0', style: Theme.of(context).textTheme.bodyMedium),
          ),
          ListTile(
            title: const Text('Проверить обновления'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Проверка обновлений
            },
          ),
          ListTile(
            title: const Text('О приложении'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Выход
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти из аккаунта'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildRoutingSelector() {
    final routings = _routingService.getAvailableRoutings();
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: routings.map((routing) {
          final isSelected = routing.id == _currentRouting;
          return RadioListTile<String>(
            title: Text(routing.name),
            subtitle: Text(
              routing.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: routing.id,
            groupValue: _currentRouting,
            onChanged: (value) {
              if (value != null) {
                setState(() => _currentRouting = value);
                _routingService.setRoutingType(value);
              }
            },
            activeColor: AppTheme.primary,
          );
        }).toList(),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
