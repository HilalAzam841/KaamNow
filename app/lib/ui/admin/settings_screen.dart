import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminPage(
        title: 'Platform settings',
        body: Loader<PlatformSettings>(
          load: adminApi(context).settings,
          builder: (context, s, reload) => _SettingsForm(key: ValueKey(s.updatedAt), settings: s, onSaved: reload),
        ),
      );
}

class _SettingsForm extends StatefulWidget {
  const _SettingsForm({super.key, required this.settings, required this.onSaved});
  final PlatformSettings settings;
  final Future<void> Function() onSaved;
  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _form = GlobalKey<FormState>();
  late final _commission = TextEditingController(text: widget.settings.commissionPercent);
  late final _fee = TextEditingController(text: widget.settings.emergencyFee);
  late bool _emergency = widget.settings.emergencyEnabled;
  late final _minPayout = TextEditingController(text: widget.settings.minPayout);
  late final _debtLimit = TextEditingController(text: widget.settings.commissionDebtLimit);
  bool _saving = false;

  String? _number(String? v, {double max = 1e9}) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null || n < 0 || n > max) return max == 100 ? 'Enter 0 to 100' : 'Enter a positive amount';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = widget.settings;
    final changes = <String, dynamic>{
      if (_commission.text.trim() != s.commissionPercent) 'commission_percent': _commission.text.trim(),
      if (_fee.text.trim() != s.emergencyFee) 'emergency_fee': _fee.text.trim(),
      if (_emergency != s.emergencyEnabled) 'emergency_enabled': _emergency,
      if (_minPayout.text.trim() != s.minPayout) 'min_payout': _minPayout.text.trim(),
      if (_debtLimit.text.trim() != s.commissionDebtLimit) 'commission_debt_limit': _debtLimit.text.trim(),
    };
    if (changes.isEmpty) return;
    if (changes.containsKey('commission_percent') &&
        !await confirm(context, 'Change commission?',
            'New bookings will be charged ${_commission.text.trim()}% instead of ${s.commissionPercent}%. '
                'Existing bookings keep their rate. This is recorded in the audit log.',
            ok: 'Change')) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final r = await runAction(context, () => adminApi(context).updateSettings(changes), success: 'Settings saved.');
    if (mounted) setState(() => _saving = false);
    if (r != null) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                key: const Key('commission-percent'),
                controller: _commission,
                decoration: const InputDecoration(labelText: 'Commission %', helperText: 'Taken from each completed booking'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => _number(v, max: 100),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('emergency-fee'),
                controller: _fee,
                decoration: const InputDecoration(labelText: 'Emergency fee (Rs)', helperText: 'Added to urgent jobs'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Emergency jobs enabled'),
                value: _emergency,
                onChanged: (v) => setState(() => _emergency = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('min-payout'),
                controller: _minPayout,
                decoration: const InputDecoration(
                    labelText: 'Minimum payout (Rs)', helperText: 'Smallest balance a worker can ask to be paid'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('commission-debt-limit'),
                controller: _debtLimit,
                decoration: const InputDecoration(
                    labelText: 'Commission debt limit (Rs)',
                    helperText: 'Workers who owe more cash commission cannot send offers until they pay. 0 = no limit'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-settings'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
              if (widget.settings.updatedAt != null) ...[
                const SizedBox(height: 12),
                Text('Last changed ${when(widget.settings.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ]),
            ),
          ),
        ]),
      );
}
