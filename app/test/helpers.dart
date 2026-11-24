import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaamnow/api/kaamnow_api.dart';
import 'package:kaamnow/core/api_client.dart';
import 'package:kaamnow/core/session.dart';
import 'package:kaamnow/core/token_store.dart';

typedef Handler = http.Response Function(http.Request req);

http.Response ok(Object? data, {int status = 200}) => http.Response(
    jsonEncode({'success': true, 'data': data, 'message': ''}), status,
    headers: {'content-type': 'application/json'});

http.Response err(int status, String code, String message, [Object? details]) => http.Response(
    jsonEncode({'success': false, 'error': {'code': code, 'message': message, 'details': details}}), status,
    headers: {'content-type': 'application/json'});

/// A scripted backend: routes are "METHOD /path/" (path below /api/v1).
class FakeBackend {
  final Map<String, Handler> routes = {};
  final List<http.Request> calls = [];

  void on(String route, Handler h) => routes[route] = h;

  late final MockClient client = MockClient((req) async {
    calls.add(req);
    final path = req.url.path.replaceFirst('/api/v1', '');
    final h = routes['${req.method} $path'];
    if (h == null) return err(404, 'not_found', 'No route for ${req.method} $path');
    return h(req);
  });

  List<http.Request> callsTo(String route) =>
      calls.where((r) => '${r.method} ${r.url.path.replaceFirst('/api/v1', '')}' == route).toList();
}

Map<String, dynamic> userJson({int id = 1, String role = 'customer', String name = 'Ayesha Khan'}) => {
      'id': id,
      'phone': '+923001234567',
      'email': null,
      'full_name': name,
      'role': role,
      'avatar': null,
      'default_address': '',
      'worker_profile_id': role == 'worker' ? 7 : null,
      'date_joined': '2026-11-01T10:00:00Z',
    };

Map<String, dynamic> workerJson({int id = 7, String name = 'Bilal Ahmed'}) => {
      'id': id,
      'full_name': name,
      'profile_picture': null,
      'bio': 'Electrician',
      'experience_years': 6,
      'service_area': 'Gulberg',
      'is_verified': true,
      'average_rating': '4.60',
      'rating_count': 12,
      'completed_jobs_count': 40,
      'plan_badge': '',
      'services': [
        {'id': 1, 'category': 1, 'category_name': 'Electrician', 'description': '', 'starting_price': '500.00', 'is_active': true}
      ],
    };

Map<String, dynamic> offerJson({int id = 3, String price = '1500.00', String awaiting = 'customer',
        String status = 'pending'}) => {
      'id': id,
      'request': 11,
      'worker': workerJson(),
      'initial_price': '1800.00',
      'current_price': price,
      'awaiting': awaiting,
      'estimated_arrival_minutes': 30,
      'message': 'Can come today',
      'additional_info': '',
      'distance_km': '2.40',
      'status': status,
      'negotiations': [
        {'id': 1, 'party': 'worker', 'action': 'offer', 'amount': '1800.00', 'message': '', 'created_at': '2026-11-24T08:00:00Z'},
        {'id': 2, 'party': 'customer', 'action': 'counter', 'amount': '1500.00', 'message': '', 'created_at': '2026-11-24T08:05:00Z'},
      ],
      'booking_id': null,
      'created_at': '2026-11-24T08:00:00Z',
      'updated_at': '2026-11-24T08:05:00Z',
    };

Map<String, dynamic> requestJson({int id = 11, String status = 'open', int? bookingId}) => {
      'id': id,
      'category': 1,
      'category_name': 'Electrician',
      'title': 'Fan not working',
      'description': 'Ceiling fan stopped working after a power cut',
      'latitude': '31.520400',
      'longitude': '74.358700',
      'address': 'House 1, Street 2',
      'area': 'Gulberg',
      'preferred_time': '2026-11-25T10:00:00Z',
      'budget': null,
      'is_emergency': false,
      'emergency_fee': '0.00',
      'status': status,
      'images': [],
      'offers_count': 1,
      'booking_id': bookingId,
      'matched_workers_count': null,
      'cancel_reason': '',
      'cancelled_at': null,
      'created_at': '2026-11-24T07:00:00Z',
      'updated_at': '2026-11-24T07:00:00Z',
    };

Map<String, dynamic> bookingJson({int id = 21, String status = 'confirmed'}) => {
      'id': id,
      'request_id': 11,
      'title': 'Fan not working',
      'category_name': 'Electrician',
      'preferred_time': '2026-11-25T10:00:00Z',
      'agreed_price': '1500.00',
      'emergency_fee': '300.00',
      'total_amount': '1800.00',
      'status': status,
      'worker': workerJson(),
      'customer_name': 'Ayesha Khan',
      'contact': {'worker_phone': '+923007654321'},
      'status_history': [
        {'from_status': '', 'to_status': 'confirmed', 'note': '', 'created_at': '2026-11-24T08:10:00Z'}
      ],
      'commission': null,
      'has_review': false,
      'cancel_reason': '',
      'completed_via': '',
      'created_at': '2026-11-24T08:10:00Z',
      'updated_at': '2026-11-24T08:10:00Z',
    };

Map<String, dynamic> configJson() => {
      'api_version': 'v1',
      'min_supported_version': {'android': '1.0.0', 'ios': '1.0.0', 'web': '1.0.0'},
      'currency': 'PKR',
      'city': {'name': 'Lahore', 'latitude': 31.5204, 'longitude': 74.3587},
      'emergency': {'enabled': true, 'fee': '300.00'},
      'offer_price': {'min': '100', 'max': '1000000'},
      'payment_methods': [
        {'code': 'cash', 'label': 'Cash', 'available': true},
        {'code': 'jazzcash', 'label': 'JazzCash', 'available': false},
      ],
      'push_enabled': false,
      'websocket_path': '/ws/bookings/{booking_id}/?token={access_token}',
      'support': {'email': 'support@kaamnow.pk', 'phone': ''},
    };

class Harness {
  Harness({String? access, String? refresh}) : tokens = MemoryTokenStore(access: access, refresh: refresh) {
    client = ApiClient(root: 'http://api.test/api/v1', tokens: tokens, httpClient: backend.client);
    api = KaamNowApi(client);
    session = Session(api, tokens);
  }
  final backend = FakeBackend();
  final MemoryTokenStore tokens;
  late final ApiClient client;
  late final KaamNowApi api;
  late final Session session;
}
