/// An error returned by the KaamNow API (or a network failure).
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.code, required this.message, this.details});

  factory ApiException.network(Object error) =>
      ApiException(statusCode: 0, code: 'network_error', message: 'Could not reach KaamNow. Check your connection.');

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  /// Field errors from a validation response, flattened to "field: message".
  Map<String, String> get fieldErrors {
    final d = details;
    if (d is! Map) return const {};
    final out = <String, String>{};
    d.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        out['$key'] = value.map((e) => '$e').join(' ');
      } else if (value is String) {
        out['$key'] = value;
      } else if (value is Map) {
        out['$key'] = value.values.map((e) => e is List ? e.join(' ') : '$e').join(' ');
      }
    });
    return out;
  }

  /// A single line suitable for a snackbar.
  String get displayMessage {
    final fields = fieldErrors;
    if (fields.isEmpty) return message;
    if (fields.length == 1 && (fields.containsKey('non_field_errors') || fields.containsKey('detail'))) {
      return fields.values.first;
    }
    return fields.entries.map((e) => e.key == 'non_field_errors' ? e.value : '${_label(e.key)}: ${e.value}').join('\n');
  }

  static String _label(String key) {
    final words = key.replaceAll('_', ' ');
    return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
