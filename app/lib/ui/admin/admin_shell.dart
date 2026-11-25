import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const adminDestinations = [
  _Dest('/admin', 'Overview', Icons.dashboard_rounded),
  _Dest('/admin/workers', 'Verification', Icons.verified_user_rounded),
  _Dest('/admin/users', 'Users', Icons.people_rounded),
  _Dest('/admin/bookings', 'Jobs', Icons.event_note_rounded),
  _Dest('/admin/revenue', 'Revenue', Icons.payments_rounded),
  _Dest('/admin/payments', 'Payments', Icons.receipt_long_rounded),
  _Dest('/admin/payouts', 'Payouts', Icons.account_balance_wallet_rounded),
  _Dest('/admin/promo-codes', 'Promo codes', Icons.local_offer_rounded),
  _Dest('/admin/plans', 'Plans', Icons.workspace_premium_rounded),
  _Dest('/admin/complaints', 'Complaints', Icons.support_agent_rounded),
  _Dest('/admin/settings', 'Settings', Icons.tune_rounded),
  _Dest('/admin/audit', 'Audit log', Icons.history_rounded),
];

/// Admin layout: a side rail on desktop, a drawer on narrow screens.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  int get _index {
    var best = 0;
    for (var i = 0; i < adminDestinations.length; i++) {
      final p = adminDestinations[i].path;
      if (location == p || (p != '/admin' && location.startsWith(p))) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final theme = Theme.of(context);
    void go(int i) => context.go(adminDestinations[i].path);

    final logout = IconButton(
      key: const Key('admin-logout'),
      tooltip: 'Log out ${session.user?.fullName ?? ''}',
      icon: const Icon(Icons.logout),
      onPressed: session.logout,
    );

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            extended: true,
            minExtendedWidth: 200,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              child: Row(children: [
                Icon(Icons.handyman_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('KaamNow Admin', style: theme.textTheme.titleMedium),
              ]),
            ),
            trailing: Expanded(child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(12), child: logout))),
            destinations: [
              for (final d in adminDestinations) NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
            onDestinationSelected: go,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(adminDestinations[_index].label), actions: [logout]),
      drawer: NavigationDrawer(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          Navigator.pop(context);
          go(i);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text('KaamNow Admin', style: theme.textTheme.titleMedium),
          ),
          for (final d in adminDestinations) NavigationDrawerDestination(icon: Icon(d.icon), label: Text(d.label)),
        ],
      ),
      body: child,
    );
  }
}

/// Page header used inside the admin shell.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.title, required this.body, this.actions = const []});
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (wide)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall)),
            ...actions,
          ]),
        )
      else if (actions.isNotEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions)),
      Expanded(child: body),
    ]);
  }
}
