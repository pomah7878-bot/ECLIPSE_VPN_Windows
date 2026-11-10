/// Общее исключение API-слоя.
class ApiException implements Exception {
  final String message;
  final String? code;

  ApiException({required this.message, this.code});

  @override
  String toString() => message;
}
