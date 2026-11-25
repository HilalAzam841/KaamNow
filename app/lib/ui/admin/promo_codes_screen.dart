import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/session.dart';
import '../../models/admin_models.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// Promo codes customers type when paying. KaamNow pays the discount; workers get their full share.
class AdminPromoCodesScreen extends StatefulWidget {
  const AdminPromoCodesScreen({super.key});
  @override
  State<AdminPromoCodesScreen> createState() => _AdminPromoCodesScreenState();
}

class _AdminPromoCodesScreenState extends State<AdminPromoCodesScreen> {
  String? _view = 'true';
  final _list = GlobalKey<PagedListState<AdminPromoCode>>();

  Future<void> _edit([AdminPromoCode? p]) async {
    final categories = await context.read<Session>().api.categories().catchError((_) => <ServiceCategory>[]);
    if (!mounted) return;
    final body = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PromoDialog(promo: p, categories: categories),
    );
    if (body == null || !mounted) return;
    final api = adminApi(context);
    final r = await runAction(
      context,
      () => p == null ? api.createPromoCode(body) : api.updatePromoCode(p.id, body),
      success: p == null ? 'Promo code created.' : 'Promo code saved.',
    );
    if (r != null) _list.currentState?.reload();
  }

  Future<void> _toggle(AdminPromoCode p, VoidCallback reload) async {
    final r = await runAction(context, () => adminApi(context).updatePromoCode(p.id, {'is_active': !p.isActive}),
        success: p.isActive ? 'Promo code switched off.' : 'Promo code switched on.');
    if (r != null) reload();
  }

  String _offer(AdminPromoCode p) => p.isPercent
      ? '${double.parse(p.value).toStringAsFixed(0)}% off${p.maxDiscount != null ? ' (up to ${rs(p.maxDiscount)})' : ''}'
      : '${rs(p.value)} off';

  Widget _tile(AdminPromoCode p, VoidCallback reload) {
    final theme = Theme.of(context);
    final rules = [
      if ((double.tryParse(p.minOrder) ?? 0) > 0) 'min ${rs(p.minOrder)}',
      if (p.categoryName != null) p.categoryName!,
      if (p.firstBookingOnly) 'first booking only',
      if (p.maxUses != null) '${p.maxUses} uses in total',
      '${p.maxUsesPerUser} per customer',
      if (p.startsAt != null) 'from ${day(p.startsAt)}',
      if (p.endsAt != null) 'until ${day(p.endsAt)}',
    ];
    return Card(
      key: Key('promo-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${p.code} · ${_offer(p)}', style: theme.textTheme.titleMedium)),
                StatusChip(p.isActive ? 'active' : 'cancelled', label: p.isActive ? 'On' : 'Off'),
              ],
            ),
            if (p.description.isNotEmpty) Text(p.description),
            Text(rules.join(' · '), style: theme.textTheme.bodySmall),
            Text('Used ${p.uses} times · ${rs(p.discountGiven)} given', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton(key: Key('edit-promo-${p.id}'), onPressed: () => _edit(p), child: const Text('Edit')),
              TextButton(
                key: Key('toggle-promo-${p.id}'),
                onPressed: () => _toggle(p, reload),
                child: Text(p.isActive ? 'Switch off' : 'Switch on'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Promo codes',
    actions: [
      FilledButton.icon(
        key: const Key('new-promo'),
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New code'),
      ),
    ],
    body: Column(
      children: [
        FilterChips(
          options: const [('true', 'On'), ('false', 'Off'), (null, 'All')],
          selected: _view,
          onSelected: (v) {
            setState(() => _view = v);
            WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
          },
        ),
        Expanded(
          child: PagedList<AdminPromoCode>(
            key: _list,
            empty: 'No promo codes',
            load: (page) => adminApi(context).promoCodes(active: _view == null ? null : _view == 'true', page: page),
            itemBuilder: (context, p, reload) => _tile(p, reload),
          ),
        ),
      ],
    ),
  );
}

class _PromoDialog extends StatefulWidget {
  const _PromoDialog({this.promo, required this.categories});
  final AdminPromoCode? promo;
  final List<ServiceCategory> categories;
  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final _form = GlobalKey<FormState>();
  late final p = widget.promo;
  late final _code = TextEditingController(text: p?.code ?? '');
  late final _description = TextEditingController(text: p?.description ?? '');
  late String _kind = p?.kind ?? 'percent';
  late final _value = TextEditingController(text: p?.value ?? '');
  late final _maxDiscount = TextEditingController(text: p?.maxDiscount ?? '');
  late final _minOrder = TextEditingController(text: p == null ? '' : p!.minOrder);
  late final _maxUses = TextEditingController(text: p?.maxUses?.toString() ?? '');
  late final _perUser = TextEditingController(text: (p?.maxUsesPerUser ?? 1).toString());
  late int? _category = p?.categoryId;
  late bool _firstOnly = p?.firstBookingOnly ?? false;
  late DateTime? _ends = p?.endsAt;

  @override
  void dispose() {
    for (final c in [_code, _description, _value, _maxDiscount, _minOrder, _maxUses, _perUser]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _amount(String? v, {bool required = false, double? max}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return required ? 'Required' : null;
    final n = double.tryParse(s);
    if (n == null || n <= 0) return 'Enter a positive number';
    if (max != null && n > max) return 'At most ${max.toStringAsFixed(0)}';
    return null;
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _ends ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _ends = DateTime(d.year, d.month, d.day, 23, 59));
  }

  @override
  Widget build(BuildContext context) {
    final percent = _kind == 'percent';
    String? orNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return AlertDialog(
      title: Text(p == null ? 'New promo code' : 'Edit ${p!.code}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: const Key('promo-code-field'),
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code', hintText: 'EID20'),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 letters or digits' : null,
                ),
                TextFormField(
                  key: const Key('promo-description'),
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description shown to customers (optional)'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'percent', label: Text('Percent off')),
                    ButtonSegment(value: 'fixed', label: Text('Rupees off')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
                TextFormField(
                  key: const Key('promo-value'),
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: percent ? 'Percent' : 'Rupees'),
                  validator: (v) => _amount(v, required: true, max: percent ? 100 : null),
                ),
                if (percent)
                  TextFormField(
                    key: const Key('promo-max-discount'),
                    controller: _maxDiscount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Most it can take off (Rs, optional)'),
                    validator: _amount,
                  ),
                TextFormField(
                  key: const Key('promo-min-order'),
                  controller: _minOrder,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Smallest booking (Rs, optional)'),
                  validator: _amount,
                ),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All services')),
                    for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('promo-max-uses'),
                      controller: _maxUses,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total uses (optional)'),
                      validator: _amount,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: const Key('promo-per-user'),
                      controller: _perUser,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Uses per customer'),
                      validator: (v) => _amount(v, required: true),
                    ),
                  ),
                ]),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _firstOnly,
                  onChanged: (v) => setState(() => _firstOnly = v ?? false),
                  title: const Text('First booking only'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_ends == null ? 'No end date' : 'Ends ${day(_ends)}'),
                  trailing: Wrap(children: [
                    if (_ends != null) TextButton(onPressed: () => setState(() => _ends = null), child: const Text('Clear')),
                    TextButton(key: const Key('promo-end'), onPressed: _pickEnd, child: const Text('Pick date')),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(
          key: const Key('dialog-ok'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, <String, dynamic>{
              'code': _code.text.trim().toUpperCase(),
              'description': _description.text.trim(),
              'kind': _kind,
              'value': _value.text.trim(),
              'max_discount': percent ? orNull(_maxDiscount) : null,
              'min_order': orNull(_minOrder) ?? '0',
              'category': _category,
              'max_uses': int.tryParse(_maxUses.text.trim()),
              'max_uses_per_user': int.tryParse(_perUser.text.trim()) ?? 1,
              'first_booking_only': _firstOnly,
              'ends_at': _ends?.toUtc().toIso8601String(),
            });
          },
          child: Text(p == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
