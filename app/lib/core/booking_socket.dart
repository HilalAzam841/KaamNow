import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import 'token_store.dart';

class SocketEvent {
  SocketEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

/// Live channel for one booking: chat, worker location and status changes.
///
/// Reconnects with backoff. Everything it carries is also available over REST,
/// so screens reload from REST after a reconnect.
class BookingSocket {
  BookingSocket({required this.bookingId, required this.tokens, WebSocketChannel Function(Uri)? connector})
    : _connector = connector ?? WebSocketChannel.connect;

  final int bookingId;
  final TokenStore tokens;
  final WebSocketChannel Function(Uri) _connector;
  final _events = StreamController<SocketEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _retry;
  int _attempt = 0;
  bool _closed = false;
  bool connected = false;

  Stream<SocketEvent> get events => _events.stream;

  Uri get url => Uri.parse('${AppConfig.wsBaseUrl}/ws/bookings/$bookingId/')
      .replace(queryParameters: {'token': tokens.access ?? ''});

  void connect() {
    if (_closed) return;
    try {
      final channel = _connector(url);
      _channel = channel;
      _sub = channel.stream.listen(_onData, onDone: _onDone, onError: (_) => _onDone());
      channel.ready.then((_) {
        connected = true;
        _attempt = 0;
        _events.add(SocketEvent('socket.open', const {}));
        _ping?.cancel();
        _ping = Timer.periodic(const Duration(seconds: 25), (_) => send({'type': 'ping'}));
      }).catchError((_) => _onDone());
    } catch (_) {
      _onDone();
    }
  }

  void _onData(dynamic raw) {
    try {
      final m = jsonDecode(raw as String) as Map<String, dynamic>;
      final data = m['data'] is Map ? (m['data'] as Map).cast<String, dynamic>() : <String, dynamic>{...m}
        ..remove('type');
      _events.add(SocketEvent('${m['type']}', data));
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _onDone() {
    final wasConnected = connected;
    connected = false;
    _ping?.cancel();
    _sub?.cancel();
    if (wasConnected) _events.add(SocketEvent('socket.closed', const {}));
    final code = _channel?.closeCode;
    // 4401 = bad token, 4404 = not a participant: retrying will not help.
    if (_closed || code == 4401 || code == 4404) return;
    _attempt++;
    final delay = Duration(seconds: (1 << _attempt.clamp(0, 5)));
    _retry?.cancel();
    _retry = Timer(delay, connect);
  }

  bool send(Map<String, dynamic> message) {
    if (!connected || _channel == null) return false;
    _channel!.sink.add(jsonEncode(message));
    return true;
  }

  void close() {
    _closed = true;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}
