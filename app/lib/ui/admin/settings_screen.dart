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
  late final _reward = TextEditingController(text: widget.settings.referralReward);
  late final _welcome = TextEditingController(text: widget.settings.referralWelcomeCredit);
  late final _minBooking = TextEditingController(text: widget.settings.referralMinBooking);
  late final _maxDiscount = TextEditingController(text: widget.settings.maxDiscountPercent);
  bool _saving = false;

  String? _number(String? v, {double max = 1e9}) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null || n < 0 || n > max) return max <= 100 ? 'Enter 0 to ${max.toInt()}' : 'Enter a positive amount';
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
      if (_reward.text.trim() != s.referralReward) 'referral_reward': _reward.text.trim(),
      if (_welcome.text.trim() != s.referralWelcomeCredit) 'referral_welcome_credit': _welcome.text.trim(),
      if (_minBooking.text.trim() != s.referralMinBooking) 'referral_min_booking': _minBooking.text.trim(),
      if (_maxDiscount.text.trim() != s.maxDiscountPercent) 'max_discount_percent': _maxDiscount.text.trim(),
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
              const SizedBox(height: 24),
              Text('Invites and discounts', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('referral-reward'),
                controller: _reward,
                decoration: const InputDecoration(labelText: 'Invite reward (Rs)', helperText: 'Given to the inviter when their friend pays a first booking. 0 = off', helperMaxLines: 2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('referral-welcome'),
                controller: _welcome,
                decoration: const InputDecoration(labelText: 'Welcome credit (Rs)', helperText: 'Credit a new customer gets for signing up with an invite code', helperMaxLines: 2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('referral-min-booking'),
                controller: _minBooking,
                decoration: const InputDecoration(labelText: 'Smallest first booking for a reward (Rs)', helperText: 'The first booking of the invited friend must be at least this much', helperMaxLines: 2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('max-discount'),
                controller: _maxDiscount,
                decoration: const InputDecoration(labelText: 'Largest discount (% of a booking)', helperText: 'Promo codes and credit together never take off more than this', helperMaxLines: 2),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => _number(v, max: 90),
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
