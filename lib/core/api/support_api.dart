import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_exception.dart';

/// Ответ AI-ассистента поддержки.
class SupportReply {
  final String text;

  /// Ассистент рекомендует обратиться к человеку.
  final bool escalate;

  SupportReply({required this.text, required this.escalate});
}

/// Чат с AI-помощником ECLIPSE — как в Android (Support.ask).
class SupportApi {
  final _client = ApiClient();

  /// POST /ai-consult (таймаут 90 с — ответ ассистента может быть долгим).
  Future<SupportReply> ask(String message) async {
    final response = await _client.dio.post(
      '/ai-consult',
      data: {'message': message, 'client': 'app'},
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );

    if (response.statusCode == 200) {
      final reply = response.data['reply']?.toString() ?? '';
      if (reply.isNotEmpty) {
        return SupportReply(
          text: reply,
          escalate: response.data['escalate'] == true,
        );
      }
      final msg = response.data['message']?.toString() ?? '';
      throw ApiException(
        message: msg.isNotEmpty
            ? msg
            : (response.data['error'] == 'image_too_large'
                ? 'Скриншот слишком большой'
                : 'Не удалось получить ответ, попробуйте ещё раз'),
      );
    }
    throw ApiException(message: 'Не удалось получить ответ, попробуйте ещё раз');
  }
}
