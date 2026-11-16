import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Первый запуск: короткий онбординг, как в Android.
class OnboardingService {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  static const _key = 'onboarding_done_v1';
  SharedPreferences? _prefs;

  final ValueNotifier<bool> done = ValueNotifier<bool>(true);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    done.value = _prefs?.getBool(_key) ?? false;
  }

  Future<void> markDone() async {
    done.value = true;
    await _prefs?.setBool(_key, true);
  }
}
