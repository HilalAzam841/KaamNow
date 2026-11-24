import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/session.dart';
import 'ui/account/account_screen.dart';
import 'ui/admin/admin_shell.dart';
import 'ui/admin/audit_screen.dart';
import 'ui/admin/complaints_screen.dart' as admin;
import 'ui/admin/jobs_screen.dart';
import 'ui/admin/overview_screen.dart';
import 'ui/admin/plans_screen.dart';
import 'ui/admin/revenue_screen.dart';
import 'ui/admin/settings_screen.dart';
import 'ui/admin/users_screen.dart';
import 'ui/admin/workers_screen.dart';
import 'ui/account/complaints_screen.dart';
import 'ui/account/notifications_screen.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/register_screen.dart';
import 'ui/bookings/booking_detail_screen.dart';
import 'ui/bookings/bookings_screen.dart';
import 'ui/bookings/chat_screen.dart';
import 'ui/customer/home_screen.dart';
import 'ui/customer/my_requests_screen.dart';
import 'ui/customer/new_request_screen.dart';
import 'ui/customer/request_detail_screen.dart';
import 'ui/customer/worker_public_screen.dart';
import 'ui/shell/home_shell.dart';
import 'ui/worker/earnings_screen.dart';
import 'ui/worker/job_detail_screen.dart';
import 'ui/worker/job_feed_screen.dart';
import 'ui/worker/my_offers_screen.dart';
import 'ui/worker/plans_screen.dart';
import 'ui/worker/worker_profile_screen.dart';

const _authRoutes = {'/login', '/register'};

GoRouter buildRouter(Session session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session, state.uri.toString()),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminOverviewScreen()),
          GoRoute(path: '/admin/workers', builder: (_, _) => const AdminWorkersScreen()),
          GoRoute(path: '/admin/users', builder: (_, _) => const AdminUsersScreen()),
          GoRoute(path: '/admin/bookings', builder: (_, _) => const AdminJobsScreen()),
          GoRoute(path: '/admin/revenue', builder: (_, _) => const AdminRevenueScreen()),
          GoRoute(path: '/admin/plans', builder: (_, _) => const AdminPlansScreen()),
          GoRoute(path: '/admin/complaints', builder: (_, _) => const admin.AdminComplaintsScreen()),
          GoRoute(path: '/admin/settings', builder: (_, _) => const AdminSettingsScreen()),
          GoRoute(path: '/admin/audit', builder: (_, _) => const AdminAuditScreen()),
        ],
      ),
      GoRoute(
        path: '/admin/workers/:id',
        builder: (_, s) => AdminWorkerReviewScreen(id: int.parse(s.pathParameters['id']!)),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const CustomerHomeScreen()),
          GoRoute(path: '/requests', builder: (_, _) => const MyRequestsScreen()),
          GoRoute(path: '/jobs', builder: (_, _) => const JobFeedScreen()),
          GoRoute(path: '/offers', builder: (_, _) => const MyOffersScreen()),
          GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
        ],
      ),
      GoRoute(
        path: '/requests/new',
        builder: (_, s) => NewRequestScreen(categoryId: int.tryParse(s.uri.queryParameters['category'] ?? '')),
      ),
      GoRoute(path: '/requests/:id', builder: (_, s) => RequestDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/workers/:id', builder: (_, s) => WorkerPublicScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/jobs/:id', builder: (_, s) => JobDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/bookings/:id', builder: (_, s) => BookingDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/bookings/:id/chat', builder: (_, s) => ChatScreen(bookingId: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/worker/profile', builder: (_, _) => const WorkerProfileScreen()),
      GoRoute(path: '/worker/earnings', builder: (_, _) => const EarningsScreen()),
      GoRoute(path: '/worker/plans', builder: (_, _) => const PlansScreen()),
      GoRoute(path: '/complaints', builder: (_, _) => const ComplaintsScreen()),
      GoRoute(
        path: '/complaints/new',
        builder: (_, s) => NewComplaintScreen(bookingId: int.tryParse(s.uri.queryParameters['booking'] ?? '')),
      ),
    ],
  );
}

/// Pure routing rules, unit-tested in test/router_test.dart.
///
/// [location] is the full URI (path and query). Deep links survive the splash screen and
/// the login screen through a `from` parameter, so reloading a booking page reopens it.
String? redirectFor(Session session, String location) {
  final uri = Uri.parse(location);
  final path = uri.path.isEmpty ? '/' : uri.path;
  final isAuthRoute = _authRoutes.contains(path);
  final from = uri.queryParameters['from'];
  String withFrom(String target) =>
      path == '/' || path == '/splash' || isAuthRoute ? target : Uri(path: target, queryParameters: {'from': location}).toString();

  switch (session.status) {
    case SessionStatus.unknown:
      return path == '/splash' ? null : withFrom('/splash');
    case SessionStatus.signedOut:
      if (isAuthRoute) return null;
      if (path == '/splash' && from != null) return Uri(path: '/login', queryParameters: {'from': from}).toString();
      return withFrom('/login');
    case SessionStatus.signedIn:
      final user = session.user!;
      final home = user.isWorker ? '/jobs' : (user.isCustomer ? '/' : '/admin');
      if (isAuthRoute || path == '/splash') {
        final target = from != null && from.startsWith('/') && !from.startsWith('//') ? from : null;
        if (target != null && redirectFor(session, target) == null) return target;
        return home;
      }
      final isAdminPath = path == '/admin' || path.startsWith('/admin/');
      if (user.isAdmin) return isAdminPath ? null : '/admin';
      if (isAdminPath) return home;
      const workerOnly = ['/jobs', '/offers', '/worker'];
      const customerOnly = ['/requests'];
      if (user.isWorker && (path == '/' || customerOnly.any(path.startsWith))) return '/jobs';
      if (user.isCustomer && workerOnly.any(path.startsWith)) return '/';
      return null;
  }
}

class KaamNowApp extends StatefulWidget {
  const KaamNowApp({super.key, required this.session});
  final Session session;
  @override
  State<KaamNowApp> createState() => _KaamNowAppState();
}

class _KaamNowAppState extends State<KaamNowApp> {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0E7C66);
    return ChangeNotifierProvider.value(
      value: widget.session,
      child: MaterialApp.router(
        title: 'KaamNow',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
        ),
      ),
    );
  }
}
