import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';

/// Экран резервного копирования (аналог BackupActivity в Android)
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Резервная копия')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Описание
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Резервная копия включает все настройки, серверы и конфигурации',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Экспорт
            _buildBackupCard(
              icon: Icons.upload_file,
              title: 'Экспорт настроек',
              description: 'Сохранить все настройки в файл',
              isLoading: _isExporting,
              onTap: _exportBackup,
            ),
            const SizedBox(height: 16),
            
            // Импорт
            _buildBackupCard(
              icon: Icons.download,
              title: 'Импорт настроек',
              description: 'Восстановить из резервной копии',
              isLoading: _isImporting,
              onTap: _importBackup,
            ),
            
            const Spacer(),
            
            // Информация
            Text(
              'Файл резервной копии зашифрован и может быть\nперенесён на другое устройство',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: AppTheme.primary, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: isLoading ? null : onTap,
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);

    try {
      // TODO: Собрать все настройки в JSON
      // TODO: Зашифровать файл
      // TODO: Сохранить через file_picker
      
      await Future.delayed(const Duration(seconds: 2)); // Заглушка
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Резервная копия сохранена')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'bak', 'eclipse'],
    );

    if (result == null) return;

    setState(() => _isImporting = true);

    try {
      // TODO: Прочитать файл
      // TODO: Расшифровать
      // TODO: Применить настройки
      
      await Future.delayed(const Duration(seconds: 2)); // Заглушка
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Настройки восстановлены')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}
