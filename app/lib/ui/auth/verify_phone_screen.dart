import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../widgets/language_button.dart';

/// Shown after sign-in until the phone number is confirmed with an SMS code (when the server
/// requires it). The router keeps the user here until then.
class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});
  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wait = await context.read<Session>().api.sendPhoneCode();
      if (!mounted) return;
      setState(() => _sent = true);
      _countdown(wait > 0 ? wait : 60);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) {
      setState(() => _error = context.t.enterTheCode);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    final messenger = ScaffoldMessenger.of(context);
    final done = context.t.numberConfirmed;
    try {
      final user = await session.api.verifyPhone(code);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      session.setUser(user); // the router now moves on to the home screen
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final session = context.watch<Session>();
    final phone = ltr(session.user?.phone ?? '');
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()], backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.sms_outlined, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(t.confirmYourNumber, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_sent ? t.codeSentTo(phone) : t.confirmNumberHint(phone), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (!_sent)
                  FilledButton(
                    key: const Key('verify-send'),
                    onPressed: _busy ? null : _send,
                    child: Text(t.sendCode),
                  )
                else ...[
                  TextField(
                    key: const Key('verify-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
                    decoration: InputDecoration(labelText: t.smsCode, counterText: ''),
                    onSubmitted: (_) => _confirm(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('verify-confirm'),
                    onPressed: _busy ? null : _confirm,
                    child: Text(t.confirmAction),
                  ),
                  TextButton(
                    key: const Key('verify-resend'),
                    onPressed: _busy || _wait > 0 ? null : _send,
                    child: Text(_wait > 0 ? t.resendIn(_wait) : t.sendNewCode),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('verify-error'), style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
                ],
                const Divider(height: 40),
                TextButton(
                  key: const Key('verify-logout'),
                  onPressed: () => session.logout(),
                  child: Text(t.wrongNumberLogOut),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
