import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

/// Экран "О приложении" (аналог AboutActivity в Android)
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Логотип
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.shield_outlined,
                  size: 50,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Название и версия
            Text(
              'ECLIPSE VPN',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Версия 0.1.0 (Build 1)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            
            // Ссылки
            _buildLinkTile(
              icon: Icons.telegram,
              title: 'Telegram-бот',
              subtitle: '@EclipseVPNBot',
              url: 'https://t.me/EclipseVPNBot',
            ),
            _buildLinkTile(
              icon: Icons.public,
              title: 'Сайт',
              subtitle: 'eclipse-vpn.com',
              url: 'https://eclipse-vpn.com',
            ),
            _buildLinkTile(
              icon: Icons.code,
              title: 'GitHub',
              subtitle: 'Исходный код',
              url: 'https://github.com/pomah7878-bot/ECLIPSE_VPN_Windows',
            ),
            
            const SizedBox(height: 32),
            
            // Лицензии
            _buildActionTile(
              icon: Icons.description_outlined,
              title: 'Лицензии открытого ПО',
              onTap: () {
                // TODO: Показать лицензии
              },
            ),
            _buildActionTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Политика конфиденциальности',
              onTap: () {
                // TODO: Открыть политику
              },
            ),
            
            const SizedBox(height: 32),
            
            // Копирайт
            Text(
              '© 2026 ECLIPSE. Все права защищены.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new, size: 16),
        onTap: () => launchUrl(Uri.parse(url)),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
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
