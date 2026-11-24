// Small helpers for tolerant JSON parsing.
DateTime? parseDate(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
double? parseDouble(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int parseInt(Object? v, [int fallback = 0]) => v is int ? v : int.tryParse('${v ?? ''}') ?? fallback;
String str(Object? v) => v == null ? '' : '$v';
List<T> parseList<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : <T>[];
Map<String, dynamic> asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// A page from a paginated endpoint. Accepts plain lists too.
class Paged<T> {
  Paged({required this.results, required this.count, this.next});

  factory Paged.parse(Object? data, T Function(Map<String, dynamic>) f) {
    if (data is List) return Paged(results: parseList(data, f), count: data.length);
    final m = asMap(data);
    final results = parseList(m['results'], f);
    return Paged(results: results, count: parseInt(m['count'], results.length), next: m['next'] as String?);
  }

  final List<T> results;
  final int count;
  final String? next;
  bool get hasMore => next != null;
}
