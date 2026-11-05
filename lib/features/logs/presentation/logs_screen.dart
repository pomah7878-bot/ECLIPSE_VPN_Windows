import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Экран логов (аналог LogcatActivity в Android)
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  LogLevel _filterLevel = LogLevel.info;

  // Симуляция потока логов
  Timer? _logTimer;

  @override
  void initState() {
    super.initState();
    _startLogSimulation();
  }

  void _startLogSimulation() {
    // В реальном приложении — подписка на stdout sing-box
    _logTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _addLog(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: 'sing-box',
        message: 'Connection established to nl1.eclipse-vpn.com:443',
      ));
    });
  }

  void _addLog(LogEntry entry) {
    setState(() {
      _logs.add(entry);
      if (_logs.length > 1000) _logs.removeAt(0);
    });
    
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _logs.where((l) => l.level.index >= _filterLevel.index).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи'),
        actions: [
          // Фильтр по уровню
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            onSelected: (level) => setState(() => _filterLevel = level),
            itemBuilder: (context) => [
              _buildFilterItem(LogLevel.debug, 'Debug'),
              _buildFilterItem(LogLevel.info, 'Info'),
              _buildFilterItem(LogLevel.warning, 'Warning'),
              _buildFilterItem(LogLevel.error, 'Error'),
            ],
          ),
          
          // Автопрокрутка
          IconButton(
            icon: Icon(
              Icons.arrow_downward,
              color: _autoScroll ? AppTheme.primary : AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          
          // Очистка
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _logs.clear()),
          ),
          
          // Поделиться
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Статистика
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatChip(label: 'Всего', value: '${_logs.length}'),
                _StatChip(
                  label: 'Ошибок',
                  value: '${_logs.where((l) => l.level == LogLevel.error).length}',
                  color: AppTheme.error,
                ),
                _StatChip(
                  label: 'Предупреждений',
                  value: '${_logs.where((l) => l.level == LogLevel.warning).length}',
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
          
          // Список логов
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                return _LogTile(log: log);
              },
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<LogLevel> _buildFilterItem(LogLevel level, String label) {
    return PopupMenuItem(
      value: level,
      child: Row(
        children: [
          if (_filterLevel == level)
            const Icon(Icons.check, size: 18, color: AppTheme.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  void _shareLogs() {
    final text = _logs.map((l) => l.toString()).join('\n');
    // TODO: Поделиться через системный диалог
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Логи скопированы в буфер обмена')),
    );
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });

  @override
  String toString() {
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
    return '[$time] [${level.name.toUpperCase()}] [$tag] $message';
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry log;

  const _LogTile({required this.log});

  Color _getLevelColor() {
    switch (log.level) {
      case LogLevel.debug:
        return AppTheme.textSecondary;
      case LogLevel.info:
        return AppTheme.textPrimary;
      case LogLevel.warning:
        return AppTheme.primary;
      case LogLevel.error:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Время
          Text(
            '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.5),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          
          // Уровень
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _getLevelColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.level.name.toUpperCase(),
              style: TextStyle(
                color: _getLevelColor(),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Сообщение
          Expanded(
            child: Text(
              log.message,
              style: TextStyle(
                color: _getLevelColor(),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatChip({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
