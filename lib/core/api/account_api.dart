import 'api_client.dart';
import 'api_exception.dart';

/// Профиль сайт-аккаунта: реферал, история платежей, промокоды, действия с ключами.
class AccountApi {
  final _client = ApiClient();

  /// GET /public/account/referral
  Future<ReferralInfo> getReferral() async {
    final response = await _client.dio.get('/public/account/referral');
    if (response.statusCode == 200) {
      return ReferralInfo.fromJson(response.data);
    }
    throw ApiException(message: 'Не удалось загрузить реферальную программу');
  }

  /// GET /public/account/history
  Future<HistoryInfo> getHistory() async {
    final response = await _client.dio.get('/public/account/history');
    if (response.statusCode == 200) {
      return HistoryInfo.fromJson(response.data);
    }
    throw ApiException(message: 'Не удалось загрузить историю');
  }

  /// POST /public/promo/apply
  Future<String?> applyPromo(String code) async {
    try {
      final response = await _client.dio.post(
        '/public/promo/apply',
        data: {'code': code},
      );
      if (response.statusCode == 200 && response.data['ok'] == true) {
        return null;
      }
      return response.data['message']?.toString() ?? 'Промокод не применён';
    } catch (e) {
      final data = _errorData(e);
      return data?['message']?.toString() ?? 'Промокод не применён';
    }
  }

  /// POST /public/promo/clear
  Future<void> clearPromo() async {
    try {
      await _client.dio.post('/public/promo/clear');
    } catch (_) {
      // не критично
    }
  }

  /// POST /public/account/key/rename
  Future<String?> renameKey(int keyId, String name) async {
    try {
      final response = await _client.dio.post(
        '/public/account/key/rename',
        data: {'key_id': keyId, 'name': name},
      );
      if (response.statusCode == 200 && response.data['ok'] == true) return null;
      return response.data['error']?.toString() ?? 'Не удалось переименовать';
    } catch (e) {
      final data = _errorData(e);
      return data?['message']?.toString() ?? 'Не удалось переименовать ключ';
    }
  }

  /// POST /public/account/key/delete
  Future<String?> deleteKey(int keyId) async {
    try {
      final response = await _client.dio.post(
        '/public/account/key/delete',
        data: {'key_id': keyId},
      );
      if (response.statusCode == 200 && response.data['ok'] == true) return null;
      final error = response.data['error']?.toString();
      if (error == 'key_still_active') return 'Ключ ещё активен — удалить нельзя';
      return response.data['message']?.toString() ?? 'Не удалось удалить ключ';
    } catch (e) {
      final data = _errorData(e);
      final error = data?['error']?.toString();
      if (error == 'key_still_active') return 'Ключ ещё активен — удалить нельзя';
      return data?['message']?.toString() ?? 'Не удалось удалить ключ';
    }
  }

  static Map<String, dynamic>? _errorData(Object e) {
    try {
      final dynamic d = e;
      final data = d.response?.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      // ignore
    }
    return null;
  }
}

class ReferralInfo {
  final bool enabled;
  final String? referralLink;
  final String? referralCode;
  final int balanceCents;
  final String? balanceHuman;
  final int referralsCount;

  ReferralInfo({
    required this.enabled,
    this.referralLink,
    this.referralCode,
    this.balanceCents = 0,
    this.balanceHuman,
    this.referralsCount = 0,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      enabled: json['enabled'] ?? false,
      referralLink: json['referral_link']?.toString(),
      referralCode: json['referral_code']?.toString(),
      balanceCents: _asInt(json['balance_cents']),
      balanceHuman: json['balance_human']?.toString(),
      referralsCount: _asInt(json['referrals_count']),
    );
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}

class HistoryInfo {
  final int balanceCents;
  final String? balanceHuman;
  final List<HistoryItem> items;

  HistoryInfo({
    required this.balanceCents,
    this.balanceHuman,
    required this.items,
  });

  factory HistoryInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List ? raw : const <dynamic>[];
    return HistoryInfo(
      balanceCents: _asInt(json['balance_cents']),
      balanceHuman: json['balance_human']?.toString(),
      items: list
          .whereType<Map<String, dynamic>>()
          .map(HistoryItem.fromJson)
          .toList(),
    );
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
}

class HistoryItem {
  final String at;
  final int cents;
  final String title;

  HistoryItem({required this.at, required this.cents, required this.title});

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      at: json['at']?.toString() ?? '',
      cents: json['cents'] is int ? json['cents'] : int.tryParse('${json['cents']}') ?? 0,
      title: json['title']?.toString() ?? 'Операция',
    );
  }

  String get amountText {
    final sign = cents >= 0 ? '+' : '−';
    final rub = (cents.abs() / 100).toStringAsFixed(0);
    return '$sign$rub ₽';
  }

  String get dateText {
    final dt = DateTime.tryParse(at.replaceFirst(' ', 'T'));
    if (dt == null) return at;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}
