import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../widgets/language_button.dart';

enum _Step { phone, code, emailOnly, done }

/// "Forgot password": a code by SMS, then a new password. Where the server cannot send SMS, it
/// emails a reset link instead (to accounts that have an email address).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialPhone = ''});
  final String initialPhone;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.initialPhone);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _step = _Step.phone;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) return;
    final api = context.read<Session>().api;
    await _run(() async {
      final sms = await api.requestPasswordReset(_phone.text.trim());
      if (mounted) setState(() => _step = sms ? _Step.code : _Step.emailOnly);
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    final api = context.read<Session>().api;
    await _run(() async {
      await api.resetPasswordWithCode(_phone.text.trim(), _code.text.trim(), _password.text);
      if (mounted) setState(() => _step = _Step.done);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final children = <Widget>[];
    switch (_step) {
      case _Step.phone:
        children.addAll([
          Text(t.forgotTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(t.forgotHint),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('forgot-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: t.yourPhoneNumber, hintText: '03XX XXXXXXX'),
            validator: (v) => (v ?? '').trim().length < 10 ? t.yourPhoneNumber : null,
            onFieldSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 20),
          FilledButton(key: const Key('forgot-send'), onPressed: _busy ? null : _sendCode, child: Text(t.sendCode)),
        ]);
      case _Step.code:
        children.addAll([
          Text(t.chooseNewPassword, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(t.forgotCodeHint(ltr(_phone.text.trim()))),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('forgot-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: t.smsCode),
            validator: (v) => RegExp(r'^\d{4,8}$').hasMatch((v ?? '').trim()) ? null : t.enterTheCode,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('forgot-password'),
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: t.newPassword),
            validator: (v) => (v ?? '').length < 8 ? t.useAtLeast8 : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('forgot-confirm'),
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(labelText: t.repeatNewPassword),
            validator: (v) => v != _password.text ? t.passwordsDontMatch : null,
            onFieldSubmitted: (_) => _reset(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('forgot-submit'),
            onPressed: _busy ? null : _reset,
            child: Text(_busy ? t.saving : t.saveNewPassword),
          ),
          TextButton(onPressed: _busy ? null : _sendCode, child: Text(t.sendNewCode)),
        ]);
      case _Step.emailOnly:
        children.addAll([
          Icon(Icons.mark_email_read_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(t.forgotEmailOnly, textAlign: TextAlign.center),
        ]);
      case _Step.done:
        children.addAll([
          Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(t.passwordChanged, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(t.loginWithNewPassword, textAlign: TextAlign.center),
        ]);
    }
    if (_error != null) {
      children.addAll([
        const SizedBox(height: 12),
        Text(_error!, key: const Key('forgot-error'), style: TextStyle(color: theme.colorScheme.error)),
      ]);
    }
    children.addAll([
      const SizedBox(height: 16),
      TextButton(key: const Key('forgot-back'), onPressed: () => context.go('/login'), child: Text(t.backToLogin)),
    ]);
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()], backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
            ),
          ),
        ),
      ),
    );
  }
}
