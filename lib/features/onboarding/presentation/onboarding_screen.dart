import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/eclipse_logo.dart';

/// Онбординг при первом запуске: 3 коротких экрана.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (Icons.shield_outlined, 'VPN без сложностей', 'Один клик — и трафик защищён. Сервер выбирается автоматически, ключ подставляется из аккаунта.'),
    (Icons.alt_route, 'Умная маршрутизация', 'Российские сайты — напрямую, остальное — через VPN. Или весь трафик через VPN: режим меняется в настройках.'),
    (Icons.devices, 'Один аккаунт на всех устройствах', 'Windows, Android, Android TV. Подписку можно перенести по QR-коду или ссылке.'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.eclipseBlack,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(onPressed: _finish, child: const Text('Пропустить')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const EclipseLogo(size: 72),
                        const SizedBox(height: 28),
                        Icon(page.$1, size: 64, color: AppTheme.goldAccent),
                        const SizedBox(height: 24),
                        Text(page.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Text(page.$3,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.goldAccent : AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_page == _pages.length - 1) {
                      _finish();
                    } else {
                      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                    }
                  },
                  child: Text(_page == _pages.length - 1 ? 'Начать' : 'Далее'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
