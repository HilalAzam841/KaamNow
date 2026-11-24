import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';

class _Tab {
  const _Tab(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _customerTabs = [
  _Tab('/', 'Home', Icons.home_rounded),
  _Tab('/requests', 'My requests', Icons.assignment_rounded),
  _Tab('/bookings', 'Bookings', Icons.event_available_rounded),
  _Tab('/notifications', 'Alerts', Icons.notifications_rounded),
  _Tab('/account', 'Account', Icons.person_rounded),
];

const _workerTabs = [
  _Tab('/jobs', 'Jobs', Icons.work_rounded),
  _Tab('/offers', 'My offers', Icons.local_offer_rounded),
  _Tab('/bookings', 'Bookings', Icons.event_available_rounded),
  _Tab('/notifications', 'Alerts', Icons.notifications_rounded),
  _Tab('/account', 'Account', Icons.person_rounded),
];

/// Bottom navigation on phones, a side rail on wide screens. Polls the unread badge.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final n = await context.read<Session>().api.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user;
    final tabs = user?.isWorker == true ? _workerTabs : _customerTabs;
    var index = tabs.indexWhere((t) => t.path != '/' && widget.location.startsWith(t.path));
    if (index < 0) index = 0;

    Widget icon(_Tab t) => t.path == '/notifications' && _unread > 0
        ? Badge(label: Text('$_unread'), child: Icon(t.icon))
        : Icon(t.icon);

    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.handyman_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
            ),
            destinations: [for (final t in tabs) NavigationRailDestination(icon: icon(t), label: Text(t.label))],
            onDestinationSelected: (i) => context.go(tabs[i].path),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ]),
      );
    }
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: [for (final t in tabs) NavigationDestination(icon: icon(t), label: t.label)],
        onDestinationSelected: (i) => context.go(tabs[i].path),
      ),
    );
  }
}
