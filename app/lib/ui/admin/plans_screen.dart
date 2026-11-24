import 'package:material_ui/material_ui.dart';

import '../../api/admin_api.dart';
import '../../core/format.dart';
import '../../models/admin_models.dart';
import '../../models/models.dart';
import '../widgets/common.dart';
import 'admin_common.dart';
import 'admin_shell.dart';

/// Subscription plans, featured-listing plans, and the purchases made with them.
class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});
  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AdminPage(
        title: 'Plans',
        body: Column(children: [
          const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Subscription plans'),
            Tab(text: 'Featured plans'),
            Tab(text: 'Subscriptions'),
            Tab(text: 'Featured listings'),
          ]),
          Expanded(
            child: TabBarView(children: [
              _SubscriptionPlansTab(api: adminApi(context)),
              _FeaturedPlansTab(api: adminApi(context)),
              _SubscriptionsTab(api: adminApi(context)),
              _FeaturedListingsTab(api: adminApi(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A small form dialog: label -> initial value. Returns the edited values or null.
Future<Map<String, String>?> editFields(BuildContext context, String title, Map<String, String> fields,
    {Map<String, bool> switches = const {}, ValueChanged<Map<String, bool>>? onSwitches}) {
  final ctrls = {for (final e in fields.entries) e.key: TextEditingController(text: e.value)};
  final sw = Map<String, bool>.from(switches);
  return showDialog<Map<String, String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final e in ctrls.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(key: Key('field-${e.key}'), controller: e.value, decoration: InputDecoration(labelText: e.key)),
                ),
              for (final k in sw.keys)
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(k), value: sw[k]!, onChanged: (v) => setState(() => sw[k] = v)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            key: const Key('save-fields'),
            onPressed: () {
              onSwitches?.call(sw);
              Navigator.pop(c, {for (final e in ctrls.entries) e.key: e.value.text.trim()});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _SubscriptionPlansTab extends StatelessWidget {
  const _SubscriptionPlansTab({required this.api});
  final AdminApi api;

  Future<void> _edit(BuildContext context, SubscriptionPlan? p, Future<void> Function() reload) async {
    var switches = <String, bool>{};
    final v = await editFields(
      context,
      p == null ? 'New subscription plan' : 'Edit ${p.name}',
      {
        'Name': p?.name ?? '',
        if (p == null) 'Slug': '',
        'Price (Rs)': p?.price ?? '0',
        'Duration (days)': '${p?.durationDays ?? 30}',
        'Commission % (blank = platform rate)': p?.commissionPercent ?? '',
        'Daily offer limit (blank = unlimited)': p?.dailyOfferLimit?.toString() ?? '',
        'Badge': p?.badge ?? '',
        'Description': p?.description ?? '',
      },
      switches: {'Active': p?.isActive ?? true},
      onSwitches: (s) => switches = s,
    );
    if (v == null || !context.mounted) return;
    final body = <String, dynamic>{
      'name': v['Name'],
      if (p == null) 'slug': v['Slug'],
      'price': v['Price (Rs)'],
      'duration_days': int.tryParse(v['Duration (days)'] ?? '') ?? 30,
      'commission_percent': (v['Commission % (blank = platform rate)'] ?? '').isEmpty ? null : v['Commission % (blank = platform rate)'],
      'daily_offer_limit': int.tryParse(v['Daily offer limit (blank = unlimited)'] ?? ''),
      'badge': v['Badge'],
      'description': v['Description'],
      'is_active': switches['Active'] ?? true,
    };
    await runAction(context, () => p == null ? api.createSubscriptionPlan(body) : api.updateSubscriptionPlan(p.id, body),
        success: 'Plan saved.');
    await reload();
  }

  @override
  Widget build(BuildContext context) => Loader<List<SubscriptionPlan>>(
        load: api.subscriptionPlans,
        builder: (context, plans, reload) => ListView(padding: const EdgeInsets.all(12), children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(onPressed: () => _edit(context, null, reload), icon: const Icon(Icons.add), label: const Text('New plan')),
          ),
          for (final p in plans)
            Card(
              child: ListTile(
                key: Key('plan-${p.id}'),
                title: Text('${p.name}${p.isDefault ? ' (default)' : ''}${p.isActive ? '' : ' · inactive'}'),
                subtitle: Text('${(double.tryParse(p.price) ?? 0) == 0 ? 'Free' : '${rs(p.price)} / ${p.durationDays} days'} · '
                    'commission ${p.commissionPercent == null ? 'platform rate' : '${p.commissionPercent}%'} · '
                    '${p.dailyOfferLimit == null ? 'unlimited offers' : '${p.dailyOfferLimit} offers/day'}'),
                trailing: IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _edit(context, p, reload)),
              ),
            ),
        ]),
      );
}

class _FeaturedPlansTab extends StatelessWidget {
  const _FeaturedPlansTab({required this.api});
  final AdminApi api;

  Future<void> _edit(BuildContext context, FeaturedPlan? p, Future<void> Function() reload) async {
    var switches = <String, bool>{};
    final v = await editFields(
      context,
      p == null ? 'New featured plan' : 'Edit ${p.name}',
      {'Name': p?.name ?? '', 'Duration (days)': '${p?.durationDays ?? 7}', 'Price (Rs)': p?.price ?? ''},
      switches: {'Active': p?.isActive ?? true},
      onSwitches: (s) => switches = s,
    );
    if (v == null || !context.mounted) return;
    final body = {
      'name': v['Name'],
      'duration_days': int.tryParse(v['Duration (days)'] ?? '') ?? 7,
      'price': v['Price (Rs)'],
      'is_active': switches['Active'] ?? true,
    };
    await runAction(context, () => p == null ? api.createFeaturedPlan(body) : api.updateFeaturedPlan(p.id, body),
        success: 'Plan saved.');
    await reload();
  }

  @override
  Widget build(BuildContext context) => Loader<List<FeaturedPlan>>(
        load: api.featuredPlans,
        builder: (context, plans, reload) => ListView(padding: const EdgeInsets.all(12), children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(onPressed: () => _edit(context, null, reload), icon: const Icon(Icons.add), label: const Text('New plan')),
          ),
          for (final p in plans)
            Card(
              child: ListTile(
                title: Text('${p.name}${p.isActive ? '' : ' · inactive'}'),
                subtitle: Text('${rs(p.price)} for ${p.durationDays} days at the top of category search'),
                trailing: IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _edit(context, p, reload)),
              ),
            ),
        ]),
      );
}

class _SubscriptionsTab extends StatefulWidget {
  const _SubscriptionsTab({required this.api});
  final AdminApi api;
  @override
  State<_SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends State<_SubscriptionsTab> {
  String? _status;
  final _list = GlobalKey<PagedListState<AdminSubscription>>();

  @override
  Widget build(BuildContext context) => Column(children: [
        FilterChips(
          options: const [(null, 'All'), ('active', 'Active'), ('pending_payment', 'Awaiting payment'), ('expired', 'Expired')],
          selected: _status,
          onSelected: (v) {
            setState(() => _status = v);
            WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
          },
        ),
        Expanded(
          child: PagedList<AdminSubscription>(
            key: _list,
            empty: 'No subscriptions',
            load: (page) => widget.api.subscriptions(status: _status, page: page),
            itemBuilder: (context, s, reload) => Card(
              child: ListTile(
                title: Text('${s.workerName} · ${s.planName}'),
                subtitle: Text('${rs(s.amount)}${s.paymentMethod.isNotEmpty ? ' via ${humanize(s.paymentMethod)}' : ''}'
                    '${s.endsAt != null ? ' · until ${day(s.endsAt)}' : ''}'),
                trailing: s.status == 'pending_payment'
                    ? OutlinedButton(
                        onPressed: () async {
                          if (!await confirm(context, 'Activate without online payment?',
                              'Use this when ${s.workerName} paid KaamNow directly. It is recorded in the audit log.',
                              ok: 'Activate')) {
                            return;
                          }
                          if (!context.mounted) return;
                          await runAction(context, () => widget.api.activateSubscription(s.id), success: 'Subscription activated.');
                          reload();
                        },
                        child: const Text('Activate'),
                      )
                    : StatusChip(s.status),
              ),
            ),
          ),
        ),
      ]);
}

class _FeaturedListingsTab extends StatefulWidget {
  const _FeaturedListingsTab({required this.api});
  final AdminApi api;
  @override
  State<_FeaturedListingsTab> createState() => _FeaturedListingsTabState();
}

class _FeaturedListingsTabState extends State<_FeaturedListingsTab> {
  String? _status = 'active';
  final _list = GlobalKey<PagedListState<AdminFeaturedListing>>();

  @override
  Widget build(BuildContext context) => Column(children: [
        FilterChips(
          options: const [('active', 'Active'), ('pending_payment', 'Awaiting payment'), (null, 'All')],
          selected: _status,
          onSelected: (v) {
            setState(() => _status = v);
            WidgetsBinding.instance.addPostFrameCallback((_) => _list.currentState?.reload());
          },
        ),
        Expanded(
          child: PagedList<AdminFeaturedListing>(
            key: _list,
            empty: 'No featured listings',
            load: (page) => widget.api.featuredListings(status: _status, page: page),
            itemBuilder: (context, f, reload) => Card(
              child: ListTile(
                title: Text('${f.workerName} · ${f.categoryName}'),
                subtitle: Text('${f.planName} · ${rs(f.amount)}${f.endsAt != null ? ' · until ${day(f.endsAt)}' : ''}'),
                trailing: f.status == 'active'
                    ? TextButton(
                        onPressed: () async {
                          final reason = await promptText(context, 'Cancel this listing?', label: 'Reason', ok: 'Cancel listing', required: true);
                          if (reason == null || !context.mounted) return;
                          await runAction(context, () => widget.api.cancelFeaturedListing(f.id, reason), success: 'Listing cancelled.');
                          reload();
                        },
                        child: const Text('Cancel'),
                      )
                    : StatusChip(f.status),
              ),
            ),
          ),
        ),
      ]);
}
