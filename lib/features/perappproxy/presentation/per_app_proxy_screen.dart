import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Экран выбора приложений для проксирования (аналог PerAppProxyActivity в Android)
/// На Windows это — выбор процессов, чей трафик идёт через VPN
class PerAppProxyScreen extends StatefulWidget {
  const PerAppProxyScreen({super.key});

  @override
  State<PerAppProxyScreen> createState() => _PerAppProxyScreenState();
}

class _PerAppProxyScreenState extends State<PerAppProxyScreen> {
  bool _enabled = false;
  ProxyMode _mode = ProxyMode.bypass;
  final Set<String> _selectedApps = {};
  String _searchQuery = '';

  // Список популярных приложений Windows
  final List<WindowsApp> _apps = [
    WindowsApp(name: 'Chrome', executable: 'chrome.exe', icon: '🌐'),
    WindowsApp(name: 'Firefox', executable: 'firefox.exe', icon: '🦊'),
    WindowsApp(name: 'Edge', executable: 'msedge.exe', icon: '🌊'),
    WindowsApp(name: 'Telegram', executable: 'Telegram.exe', icon: '✈️'),
    WindowsApp(name: 'Discord', executable: 'Discord.exe', icon: '💬'),
    WindowsApp(name: 'Steam', executable: 'steam.exe', icon: '🎮'),
    WindowsApp(name: 'Spotify', executable: 'Spotify.exe', icon: '🎵'),
    WindowsApp(name: 'Zoom', executable: 'Zoom.exe', icon: '📹'),
    WindowsApp(name: 'Slack', executable: 'slack.exe', icon: '💼'),
    WindowsApp(name: 'VS Code', executable: 'Code.exe', icon: '💻'),
    WindowsApp(name: 'Notion', executable: 'Notion.exe', icon: '📝'),
    WindowsApp(name: 'Figma', executable: 'Figma.exe', icon: '🎨'),
  ];

  List<WindowsApp> get _filteredApps {
    if (_searchQuery.isEmpty) return _apps;
    return _apps.where((app) =>
      app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      app.executable.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Прокси для приложений')),
      body: Column(
        children: [
          // Включение и режим
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Включить выборочный прокси'),
                  subtitle: const Text('Только выбранные приложения используют VPN'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                
                if (_enabled) ...[
                  const Divider(color: AppTheme.border),
                  RadioListTile<ProxyMode>(
                    title: const Text('Только выбранные (Whitelist)'),
                    subtitle: const Text('Выбранные приложения через VPN'),
                    value: ProxyMode.whitelist,
                    groupValue: _mode,
                    onChanged: (v) => setState(() => _mode = v!),
                    activeColor: AppTheme.primary,
                  ),
                  RadioListTile<ProxyMode>(
                    title: const Text('Все кроме выбранных (Bypass)'),
                    subtitle: const Text('Выбранные приложения напрямую'),
                    value: ProxyMode.bypass,
                    groupValue: _mode,
                    onChanged: (v) => setState(() => _mode = v!),
                    activeColor: AppTheme.primary,
                  ),
                ],
              ],
            ),
          ),
          
          // Поиск
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск приложений...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          
          // Список приложений
          Expanded(
            child: !_enabled
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.apps_outlined,
                          size: 64,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Включите выборочный прокси',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Чтобы настроить, какие приложения\nиспользуют VPN',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final isSelected = _selectedApps.contains(app.executable);
                      
                      return CheckboxListTile(
                        secondary: Text(app.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(app.name),
                        subtitle: Text(app.executable),
                        value: isSelected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedApps.add(app.executable);
                            } else {
                              _selectedApps.remove(app.executable);
                            }
                          });
                        },
                        activeColor: AppTheme.primary,
                      );
                    },
                  ),
          ),
          
          // Кнопка сохранения
          if (_enabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selectedApps.isEmpty ? null : _saveConfig,
                child: Text('Сохранить (${_selectedApps.length} приложений)'),
              ),
            ),
        ],
      ),
    );
  }

  void _saveConfig() {
    // TODO: Сохранить конфигурацию для sing-box
    // В sing-box это реализуется через правила маршрутизации по process_name
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сохранены')),
    );
  }
}

enum ProxyMode { whitelist, bypass }

class WindowsApp {
  final String name;
  final String executable;
  final String icon;

  WindowsApp({
    required this.name,
    required this.executable,
    required this.icon,
  });
}
