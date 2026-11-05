import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/oauth_service.dart';

class OAuthButtons extends StatelessWidget {
  final Function(OAuthProvider) onSignIn;
  final bool isLoading;

  const OAuthButtons({
    super.key,
    required this.onSignIn,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'или',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(child: Divider(color: AppTheme.border)),
          ],
        ),
        const SizedBox(height: 16),
        
        // Google
        _OAuthButton(
          provider: OAuthProvider.google,
          label: 'Войти через Google',
          icon: Icons.g_mobiledata,
          color: const Color(0xFF4285F4),
          onPressed: isLoading ? null : () => onSignIn(OAuthProvider.google),
        ),
        const SizedBox(height: 8),
        
        // Яндекс
        _OAuthButton(
          provider: OAuthProvider.yandex,
          label: 'Войти через Яндекс',
          icon: Icons.alternate_email,
          color: const Color(0xFFFC3F1D),
          onPressed: isLoading ? null : () => onSignIn(OAuthProvider.yandex),
        ),
        const SizedBox(height: 8),
        
        // VK
        _OAuthButton(
          provider: OAuthProvider.vk,
          label: 'Войти через VK',
          icon: Icons.tag_faces,
          color: const Color(0xFF0077FF),
          onPressed: isLoading ? null : () => onSignIn(OAuthProvider.vk),
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final OAuthProvider provider;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _OAuthButton({
    required this.provider,
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: 24),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textPrimary,
        side: const BorderSide(color: AppTheme.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
