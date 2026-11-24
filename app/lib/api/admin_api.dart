import 'dart:typed_data';

import '../core/api_client.dart';
import '../models/admin_models.dart';
import '../models/models.dart';

/// Admin endpoints (`/api/v1/admin/...`). Every call needs an admin account; the server enforces it.
class AdminApi {
  AdminApi(this.client);
  final ApiClient client;

  // ---- overview & reporting ---------------------------------------------
  Future<Map<String, dynamic>> dashboard() async => asMap(await client.get('/admin/dashboard/'));
  Future<Map<String, dynamic>> revenue({String? from, String? to}) async =>
      asMap(await client.get('/admin/revenue/', query: {'date_from': from, 'date_to': to}));
  Future<Map<String, dynamic>> otherRevenue({String? from, String? to}) async =>
      asMap(await client.get('/admin/revenue/other/', query: {'date_from': from, 'date_to': to}));
  Future<Map<String, dynamic>> reports({String? from, String? to}) async =>
      asMap(await client.get('/admin/reports/', query: {'date_from': from, 'date_to': to}));

  // ---- workers -----------------------------------------------------------
  Future<Paged<AdminWorker>> pendingWorkers({String? search, int page = 1}) async =>
      Paged.parse(await client.get('/admin/workers/pending/', query: {'search': search, 'page': page}),
          AdminWorker.fromJson);
  Future<AdminWorker> worker(int id) async => AdminWorker.fromJson(asMap(await client.get('/admin/workers/$id/')));
  Future<AdminWorker> verifyWorker(int id) async =>
      AdminWorker.fromJson(asMap(await client.post('/admin/workers/$id/verify/')));
  Future<AdminWorker> rejectWorker(int id, String reason) async =>
      AdminWorker.fromJson(asMap(await client.post('/admin/workers/$id/reject/', body: {'reason': reason})));

  /// Raw bytes of a private CNIC/certificate file. Each download is written to the audit log.
  Future<(Uint8List, String)> documentFile(int id) => client.getBytes('/admin/documents/$id/file/');

  // ---- users -------------------------------------------------------------
  Future<Paged<AdminUser>> users({String? role, String? search, bool? suspended, int page = 1}) async =>
      Paged.parse(await client.get('/admin/users/', query: {
        'role': role,
        'search': search,
        'is_suspended': suspended,
        'page': page,
      }), AdminUser.fromJson);
  Future<AdminUser> suspendUser(int id, String reason) async =>
      AdminUser.fromJson(asMap(await client.post('/admin/users/$id/suspend/', body: {'reason': reason})));
  Future<AdminUser> reactivateUser(int id) async =>
      AdminUser.fromJson(asMap(await client.post('/admin/users/$id/reactivate/')));

  // ---- activity ----------------------------------------------------------
  Future<Paged<Booking>> bookings({String? status, String? search, String? from, String? to, int page = 1}) async =>
      Paged.parse(await client.get('/admin/bookings/', query: {
        'status': status,
        'search': search,
        'date_from': from,
        'date_to': to,
        'page': page,
      }), Booking.fromJson);
  Future<Paged<ServiceRequest>> requests({String? status, String? search, int page = 1}) async =>
      Paged.parse(await client.get('/admin/requests/', query: {'status': status, 'search': search, 'page': page}),
          ServiceRequest.fromJson);
  Future<Paged<AdminCommission>> commissions({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/admin/commissions/', query: {'status': status, 'page': page}),
          AdminCommission.fromJson);

  // ---- settings & plans --------------------------------------------------
  Future<PlatformSettings> settings() async => PlatformSettings.fromJson(asMap(await client.get('/admin/settings/')));
  Future<PlatformSettings> updateSettings(Map<String, dynamic> fields) async =>
      PlatformSettings.fromJson(asMap(await client.patch('/admin/settings/', body: fields)));

  Future<List<SubscriptionPlan>> subscriptionPlans() async =>
      Paged.parse(await client.get('/admin/subscription-plans/'), SubscriptionPlan.fromJson).results;
  Future<SubscriptionPlan> updateSubscriptionPlan(int id, Map<String, dynamic> fields) async =>
      SubscriptionPlan.fromJson(asMap(await client.patch('/admin/subscription-plans/$id/', body: fields)));
  Future<SubscriptionPlan> createSubscriptionPlan(Map<String, dynamic> fields) async =>
      SubscriptionPlan.fromJson(asMap(await client.post('/admin/subscription-plans/', body: fields)));

  Future<List<FeaturedPlan>> featuredPlans() async =>
      Paged.parse(await client.get('/admin/featured-plans/'), FeaturedPlan.fromJson).results;
  Future<FeaturedPlan> updateFeaturedPlan(int id, Map<String, dynamic> fields) async =>
      FeaturedPlan.fromJson(asMap(await client.patch('/admin/featured-plans/$id/', body: fields)));
  Future<FeaturedPlan> createFeaturedPlan(Map<String, dynamic> fields) async =>
      FeaturedPlan.fromJson(asMap(await client.post('/admin/featured-plans/', body: fields)));

  Future<Paged<AdminSubscription>> subscriptions({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/admin/subscriptions/', query: {'status': status, 'page': page}),
          AdminSubscription.fromJson);
  Future<AdminSubscription> activateSubscription(int id) async =>
      AdminSubscription.fromJson(asMap(await client.post('/admin/subscriptions/$id/activate/')));

  Future<Paged<AdminFeaturedListing>> featuredListings({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/admin/featured-listings/', query: {'status': status, 'page': page}),
          AdminFeaturedListing.fromJson);
  Future<AdminFeaturedListing> cancelFeaturedListing(int id, String reason) async => AdminFeaturedListing.fromJson(
      asMap(await client.post('/admin/featured-listings/$id/cancel/', body: {'reason': reason})));

  // ---- complaints & audit ------------------------------------------------
  Future<Paged<AdminComplaint>> complaints({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/admin/complaints/', query: {'status': status, 'page': page}),
          AdminComplaint.fromJson);
  Future<AdminComplaint> updateComplaint(int id, String status, String resolution) async => AdminComplaint.fromJson(
      asMap(await client.post('/admin/complaints/$id/status/', body: {'status': status, 'resolution': resolution})));

  Future<Paged<AuditEntry>> auditLog({String? action, int page = 1}) async =>
      Paged.parse(await client.get('/admin/audit-logs/', query: {'action': action, 'page': page}), AuditEntry.fromJson);
}
