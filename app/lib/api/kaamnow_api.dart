import '../core/api_client.dart';
import '../models/models.dart';

/// Typed wrapper over every endpoint the app uses. One method per API call.
class KaamNowApi {
  KaamNowApi(this.client);
  final ApiClient client;

  // ---- App & auth --------------------------------------------------------
  Future<ClientConfig> appConfig() async => ClientConfig.fromJson(asMap(await client.get('/app/config/')));

  Future<(User, String, String)> login(String phone, String password) async =>
      _auth(await client.post('/auth/login/', body: {'phone': phone, 'password': password}, auth: false));

  Future<(User, String, String)> register({required String phone, required String password,
      required String fullName, required UserRole role, String? email, String? cnic}) async {
    final body = {
      'phone': phone,
      'password': password,
      'full_name': fullName,
      'role': role.name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (cnic != null && cnic.isNotEmpty) 'cnic_number': cnic,
    };
    return _auth(await client.post('/auth/register/', body: body, auth: false));
  }

  (User, String, String) _auth(Object? data) {
    final m = asMap(data);
    final tokens = asMap(m['tokens']);
    return (User.fromJson(asMap(m['user'])), str(tokens['access']), str(tokens['refresh']));
  }

  Future<void> logout(String refresh) => client.post('/auth/logout/', body: {'refresh': refresh});
  Future<User> me() async => User.fromJson(asMap(await client.get('/auth/me/')));
  Future<User> updateMe(Map<String, dynamic> fields) async =>
      User.fromJson(asMap(await client.patch('/auth/me/', body: fields)));
  Future<void> changePassword(String current, String next) =>
      client.post('/auth/password-change/', body: {'current_password': current, 'new_password': next});
  Future<void> requestPasswordReset(String phone) =>
      client.post('/auth/password-reset/', body: {'phone': phone}, auth: false);
  Future<void> confirmPasswordReset(String uid, String token, String newPassword) => client.post(
      '/auth/password-reset/confirm/', body: {'uid': uid, 'token': token, 'new_password': newPassword}, auth: false);

  // ---- Catalog & discovery ----------------------------------------------
  Future<List<ServiceCategory>> categories() async =>
      Paged.parse(await client.get('/services/categories/'), ServiceCategory.fromJson).results;

  Future<List<PublicWorker>> nearbyWorkers({required double lat, required double lng, int? category}) async =>
      Paged.parse(await client.get('/workers/nearby/', query: {'latitude': lat, 'longitude': lng, 'category': category}),
          PublicWorker.fromJson).results;

  Future<PublicWorker> worker(int id) async => PublicWorker.fromJson(asMap(await client.get('/workers/$id/')));
  Future<Paged<Review>> workerReviews(int id) async =>
      Paged.parse(await client.get('/workers/$id/reviews/'), Review.fromJson);

  // ---- Service requests --------------------------------------------------
  Future<ServiceRequest> createRequest({required int category, required String title, required String description,
      required double latitude, required double longitude, required String address, String area = '',
      required DateTime preferredTime, String? budget, bool isEmergency = false,
      List<UploadFile> images = const []}) async {
    final fields = {
      'category': '$category',
      'title': title,
      'description': description,
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'address': address,
      'area': area,
      'preferred_time': preferredTime.toUtc().toIso8601String(),
      'budget': ?(budget == null || budget.isEmpty ? null : budget),
      'is_emergency': isEmergency ? 'true' : 'false',
    };
    final data = await client.multipart('POST', '/requests/', fields: fields, files: images);
    return ServiceRequest.fromJson(asMap(data));
  }

  /// Customers: own requests. Workers: scope "feed" (open nearby) or "offered".
  Future<Paged<ServiceRequest>> requests({String? scope, String? status, int page = 1}) async =>
      Paged.parse(await client.get('/requests/', query: {'scope': scope, 'status': status, 'page': page}),
          ServiceRequest.fromJson);

  Future<ServiceRequest> request(int id) async => ServiceRequest.fromJson(asMap(await client.get('/requests/$id/')));
  Future<ServiceRequest> cancelRequest(int id, String reason) async =>
      ServiceRequest.fromJson(asMap(await client.post('/requests/$id/cancel/', body: {'reason': reason})));

  // ---- Offers & negotiation ---------------------------------------------
  Future<Paged<WorkerOffer>> offersForRequest(int requestId, {String? ordering}) async =>
      Paged.parse(await client.get('/requests/$requestId/offers/', query: {'ordering': ordering, 'page_size': 100}),
          WorkerOffer.fromJson);

  Future<WorkerOffer> createOffer(int requestId, {required String price, required int etaMinutes,
      String message = '', String additionalInfo = ''}) async {
    final data = await client.post('/requests/$requestId/offers/', body: {
      'price': price,
      'estimated_arrival_minutes': etaMinutes,
      'message': message,
      'additional_info': additionalInfo,
    });
    return WorkerOffer.fromJson(asMap(data));
  }

  Future<Paged<WorkerOffer>> myOffers({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/offers/', query: {'status': status, 'page': page}), WorkerOffer.fromJson);

  Future<WorkerOffer> offer(int id) async => WorkerOffer.fromJson(asMap(await client.get('/offers/$id/')));

  Future<Booking> acceptOffer(int id, {String message = ''}) async =>
      Booking.fromJson(asMap(await client.post('/offers/$id/accept/', body: {'message': message})));

  Future<WorkerOffer> rejectOffer(int id, {String reason = ''}) async =>
      WorkerOffer.fromJson(asMap(await client.post('/offers/$id/reject/', body: {'reason': reason})));

  /// Counter with [amount], or agree to the other side's price (`agree: true`).
  /// Returns the offer and, when an agreement creates it, the booking.
  Future<(WorkerOffer, Booking?)> negotiate(int id, {String? amount, bool agree = false, String message = ''}) async {
    final data = asMap(await client.post('/offers/$id/negotiate/', body: {
      'action': agree ? 'agree' : 'counter',
      'amount': ?amount,
      'message': message,
    }));
    final booking = data['booking'] == null ? null : Booking.fromJson(asMap(data['booking']));
    return (WorkerOffer.fromJson(asMap(data['offer'])), booking);
  }

  // ---- Bookings ----------------------------------------------------------
  Future<Paged<Booking>> bookings({String? status, int page = 1}) async =>
      Paged.parse(await client.get('/bookings/', query: {'status': status, 'page': page}), Booking.fromJson);
  Future<Booking> booking(int id) async => Booking.fromJson(asMap(await client.get('/bookings/$id/')));
  Future<Booking> updateBookingStatus(int id, String status, {String note = ''}) async =>
      Booking.fromJson(asMap(await client.post('/bookings/$id/status/', body: {'status': status, 'note': note})));
  Future<Booking> cancelBooking(int id, String reason) async =>
      Booking.fromJson(asMap(await client.post('/bookings/$id/cancel/', body: {'reason': reason})));

  /// Customer: a private one-time code to give the worker. Returns (code, expiresAt).
  Future<(String, DateTime?)> issueCompletionOtp(int id) async {
    final m = asMap(await client.post('/bookings/$id/completion-otp/'));
    return (str(m['otp']), parseDate(m['expires_at']));
  }

  Future<Booking> completeWithOtp(int id, String otp) async =>
      Booking.fromJson(asMap(await client.post('/bookings/$id/complete/', body: {'otp': otp})));
  Future<Booking> confirmCompletion(int id) async =>
      Booking.fromJson(asMap(await client.post('/bookings/$id/complete/', body: {'confirm': true})));

  // ---- Chat & tracking ---------------------------------------------------
  /// Newest 100 messages, returned oldest first.
  Future<List<ChatMessage>> messages(int bookingId) async {
    final page = Paged.parse(
        await client.get('/bookings/$bookingId/messages/', query: {'ordering': '-created_at', 'page_size': 100}),
        ChatMessage.fromJson);
    return page.results.reversed.toList();
  }

  Future<ChatMessage> sendMessage(int bookingId, String body) async =>
      ChatMessage.fromJson(asMap(await client.post('/bookings/$bookingId/messages/', body: {'body': body})));
  Future<void> markMessagesRead(int bookingId) => client.post('/bookings/$bookingId/messages/read/');

  Future<LiveLocation> location(int bookingId) async =>
      LiveLocation.fromJson(asMap(await client.get('/bookings/$bookingId/location/')));
  Future<void> shareLocation(int bookingId, double lat, double lng, {double? accuracy, double? speedKmh, double? heading}) =>
      client.post('/bookings/$bookingId/location/', body: {
        'latitude': lat.toStringAsFixed(6),
        'longitude': lng.toStringAsFixed(6),
        if (accuracy != null) 'accuracy_m': accuracy.toStringAsFixed(1),
        if (speedKmh != null) 'speed_kmh': speedKmh.toStringAsFixed(1),
        if (heading != null) 'heading': heading.toStringAsFixed(1),
      });

  // ---- Payments ----------------------------------------------------------
  Future<Payment> createPayment(int bookingId, String method) async =>
      Payment.fromJson(asMap(await client.post('/payments/', body: {'booking': bookingId, 'method': method})));
  Future<List<Payment>> paymentsForBooking(int bookingId) async =>
      Paged.parse(await client.get('/payments/', query: {'booking': bookingId}), Payment.fromJson).results;
  Future<Payment> confirmCashPayment(int paymentId) async =>
      Payment.fromJson(asMap(await client.post('/payments/$paymentId/confirm/')));
  Future<EarningsSummary> earnings() async => EarningsSummary.fromJson(asMap(await client.get('/payments/earnings/')));

  // ---- Reviews & complaints ---------------------------------------------
  Future<Review> createReview(int bookingId, int rating, String comment) async => Review.fromJson(
      asMap(await client.post('/reviews/', body: {'booking': bookingId, 'rating': rating, 'comment': comment})));

  Future<Paged<Complaint>> complaints() async => Paged.parse(await client.get('/complaints/'), Complaint.fromJson);
  Future<Complaint> createComplaint({int? bookingId, required String category, required String subject,
      required String description}) async =>
      Complaint.fromJson(asMap(await client.post('/complaints/', body: {
        'booking': ?bookingId,
        'category': category,
        'subject': subject,
        'description': description,
      })));

  // ---- Notifications -----------------------------------------------------
  Future<Paged<AppNotification>> notifications({int page = 1}) async =>
      Paged.parse(await client.get('/notifications/', query: {'page': page}), AppNotification.fromJson);
  Future<int> unreadCount() async => parseInt(asMap(await client.get('/notifications/unread-count/'))['unread']);
  Future<void> markNotificationRead(int id) => client.post('/notifications/$id/read/');
  Future<void> markAllNotificationsRead() => client.post('/notifications/read-all/');

  // ---- Worker ------------------------------------------------------------
  Future<WorkerProfile> myWorkerProfile() async => WorkerProfile.fromJson(asMap(await client.get('/workers/me/')));
  Future<WorkerProfile> updateWorkerProfile(Map<String, dynamic> fields) async =>
      WorkerProfile.fromJson(asMap(await client.patch('/workers/me/', body: fields)));
  Future<WorkerProfile> uploadProfilePicture(UploadFile file) async =>
      WorkerProfile.fromJson(asMap(await client.multipart('PATCH', '/workers/me/', files: [file])));
  Future<WorkerProfile> setAvailability(bool available) async =>
      WorkerProfile.fromJson(asMap(await client.post('/workers/availability/', body: {'is_available': available})));

  Future<List<WorkerDocument>> myDocuments() async =>
      Paged.parse(await client.get('/workers/documents/'), WorkerDocument.fromJson).results;
  Future<WorkerDocument> uploadDocument(String type, UploadFile file) async => WorkerDocument.fromJson(
      asMap(await client.multipart('POST', '/workers/documents/', fields: {'document_type': type}, files: [file])));

  Future<void> addService(int category, {String description = '', String? startingPrice}) =>
      client.post('/services/workers/', body: {
        'category': category,
        'description': description,
        if (startingPrice != null && startingPrice.isNotEmpty) 'starting_price': startingPrice,
      });
  Future<void> removeService(int serviceId) => client.delete('/services/workers/$serviceId/');

  Future<List<SubscriptionPlan>> subscriptionPlans() async =>
      Paged.parse(await client.get('/subscriptions/plans/'), SubscriptionPlan.fromJson).results;
  Future<MySubscription> mySubscription() async =>
      MySubscription.fromJson(asMap(await client.get('/subscriptions/my-subscription/')));

  /// Returns a gateway checkout for paid plans, null for free ones.
  Future<Checkout?> subscribe(int planId, {String? method}) async {
    final m = asMap(await client.post('/subscriptions/', body: {'plan': planId, 'method': ?method}));
    return m['checkout'] == null ? null : Checkout.fromJson(asMap(m['checkout']));
  }
}
