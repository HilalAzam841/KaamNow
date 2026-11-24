import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/session.dart';

/// Opened from the link in the password-reset email: `/#/reset-password?uid=...&token=...`.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.uid, required this.token});
  final String uid;
  final String token;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  bool get _linkValid => widget.uid.isNotEmpty && widget.token.isNotEmpty;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api.confirmPasswordReset(widget.uid, widget.token, _password.text);
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = context.watch<Session>().isSignedIn;
    final Widget body;
    if (!_linkValid) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('This reset link is incomplete', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Open the link from the email again, or ask for a new one from the login screen.'),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => context.go(signedIn ? '/' : '/login'), child: const Text('Back')),
      ]);
    } else if (_done) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.check_circle, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text('Password changed', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('You can log in with your new password now.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('reset-done'),
          onPressed: () => context.go(signedIn ? '/' : '/login'),
          child: Text(signedIn ? 'Continue' : 'Log in'),
        ),
      ]);
    } else {
      body = Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Choose a new password', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('reset-password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
            validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('reset-confirm'),
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Repeat new password'),
            validator: (v) => v != _password.text ? 'The passwords do not match' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('reset-submit'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Saving…' : 'Save new password'),
          ),
        ]),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: body),
          ),
        ),
      ),
    );
  }
}
