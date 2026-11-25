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

  // ---- payouts and commission --------------------------------------------
  Future<Paged<Settlement>> settlements({String? kind, String? status, int page = 1}) async => Paged.parse(
      await client.get('/admin/settlements/', query: {'kind': kind, 'status': status, 'page': page}),
      Settlement.fromJson);
  Future<Settlement> markPayoutPaid(int id, String reference) async => Settlement.fromJson(
      asMap(await client.post('/admin/settlements/$id/mark-paid/', body: {'reference': reference})));
  Future<Settlement> rejectPayout(int id, String reason) async =>
      Settlement.fromJson(asMap(await client.post('/admin/settlements/$id/reject/', body: {'reason': reason})));
  Future<List<WorkerBalance>> workerBalances({bool? owing}) async => parseList(
      await client.get('/admin/worker-balances/', query: {'owing': owing?.toString()}), WorkerBalance.fromJson);
  Future<Settlement> recordCommission(int workerId, String method, String reference) async => Settlement.fromJson(
      asMap(await client.post('/admin/workers/$workerId/record-commission/',
          body: {'method': method, 'reference': reference})));

  // ---- payments, refunds and disputes -------------------------------------
  Future<Paged<AdminPayment>> payments({String? status, String? method, bool? refunded, String? search,
          int page = 1}) async =>
      Paged.parse(
          await client.get('/admin/payments/', query: {
            'status': status,
            'method': method,
            'refunded': refunded?.toString(),
            'search': search,
            'page': page,
          }),
          AdminPayment.fromJson);
  Future<AdminRefund> refundPayment(int id,
          {required String amount,
          required String method,
          required String reason,
          required String reference,
          bool chargeWorker = false,
          int? complaintId}) async =>
      AdminRefund.fromJson(asMap(await client.post('/admin/payments/$id/refund/', body: {
        'amount': amount,
        'method': method,
        'reason': reason,
        'reference': reference,
        'charge_worker': chargeWorker,
        'complaint': ?complaintId,
      })));
  Future<AdminPayment> resolvePayment(int id, String resolution, String note,
          {String? method, String? reference}) async =>
      AdminPayment.fromJson(asMap(await client.post('/admin/payments/$id/resolve/', body: {
        'resolution': resolution,
        'note': note,
        'method': ?method,
        'reference': ?reference,
      })));

  // ---- promo codes ----------------------------------------------------------
  Future<Paged<AdminPromoCode>> promoCodes({bool? active, int page = 1}) async => Paged.parse(
      await client.get('/admin/promo-codes/', query: {'is_active': active?.toString(), 'page': page}),
      AdminPromoCode.fromJson);
  Future<AdminPromoCode> createPromoCode(Map<String, dynamic> body) async =>
      AdminPromoCode.fromJson(asMap(await client.post('/admin/promo-codes/', body: body)));
  Future<AdminPromoCode> updatePromoCode(int id, Map<String, dynamic> body) async =>
      AdminPromoCode.fromJson(asMap(await client.patch('/admin/promo-codes/$id/', body: body)));

  // ---- no-shows ---------------------------------------------------------------
  Future<Paged<AdminNoShow>> noShows({String? review, String? side, int page = 1}) async => Paged.parse(
      await client.get('/admin/no-shows/', query: {'review': review, 'side': side, 'page': page}), AdminNoShow.fromJson);
  Future<AdminNoShow> reviewNoShow(int id, String review, {String note = ''}) async => AdminNoShow.fromJson(
      asMap(await client.post('/admin/no-shows/$id/review/', body: {'review': review, 'note': note})));

  // ---- portfolio photos -------------------------------------------------------
  Future<Paged<PortfolioPhoto>> portfolioPhotos({bool? hidden, int page = 1}) async => Paged.parse(
      await client.get('/admin/portfolio-photos/', query: {'is_hidden': hidden?.toString(), 'page': page}),
      PortfolioPhoto.fromJson);
  Future<PortfolioPhoto> hidePortfolioPhoto(int id, String reason) async => PortfolioPhoto.fromJson(
      asMap(await client.post('/admin/portfolio-photos/$id/hide/', body: {'reason': reason})));
  Future<PortfolioPhoto> unhidePortfolioPhoto(int id) async =>
      PortfolioPhoto.fromJson(asMap(await client.post('/admin/portfolio-photos/$id/unhide/')));

  // ---- SOS alerts -------------------------------------------------------------
  Future<Paged<AdminSosAlert>> sosAlerts({String? status, int page = 1}) async => Paged.parse(
      await client.get('/admin/sos-alerts/', query: {'status': status, 'page': page}), AdminSosAlert.fromJson);
  Future<AdminSosAlert> handleSos(int id, String status, {String note = ''}) async => AdminSosAlert.fromJson(
      asMap(await client.post('/admin/sos-alerts/$id/handle/', body: {'status': status, 'note': note})));

  // ---- complaints & audit ------------------------------------------------
  Future<Paged<AdminComplaint>> complaints({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/admin/complaints/', query: {'status': status, 'page': page}),
          AdminComplaint.fromJson);
  Future<AdminComplaint> updateComplaint(int id, String status, String resolution) async => AdminComplaint.fromJson(
      asMap(await client.post('/admin/complaints/$id/status/', body: {'status': status, 'resolution': resolution})));

  Future<Paged<AuditEntry>> auditLog({String? action, int page = 1}) async =>
      Paged.parse(await client.get('/admin/audit-logs/', query: {'action': action, 'page': page}), AuditEntry.fromJson);
}
