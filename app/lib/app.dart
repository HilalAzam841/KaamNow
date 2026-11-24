import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/format.dart';
import 'core/install/install_controller.dart';
import 'core/locale_controller.dart';
import 'core/push/push_controller.dart';
import 'core/session.dart';
import 'l10n/l10n.dart';
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
import 'ui/auth/reset_password_screen.dart';
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

/// Opened from the password-reset email; works signed in or out.
const _publicRoutes = {'/reset-password'};

GoRouter buildRouter(Session session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session, state.uri.toString()),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, s) => ResetPasswordScreen(
            uid: s.uri.queryParameters['uid'] ?? '', token: s.uri.queryParameters['token'] ?? ''),
      ),
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
  if (_publicRoutes.contains(path)) return null;
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
  KaamNowApp(
      {super.key, required this.session, LocaleController? locale, InstallController? install, PushController? push})
      : locale = locale ?? LocaleController(),
        install = install ?? InstallController(),
        push = push ?? PushController();
  final Session session;
  final LocaleController locale;
  final InstallController install;
  final PushController push;
  @override
  State<KaamNowApp> createState() => _KaamNowAppState();
}

class _KaamNowAppState extends State<KaamNowApp> {
  late final GoRouter _router = buildRouter(widget.session);
  String? _syncedLanguage;

  @override
  void initState() {
    super.initState();
    widget.locale.addListener(_onLanguageOrSession);
    widget.session.addListener(_onLanguageOrSession);
    widget.push.attach(widget.session);
    _onLanguageOrSession();
  }

  @override
  void dispose() {
    widget.locale.removeListener(_onLanguageOrSession);
    widget.session.removeListener(_onLanguageOrSession);
    super.dispose();
  }

  /// The admin dashboard is English-only; everyone else gets the language they picked.
  String get _effectiveLanguage => widget.session.user?.isAdmin == true ? 'en' : widget.locale.code;

  /// Sends the language with every request, and saves it on the account so alerts
  /// (written by the server, also when the app is closed) use it too.
  void _onLanguageOrSession() {
    final code = _effectiveLanguage;
    widget.session.api.client.language = code;
    final user = widget.session.user;
    if (user == null || user.isAdmin) {
      _syncedLanguage = null;
      return;
    }
    if (user.language == code || _syncedLanguage == code) return;
    _syncedLanguage = code;
    widget.session.api.updateMe({'language': code}).then((_) {}, onError: (_) => _syncedLanguage = null);
  }

  ThemeData _theme(Brightness brightness, bool urdu) {
    const seed = Color(0xFF0E7C66);
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
      // Nastaliq script needs room above and below the line.
      fontFamily: urdu ? 'NotoNastaliqUrdu' : null,
    );
    if (!urdu) return base;
    return base.copyWith(textTheme: base.textTheme.apply(heightFactor: 1.0, heightDelta: 0.35));
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.session),
        ChangeNotifierProvider.value(value: widget.locale),
        ChangeNotifierProvider.value(value: widget.install),
        ChangeNotifierProvider.value(value: widget.push),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.locale, widget.session]),
        builder: (context, _) {
          final code = _effectiveLanguage;
          final urdu = code == 'ur';
          return MaterialApp.router(
            onGenerateTitle: (context) => context.t.appName,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            locale: Locale(code),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
            builder: (context, child) {
              useStrings(context.t);
              return child!;
            },
            theme: _theme(Brightness.light, urdu),
            darkTheme: _theme(Brightness.dark, urdu),
          );
        },
      ),
    );
  }
}
