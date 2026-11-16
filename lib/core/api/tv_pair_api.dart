import 'api_client.dart';

/// Перенос подписки с телефона на Windows по QR (та же механика, что на TV).
class TvPairApi {
  final _client = ApiClient();

  /// POST /public/tv-pair/create
  Future<TvPairSession> create() async {
    final response = await _client.dio.post('/public/tv-pair/create');
    if (response.statusCode == 200 && response.data['ok'] == true) {
      return TvPairSession(
        code: response.data['code']?.toString() ?? '',
        token: response.data['token']?.toString() ?? '',
        url: response.data['url']?.toString() ?? '',
        expiresIn: int.tryParse('${response.data['expires_in']}') ?? 600,
      );
    }
    throw Exception('Не удалось создать QR');
  }

  /// GET /public/tv-pair/get — null, пока телефон не прислал подписку.
  Future<String?> fetchBody(TvPairSession session) async {
    final response = await _client.dio.get(
      '/public/tv-pair/get',
      queryParameters: {'code': session.code, 'token': session.token},
    );
    if (response.statusCode != 200 || response.data['ok'] != true) return null;
    if (response.data['ready'] != true) return null;
    final body = response.data['body']?.toString();
    return (body == null || body.isEmpty) ? null : body;
  }
}

class TvPairSession {
  final String code;
  final String token;
  final String url;
  final int expiresIn;

  TvPairSession({
    required this.code,
    required this.token,
    required this.url,
    required this.expiresIn,
  });
}
