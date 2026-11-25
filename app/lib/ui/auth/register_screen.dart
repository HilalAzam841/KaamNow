import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../widgets/language_button.dart';
import '../../l10n/l10n.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.referralCode});

  /// From an invite link (`/register?ref=CODE`).
  final String? referralCode;
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
  late final _referral = TextEditingController(text: widget.referralCode ?? '');
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
            referralCode: _role == UserRole.customer ? _referral.text : null,
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
        title: Text(context.t.createAccount),
        actions: const [LanguageButton()],
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
                Text(context.t.iWantTo, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: [
                    ButtonSegment(value: UserRole.customer, label: Text(context.t.hireHelp), icon: Icon(Icons.person)),
                    ButtonSegment(value: UserRole.worker, label: Text(context.t.offerServices), icon: Icon(Icons.handyman)),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('reg-name'),
                  controller: _name,
                  decoration: InputDecoration(labelText: context.t.fullName),
                  validator: (v) => (v ?? '').trim().length < 3 ? context.t.enterFullName : _server('full_name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('reg-phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: context.t.phoneNumber, hintText: '03XX XXXXXXX'),
                  validator: (v) => (v ?? '').trim().length < 10 ? context.t.enterValidPhone : _server('phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('reg-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: context.t.emailOptional),
                  validator: (_) => _server('email'),
                ),
                if (_role == UserRole.worker) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('reg-cnic'),
                    controller: _cnic,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: context.t.cnicNumber, hintText: '35202-1234567-1'),
                    validator: (v) => (v ?? '').trim().length < 13 ? context.t.enterCnic : _server('cnic_number'),
                  ),
                ],
                if (_role == UserRole.customer) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('reg-referral'),
                    controller: _referral,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                        labelText: context.t.inviteCodeOptional, helperText: context.t.inviteCodeHint, helperMaxLines: 2),
                    validator: (_) => _server('referral_code'),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('reg-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: context.t.password, helperText: context.t.atLeast8),
                  validator: (v) => (v ?? '').length < 8 ? context.t.useAtLeast8 : _server('password'),
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
                      : Text(context.t.createAccount),
                ),
                if (_role == UserRole.worker) ...[
                  const SizedBox(height: 12),
                  Text(context.t.workerSignupHint,
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
