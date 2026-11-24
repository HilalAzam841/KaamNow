import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';
import '../widgets/language_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().login(_phone.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = e.displayMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    return Scaffold(
      appBar: AppBar(actions: const [LanguageButton()], backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Icon(Icons.handyman_rounded, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(t.appName, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                  Text(t.tagline, textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('login-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: t.phoneNumber, hintText: '03XX XXXXXXX',
                        prefixIcon: const Icon(Icons.phone)),
                    validator: (v) => (v ?? '').trim().length < 10 ? t.enterPhone : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('login-password'),
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: t.password,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v ?? '').isEmpty ? t.enterPassword : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, key: const Key('login-error'), style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('login-submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.logIn),
                  ),
                  TextButton(
                      key: const Key('login-forgot'),
                      onPressed: () => context.go('/forgot-password'),
                      child: Text(t.forgotPassword)),
                  const Divider(height: 32),
                  OutlinedButton(
                    onPressed: () => context.go('/register'),
                    child: Text(t.createAnAccount),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
