import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/session.dart';
import '../../models/models.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _cnic = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.customer;
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().register(
            phone: _phone.text,
            password: _password.text,
            fullName: _name.text,
            role: _role,
            email: _email.text.trim(),
            cnic: _role == UserRole.worker ? _cnic.text.trim() : null,
          );
    } on ApiException catch (e) {
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.displayMessage : null;
      });
      _form.currentState!.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _server(String field) => _fieldErrors[field];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('I want to', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(value: UserRole.customer, label: Text('Hire help'), icon: Icon(Icons.person)),
                    ButtonSegment(value: UserRole.worker, label: Text('Offer services'), icon: Icon(Icons.handyman)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('reg-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Enter your full name' : _server('full_name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('reg-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number', hintText: '03XX XXXXXXX'),
                  validator: (v) => (v ?? '').trim().length < 10 ? 'Enter a valid phone number' : _server('phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('reg-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (optional, for password reset)'),
                  validator: (_) => _server('email'),
                ),
                if (_role == UserRole.worker) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('reg-cnic'),
                    controller: _cnic,
                    decoration: const InputDecoration(labelText: 'CNIC number', hintText: '35202-1234567-1'),
                    validator: (v) => (v ?? '').trim().length < 13 ? 'Enter your CNIC number' : _server('cnic_number'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('reg-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'),
                  validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : _server('password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('reg-submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
                if (_role == UserRole.worker) ...[
                  const SizedBox(height: 12),
                  Text('After signing up, upload your CNIC so KaamNow can verify you before you send offers.',
                      style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
