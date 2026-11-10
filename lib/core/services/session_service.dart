import 'package:flutter/foundation.dart';

/// Глобальное состояние сессии (для реакции вкладок на вход/выход).
class SessionService {
  SessionService._();

  static final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);

  static void setLoggedIn(bool value) {
    loggedIn.value = value;
  }
}
