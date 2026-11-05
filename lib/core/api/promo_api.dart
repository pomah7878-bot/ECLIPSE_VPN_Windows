import 'api_client.dart';

/// API для промокодов и реферальной системы (аналог в Android)
class PromoApi {
  final _client = ApiClient();

  /// Применить промокод
  /// POST /api/promo/apply
  Future<PromoResult> applyPromoCode(String code) async {
    final response = await _client.dio.post(
      '/api/promo/apply',
      data: {'code': code},
    );

    if (response.statusCode == 200 && response.data['ok'] == true) {
      return PromoResult(
        success: true,
        message: response.data['message'] ?? 'Промокод применён',
        bonusDays: response.data['bonus_days'],
        bonusAmount: response.data['bonus_amount'],
      );
    } else {
      return PromoResult(
        success: false,
        message: response.data['message'] ?? 'Неверный промокод',
      );
    }
  }

  /// Получить реферальную ссылку
  /// GET /api/referral/link
  Future<String?> getReferralLink() async {
    final response = await _client.dio.get('/api/referral/link');
    if (response.statusCode == 200) {
      return response.data['link'];
    }
    return null;
  }

  /// Получить реферальную статистику
  /// GET /api/referral/stats
  Future<ReferralStats> getReferralStats() async {
    final response = await _client.dio.get('/api/referral/stats');
    if (response.statusCode == 200) {
      return ReferralStats.fromJson(response.data);
    }
    return ReferralStats.empty();
  }

  /// Рулетка (если включена в боте)
  /// POST /api/roulette/spin
  Future<RouletteResult> spinRoulette() async {
    final response = await _client.dio.post('/api/roulette/spin');

    if (response.statusCode == 200 && response.data['ok'] == true) {
      return RouletteResult(
        success: true,
        prize: response.data['prize'],
        prizeType: response.data['prize_type'],
      );
    } else {
      return RouletteResult(
        success: false,
        error: response.data['message'] ?? 'Ошибка рулетки',
      );
    }
  }
}

class PromoResult {
  final bool success;
  final String message;
  final int? bonusDays;
  final double? bonusAmount;

  PromoResult({
    required this.success,
    required this.message,
    this.bonusDays,
    this.bonusAmount,
  });
}

class ReferralStats {
  final int totalReferrals;
  final int activeReferrals;
  final double totalEarned;
  final double pendingEarned;

  ReferralStats({
    required this.totalReferrals,
    required this.activeReferrals,
    required this.totalEarned,
    required this.pendingEarned,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      totalReferrals: json['total_referrals'] ?? 0,
      activeReferrals: json['active_referrals'] ?? 0,
      totalEarned: (json['total_earned'] ?? 0).toDouble(),
      pendingEarned: (json['pending_earned'] ?? 0).toDouble(),
    );
  }

  factory ReferralStats.empty() {
    return ReferralStats(
      totalReferrals: 0,
      activeReferrals: 0,
      totalEarned: 0,
      pendingEarned: 0,
    );
  }
}

class RouletteResult {
  final bool success;
  final String? prize;
  final String? prizeType;
  final String? error;

  RouletteResult({
    required this.success,
    this.prize,
    this.prizeType,
    this.error,
  });
}
