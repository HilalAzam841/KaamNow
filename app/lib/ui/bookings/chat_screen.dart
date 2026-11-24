import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/booking_socket.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import '../../l10n/l10n.dart';

/// Booking chat. Live over WebSocket, with REST for history and as a fallback for sending.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.bookingId});
  final int bookingId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final Session session = context.read<Session>();
  late final BookingSocket socket = BookingSocket(bookingId: widget.bookingId, tokens: session.tokens);
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<SocketEvent>? _sub;
  Object? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _sub = socket.events.listen(_onEvent);
    socket.connect();
    _loadHistory();
  }

  @override
  void dispose() {
    _sub?.cancel();
    socket.close();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await session.api.messages(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
        _error = null;
      });
      _toBottom();
      unawaited(session.api.markMessagesRead(widget.bookingId).catchError((_) {}));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _onEvent(SocketEvent e) {
    if (e.type == 'socket.open') {
      _loadHistory(); // catch up on anything missed while disconnected
    } else if (e.type == 'chat.message') {
      final m = ChatMessage.fromEvent(e.data, session.user!.id);
      if (_messages.any((x) => x.id == m.id)) return;
      setState(() => _messages.add(m));
      _toBottom();
      if (!m.isMine) socket.send({'type': 'chat.read'});
    } else if (e.type == 'error') {
      showInfo(context, '${e.data['message'] ?? context.t.messageNotSent}');
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    _input.clear();
    if (socket.send({'type': 'chat.message', 'body': body})) return;
    setState(() => _sending = true);
    final m = await runAction(context, () => session.api.sendMessage(widget.bookingId, body));
    if (mounted) {
      setState(() {
        _sending = false;
        if (m != null && !_messages.any((x) => x.id == m.id)) _messages.add(m);
      });
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.t.chat), actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: Tooltip(
            message: socket.connected ? context.t.live : context.t.reconnecting,
            child: Icon(Icons.circle, size: 10, color: socket.connected ? Colors.green : Colors.grey),
          ),
        ),
        const LanguageButton(),
      ]),
      body: PageBody(
        child: Column(children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? ErrorView(error: _error!, onRetry: _loadHistory)
                    : _messages.isEmpty
                        ? EmptyView(icon: Icons.chat_bubble_outline, title: context.t.noMessagesYet,
                            subtitle: context.t.messagesPrivate)
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[i];
                              return Align(
                                alignment: m.isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 480),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: m.isMine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text(m.body),
                                    Text(when(m.createdAt), style: theme.textTheme.labelSmall),
                                  ]),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: context.t.typeMessage, isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('chat-send'),
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
