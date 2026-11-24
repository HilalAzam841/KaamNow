import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'token_store.dart';

class UploadFile {
  UploadFile({required this.field, required this.filename, required this.bytes});
  final String field;
  final String filename;
  final Uint8List bytes;
}

/// Low-level HTTP client for the KaamNow API.
///
/// * Unwraps the `{success, data, message}` envelope and returns `data`.
/// * Turns `{success: false, error: {...}}` into an [ApiException].
/// * Sends the access token and, on a 401, refreshes it once (single flight) and retries.
class ApiClient {
  ApiClient({required this.root, required this.tokens, http.Client? httpClient, this.onSessionExpired})
    : _http = httpClient ?? http.Client();

  final String root; // e.g. http://localhost:8000/api/v1
  final TokenStore tokens;
  final http.Client _http;
  void Function()? onSessionExpired;
  Future<bool>? _refreshing;

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final clean = path.startsWith('/') ? path : '/$path';
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    final u = Uri.parse('$root$clean');
    return q.isEmpty ? u : u.replace(queryParameters: q);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => http.Request('GET', uri(path, query)));

  /// Downloads a binary file (e.g. a private document). Returns the bytes and content type.
  Future<(Uint8List, String)> getBytes(String path) async {
    final res = await _sendRaw(() => http.Request('GET', uri(path)));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (res.bodyBytes, res.headers['content-type'] ?? 'application/octet-stream');
    }
    _decode(res); // throws the API error
    throw ApiException(statusCode: res.statusCode, code: 'download_failed', message: 'Download failed.');
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send(() => _json('POST', path, body), auth: auth);

  Future<dynamic> patch(String path, {Object? body}) => _send(() => _json('PATCH', path, body));

  Future<dynamic> delete(String path, {Object? body}) => _send(() => _json('DELETE', path, body));

  Future<dynamic> multipart(String method, String path,
      {Map<String, String> fields = const {}, List<UploadFile> files = const []}) {
    return _send(() {
      final req = http.MultipartRequest(method, uri(path));
      req.fields.addAll(fields);
      for (final f in files) {
        req.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.filename));
      }
      return req;
    });
  }

  http.Request _json(String method, String path, Object? body) {
    final req = http.Request(method, uri(path));
    req.headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    return req;
  }

  Future<dynamic> _send(http.BaseRequest Function() build, {bool auth = true}) async =>
      _decode(await _sendRaw(build, auth: auth));

  Future<http.Response> _sendRaw(http.BaseRequest Function() build, {bool auth = true, bool retried = false}) async {
    final req = build();
    req.headers['Accept'] = 'application/json';
    final access = tokens.access;
    if (auth && access != null) req.headers['Authorization'] = 'Bearer $access';

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req));
    } catch (e) {
      throw ApiException.network(e);
    }

    if (res.statusCode == 401 && auth && access != null && !retried) {
      if (await _refreshTokens()) return _sendRaw(build, auth: auth, retried: true);
      await tokens.clear();
      onSessionExpired?.call();
    }
    return res;
  }

  Future<bool> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = tokens.refresh;
    if (refresh == null) return false;
    try {
      final res = await _http.post(
        uri('/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );
      if (res.statusCode != 200) return false;
      final data = _decode(res) as Map<String, dynamic>;
      await tokens.save(access: data['access'] as String, refresh: data['refresh'] as String?);
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        body = null;
      }
    }
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      if (body is Map && body.containsKey('success')) return body['data'];
      return body;
    }
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      throw ApiException(
        statusCode: res.statusCode,
        code: '${err['code'] ?? 'error'}',
        message: '${err['message'] ?? 'Something went wrong.'}',
        details: err['details'],
      );
    }
    throw ApiException(
      statusCode: res.statusCode,
      code: 'http_${res.statusCode}',
      message: res.statusCode >= 500 ? 'KaamNow is having trouble right now. Please try again.' : 'Request failed.',
    );
  }
}
