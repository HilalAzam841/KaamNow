import 'dart:typed_data';

import '../core/api_client.dart';
import '../models/models.dart';

/// YYYY-MM-DD for a calendar date.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Typed wrapper over every endpoint the app uses. One method per API call.
class KaamNowApi {
  KaamNowApi(this.client);
  final ApiClient client;

  // ---- App & auth --------------------------------------------------------
  Future<ClientConfig> appConfig() async => ClientConfig.fromJson(asMap(await client.get('/app/config/')));

  Future<(User, String, String)> login(String phone, String password) async =>
      _auth(await client.post('/auth/login/', body: {'phone': phone, 'password': password}, auth: false));

  Future<(User, String, String)> register({required String phone, required String password,
      required String fullName, required UserRole role, String? email, String? cnic, String? referralCode}) async {
    final body = {
      'phone': phone,
      'password': password,
      'full_name': fullName,
      'role': role.name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (cnic != null && cnic.isNotEmpty) 'cnic_number': cnic,
      if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
    };
    return _auth(await client.post('/auth/register/', body: body, auth: false));
  }

  (User, String, String) _auth(Object? data) {
    final m = asMap(data);
    final tokens = asMap(m['tokens']);
    return (User.fromJson(asMap(m['user'])), str(tokens['access']), str(tokens['refresh']));
  }

  Future<void> logout(String refresh) => client.post('/auth/logout/', body: {'refresh': refresh});
  /// Browser notifications: [subscription] is PushSubscription.toJSON().
  Future<void> subscribeWebPush(Map<String, dynamic> subscription) =>
      client.post('/notifications/web-push/subscribe/', body: subscription);
  Future<void> unsubscribeWebPush(String endpoint) =>
      client.post('/notifications/web-push/unsubscribe/', body: {'endpoint': endpoint});

  /// Phone apps: this device's Firebase token ('android' or 'ios').
  Future<void> registerDevice(String token, String platform) =>
      client.post('/notifications/devices/', body: {'token': token, 'platform': platform});
  Future<void> unregisterDevice(String token) => client.delete('/notifications/devices/', body: {'token': token});
  Future<User> me() async => User.fromJson(asMap(await client.get('/auth/me/')));
  Future<User> updateMe(Map<String, dynamic> fields) async =>
      User.fromJson(asMap(await client.patch('/auth/me/', body: fields)));
  Future<void> changePassword(String current, String next) =>
      client.post('/auth/password-change/', body: {'current_password': current, 'new_password': next});
  /// Returns true when the server sent a code by SMS (then use [resetPasswordWithCode]).
  Future<bool> requestPasswordReset(String phone) async =>
      asMap(await client.post('/auth/password-reset/', body: {'phone': phone}, auth: false))['sms_code'] == true;
  Future<void> resetPasswordWithCode(String phone, String code, String newPassword) => client.post(
      '/auth/password-reset/sms-confirm/', body: {'phone': phone, 'code': code, 'new_password': newPassword}, auth: false);

  /// Sends a code to the signed-in user's phone. Returns the seconds to wait before asking again.
  Future<int> sendPhoneCode() async => parseInt(asMap(await client.post('/auth/phone/send-code/'))['resend_after']);
  Future<User> verifyPhone(String code) async =>
      User.fromJson(asMap(await client.post('/auth/phone/verify/', body: {'code': code})));
  Future<void> confirmPasswordReset(String uid, String token, String newPassword) => client.post(
      '/auth/password-reset/confirm/', body: {'uid': uid, 'token': token, 'new_password': newPassword}, auth: false);

  // ---- Catalog & discovery ----------------------------------------------
  Future<List<ServiceCategory>> categories() async =>
      Paged.parse(await client.get('/services/categories/'), ServiceCategory.fromJson).results;

  Future<List<PublicWorker>> nearbyWorkers({required double lat, required double lng, int? category}) async =>
      Paged.parse(await client.get('/workers/nearby/', query: {'latitude': lat, 'longitude': lng, 'category': category}),
          PublicWorker.fromJson).results;

  Future<PublicWorker> worker(int id) async => PublicWorker.fromJson(asMap(await client.get('/workers/$id/')));
  Future<Paged<Review>> workerReviews(int id, {bool withPhotos = false}) async => Paged.parse(
      await client.get('/workers/$id/reviews/', query: {if (withPhotos) 'with_photos': 'true'}), Review.fromJson);

  // ---- Service requests --------------------------------------------------
  Future<ServiceRequest> createRequest({required int category, required String title, required String description,
      required double latitude, required double longitude, required String address, String area = '',
      required DateTime preferredTime, int durationMinutes = 120, String? budget, bool isEmergency = false,
      int? workerId, List<UploadFile> images = const []}) async {
    final fields = {
      'category': '$category',
      'title': title,
      'description': description,
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'address': address,
      'area': area,
      'preferred_time': preferredTime.toUtc().toIso8601String(),
      'duration_minutes': '$durationMinutes',
      'budget': ?(budget == null || budget.isEmpty ? null : budget),
      'is_emergency': isEmergency ? 'true' : 'false',
      'worker': ?(workerId == null ? null : '$workerId'),
    };
    final data = await client.multipart('POST', '/requests/', fields: fields, files: images);
    return ServiceRequest.fromJson(asMap(data));
  }

  /// Two-hour slots on [date] with how many matching workers nearby are free in each.
  Future<List<TimeSlot>> timeSlots({required int category, required double lat, required double lng,
      required DateTime date}) async {
    final d = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final data = await client.get('/requests/slots/', query: {
      'category': category,
      'latitude': lat.toStringAsFixed(6),
      'longitude': lng.toStringAsFixed(6),
      'date': d,
    });
    return parseList(data, TimeSlot.fromJson);
  }

  /// Book again: send the job to every free worker nearby instead of only the chosen one.
  Future<ServiceRequest> openToAll(int requestId) async =>
      ServiceRequest.fromJson(asMap(await client.post('/requests/$requestId/open-to-all/')));

  /// Invited worker: cannot take this job. It goes to other workers nearby.
  Future<void> declineRequest(int requestId) => client.post('/requests/$requestId/decline/');

  // ---- Saved addresses -----------------------------------------------------
  Future<List<SavedAddress>> savedAddresses() async =>
      parseList(await client.get('/addresses/'), SavedAddress.fromJson);
  Future<SavedAddress> addAddress(Map<String, dynamic> fields) async =>
      SavedAddress.fromJson(asMap(await client.post('/addresses/', body: fields)));
  Future<SavedAddress> updateAddress(int id, Map<String, dynamic> fields) async =>
      SavedAddress.fromJson(asMap(await client.patch('/addresses/$id/', body: fields)));
  Future<void> deleteAddress(int id) => client.delete('/addresses/$id/');
  Future<SavedAddress> makeDefaultAddress(int id) async =>
      SavedAddress.fromJson(asMap(await client.post('/addresses/$id/make-default/')));

  // ---- Portfolio -----------------------------------------------------------
  Future<List<PortfolioPhoto>> myPortfolio() async =>
      parseList(await client.get('/workers/me/portfolio/'), PortfolioPhoto.fromJson);
  Future<PortfolioPhoto> addPortfolioPhoto(UploadFile image, {String caption = '', int? category}) async =>
      PortfolioPhoto.fromJson(asMap(await client.multipart('POST', '/workers/me/portfolio/',
          fields: {'caption': caption, 'category': ?category?.toString()}, files: [image])));
  Future<PortfolioPhoto> updatePortfolioPhoto(int id, Map<String, dynamic> fields) async =>
      PortfolioPhoto.fromJson(asMap(await client.patch('/workers/me/portfolio/$id/', body: fields)));
  Future<void> deletePortfolioPhoto(int id) => client.delete('/workers/me/portfolio/$id/');
  Future<List<PortfolioPhoto>> reorderPortfolio(List<int> ids) async =>
      parseList(await client.post('/workers/me/portfolio/reorder/', body: {'ids': ids}), PortfolioPhoto.fromJson);

  // ---- Fixed-price packages ------------------------------------------------
  Future<List<ServicePackage>> myPackages() async =>
      parseList(await client.get('/workers/me/packages/'), ServicePackage.fromJson);
  Future<ServicePackage> createPackage(Map<String, dynamic> fields) async =>
      ServicePackage.fromJson(asMap(await client.post('/workers/me/packages/', body: fields)));
  Future<ServicePackage> updatePackage(int id, Map<String, dynamic> fields) async =>
      ServicePackage.fromJson(asMap(await client.patch('/workers/me/packages/$id/', body: fields)));
  Future<void> deletePackage(int id) => client.delete('/workers/me/packages/$id/');
  Future<List<ServicePackage>> workerPackages(int workerId) async =>
      parseList(await client.get('/workers/$workerId/packages/'), ServicePackage.fromJson);
  Future<Paged<ServicePackage>> packages({int? category, double? lat, double? lng, int page = 1}) async =>
      Paged.parse(
          await client.get('/packages/', query: {'category': category, 'latitude': lat, 'longitude': lng, 'page': page}),
          ServicePackage.fromJson);
  Future<ServicePackage> package(int id) async => ServicePackage.fromJson(asMap(await client.get('/packages/$id/')));

  /// Books [packageId] at its fixed price. Pass a saved address id, or a pin and address.
  Future<Booking> bookPackage(int packageId,
          {required DateTime preferredTime, int? savedAddress, double? latitude, double? longitude,
          String address = '', String area = '', String notes = ''}) async =>
      Booking.fromJson(asMap(await client.post('/packages/$packageId/book/', body: {
        'preferred_time': preferredTime.toUtc().toIso8601String(),
        'saved_address': ?savedAddress,
        if (savedAddress == null) ...{
          'latitude': latitude?.toStringAsFixed(6),
          'longitude': longitude?.toStringAsFixed(6),
          'address': address,
          'area': area,
        },
        if (notes.isNotEmpty) 'notes': notes,
      })));

  // ---- Safety --------------------------------------------------------------
  Future<List<EmergencyContact>> emergencyContacts() async =>
      parseList(await client.get('/safety/contacts/'), EmergencyContact.fromJson);
  Future<EmergencyContact> addEmergencyContact(String name, String phone) async => EmergencyContact.fromJson(
      asMap(await client.post('/safety/contacts/', body: {'name': name, 'phone': phone})));
  Future<void> removeEmergencyContact(int id) => client.delete('/safety/contacts/$id/');

  /// Returns how many emergency contacts were texted.
  Future<int> raiseSos(int bookingId, {String note = ''}) async =>
      parseInt(asMap(await client.post('/bookings/$bookingId/sos/', body: {'note': note}))['contacts_texted']);
  Future<TripShare> shareBooking(int bookingId, {bool sendToContacts = false}) async => TripShare.fromJson(
      asMap(await client.post('/bookings/$bookingId/share/', body: {'send_to_contacts': sendToContacts})));
  Future<void> stopSharing(int bookingId) => client.delete('/bookings/$bookingId/share/');
  Future<SharedJob> sharedJob(String token) async =>
      SharedJob.fromJson(asMap(await client.get('/safety/shared/${Uri.encodeComponent(token)}/')));

  // ---- Repeating jobs ------------------------------------------------------
  Future<List<RecurringJob>> recurringJobs({String? status}) async =>
      Paged.parse(await client.get('/recurring-jobs/', query: {'status': status}), RecurringJob.fromJson).results;
  Future<RecurringJob> repeatBooking(int bookingId, String frequency, DateTime firstVisit) async =>
      RecurringJob.fromJson(asMap(await client.post('/recurring-jobs/from-booking/', body: {
        'booking': bookingId,
        'frequency': frequency,
        'first_visit': firstVisit.toUtc().toIso8601String(),
      })));
  Future<RecurringJob> updateRecurring(int id, Map<String, dynamic> fields) async =>
      RecurringJob.fromJson(asMap(await client.patch('/recurring-jobs/$id/', body: fields)));

  /// pause, resume, cancel, skip-next (customer) or leave (worker).
  Future<RecurringJob> recurringAction(int id, String action) async =>
      RecurringJob.fromJson(asMap(await client.post('/recurring-jobs/$id/$action/')));

  // ---- Favourite workers -------------------------------------------------
  Future<List<PublicWorker>> favourites() async => parseList(await client.get('/favourites/'), PublicWorker.fromJson);
  Future<List<PublicWorker>> recentWorkers() async =>
      parseList(await client.get('/favourites/recent/'), PublicWorker.fromJson);
  Future<void> addFavourite(int workerId) => client.post('/favourites/', body: {'worker': workerId});
  Future<void> removeFavourite(int workerId) => client.delete('/favourites/$workerId/');

  Future<List<WorkerSlot>> workerSlots(int workerId, DateTime date) async {
    final d = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return parseList(await client.get('/workers/$workerId/slots/', query: {'date': d}), WorkerSlot.fromJson);
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
  Future<CancellationQuote> cancelQuote(int id) async =>
      CancellationQuote.fromJson(asMap(await client.get('/bookings/$id/cancel-fee/')));
  Future<List<CancellationFeeInfo>> cancellationFees({String? status}) async => Paged.parse(
          await client.get('/cancellation-fees/', query: {'status': status}), CancellationFeeInfo.fromJson)
      .results;

  /// Starts an online payment of a late cancellation fee; open the returned checkout.
  Future<Checkout?> payCancellationFee(int id, String method) async {
    final payment = asMap(await client.post('/cancellation-fees/$id/pay/', body: {'method': method}));
    return payment['checkout'] == null ? null : Checkout.fromJson(asMap(payment['checkout']));
  }

  /// Tips the worker after a completed job. Returns the gateway checkout for online methods, else null.
  Future<(TipInfo, Checkout?)> giveTip(int bookingId, {required String amount, required String method,
      String message = ''}) async {
    final r = asMap(await client.post('/bookings/$bookingId/tip/',
        body: {'amount': amount, 'method': method, if (message.isNotEmpty) 'message': message}));
    return (TipInfo.fromJson(asMap(r['tip'])), r['checkout'] == null ? null : Checkout.fromJson(asMap(r['checkout'])));
  }

  Future<List<TipInfo>> tips({String? status}) async =>
      Paged.parse(await client.get('/tips/', query: {'status': status}), TipInfo.fromJson).results;
  Future<({int count, String total})> tipSummary() async {
    final j = asMap(await client.get('/tips/summary/'));
    return (count: parseInt(j['count']), total: j['total'] == null ? '0.00' : str(j['total']));
  }

  Future<TipInfo> confirmCashTip(int id) async =>
      TipInfo.fromJson(asMap(await client.post('/tips/$id/confirm-cash/')));
  Future<TipInfo> cashTipNotReceived(int id) async =>
      TipInfo.fromJson(asMap(await client.post('/tips/$id/not-received/')));

  Future<Booking> cancelBooking(int id, String reason) async =>
      Booking.fromJson(asMap(await client.post('/bookings/$id/cancel/', body: {'reason': reason})));

  /// The other side did not show up. Cancels the booking.
  Future<Booking> reportNoShow(int id, {String note = ''}) async =>
      Booking.fromJson(asMap(await client.post('/bookings/$id/no-show/', body: {'note': note})));

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
  Future<Payment> createPayment(int bookingId, String method, {String promoCode = '', bool useCredit = false}) async =>
      Payment.fromJson(asMap(await client.post('/payments/', body: {
        'booking': bookingId,
        'method': method,
        if (promoCode.isNotEmpty) 'promo_code': promoCode,
        if (useCredit) 'use_credit': true,
      })));
  Future<PaymentQuote> checkPromo(int bookingId, {String promoCode = '', bool useCredit = false}) async =>
      PaymentQuote.fromJson(asMap(await client.post('/promos/check/',
          body: {'booking': bookingId, 'promo_code': promoCode, 'use_credit': useCredit})));
  Future<ReferralSummary> referralSummary() async => ReferralSummary.fromJson(asMap(await client.get('/referrals/me/')));
  Future<LevelProgress> myLevel() async => LevelProgress.fromJson(asMap(await client.get('/workers/me/level/')));

  Future<Receipt> receipt(int paymentId) async =>
      Receipt.fromJson(asMap(await client.get('/payments/$paymentId/receipt/')));

  /// The receipt PDF in [lang] (en or ur): bytes and content type.
  Future<(Uint8List, String)> receiptPdf(int paymentId, String lang) =>
      client.getBytes('/payments/$paymentId/receipt/pdf/', query: {'lang': lang});

  Future<List<Payment>> paymentsForBooking(int bookingId) async =>
      Paged.parse(await client.get('/payments/', query: {'booking': bookingId}), Payment.fromJson).results;
  Future<Payment> confirmCashPayment(int paymentId) async =>
      Payment.fromJson(asMap(await client.post('/payments/$paymentId/confirm/')));
  Future<EarningsReport> earningsReport({required DateTime start, required DateTime end}) async =>
      EarningsReport.fromJson(asMap(await client.get('/payments/earnings/report/',
          query: {'start': isoDate(start), 'end': isoDate(end)})));

  /// The CSV statement for a date range: bytes and content type.
  Future<(Uint8List, String)> earningsStatement({required DateTime start, required DateTime end}) =>
      client.getBytes('/payments/earnings/statement/', query: {'start': isoDate(start), 'end': isoDate(end)});

  Future<EarningsSummary> earnings() async => EarningsSummary.fromJson(asMap(await client.get('/payments/earnings/')));

  // ---- worker wallet: payouts and commission ------------------------------
  Future<Wallet> wallet() async => Wallet.fromJson(asMap(await client.get('/payments/wallet/')));
  Future<Settlement> requestPayout(PayoutAccount account) async => Settlement.fromJson(asMap(await client.post(
      '/payments/payouts/',
      body: {'method': account.method, 'account_title': account.accountTitle, 'account_number': account.accountNumber})));
  Future<Settlement> cancelPayout(int id) async =>
      Settlement.fromJson(asMap(await client.post('/payments/payouts/$id/cancel/')));

  /// Starts an online commission payment; open the returned checkout. Settled by the server only
  /// after the gateway confirms it.
  Future<Checkout?> payCommission(String method) async {
    final m = asMap(await client.post('/payments/commission/pay/', body: {'method': method}));
    final payment = asMap(m['payment']);
    return payment['checkout'] == null ? null : Checkout.fromJson(asMap(payment['checkout']));
  }

  // ---- Before and after job photos ---------------------------------------
  Future<(JobPhotoSummary, List<JobPhoto>)> jobPhotos(int bookingId) async {
    final m = asMap(await client.get('/bookings/$bookingId/photos/'));
    return (JobPhotoSummary.fromJson(asMap(m['summary'])), parseList(m['results'], JobPhoto.fromJson));
  }

  /// The worker adds a photo ([kind] is before or after). The server removes location data.
  Future<JobPhoto> addJobPhoto(int bookingId, String kind, UploadFile image, {String caption = ''}) async =>
      JobPhoto.fromJson(asMap(await client.multipart('POST', '/bookings/$bookingId/photos/',
          fields: {'kind': kind, if (caption.isNotEmpty) 'caption': caption}, files: [image])));
  Future<void> deleteJobPhoto(int bookingId, int photoId) => client.delete('/bookings/$bookingId/photos/$photoId/');

  /// The picture itself. Job photos are private, so they are downloaded with your login, not by URL.
  Future<Uint8List> jobPhotoBytes(JobPhoto photo) async =>
      (await client.getBytes(photo.fileUrl.replaceFirst(RegExp(r'^/api/v1'), ''))).$1;

  // ---- Parts and materials ---------------------------------------------
  Future<(PartsSummary, List<JobPart>)> jobParts(int bookingId) async {
    final m = asMap(await client.get('/bookings/$bookingId/parts/'));
    return (PartsSummary.fromJson(asMap(m['summary'])), parseList(m['results'], JobPart.fromJson));
  }

  /// The worker adds a part. The customer must approve it before it is added to the bill.
  Future<JobPart> addJobPart(int bookingId,
          {required String name, int quantity = 1, required String unitPrice, UploadFile? receipt}) async =>
      JobPart.fromJson(asMap(await client.multipart('POST', '/bookings/$bookingId/parts/',
          fields: {'name': name, 'quantity': '$quantity', 'unit_price': unitPrice},
          files: [if (receipt != null) UploadFile(field: 'receipt', filename: receipt.filename, bytes: receipt.bytes)])));
  Future<void> deleteJobPart(int bookingId, int partId) => client.delete('/bookings/$bookingId/parts/$partId/');
  Future<JobPart> approveJobPart(int bookingId, int partId) async =>
      JobPart.fromJson(asMap(await client.post('/bookings/$bookingId/parts/$partId/approve/')));
  Future<JobPart> rejectJobPart(int bookingId, int partId, String reason) async => JobPart.fromJson(
      asMap(await client.post('/bookings/$bookingId/parts/$partId/reject/', body: {'reason': reason})));

  /// The receipt photo, downloaded with your login (it is private).
  Future<Uint8List> partReceiptBytes(JobPart part) async =>
      (await client.getBytes(part.receiptUrl!.replaceFirst(RegExp(r'^/api/v1'), ''))).$1;

  // ---- Work guarantee ----------------------------------------------------
  /// The customer asks for a free fix, within the guarantee period after the job.
  Future<GuaranteeClaim> makeGuaranteeClaim(int bookingId, String problem) async => GuaranteeClaim.fromJson(
      asMap(await client.post('/bookings/$bookingId/guarantee/', body: {'problem': problem})));
  Future<GuaranteeClaim> acceptGuaranteeClaim(int id, DateTime redoTime, {String note = ''}) async =>
      GuaranteeClaim.fromJson(asMap(await client.post('/guarantee-claims/$id/accept/',
          body: {'redo_time': redoTime.toUtc().toIso8601String(), 'note': note})));
  Future<GuaranteeClaim> declineGuaranteeClaim(int id, String reason) async => GuaranteeClaim.fromJson(
      asMap(await client.post('/guarantee-claims/$id/decline/', body: {'reason': reason})));
  Future<GuaranteeClaim> guaranteeRedoDone(int id) async =>
      GuaranteeClaim.fromJson(asMap(await client.post('/guarantee-claims/$id/redo-done/')));
  Future<GuaranteeClaim> guaranteeConfirmFixed(int id) async =>
      GuaranteeClaim.fromJson(asMap(await client.post('/guarantee-claims/$id/confirm-fixed/')));
  Future<GuaranteeClaim> withdrawGuaranteeClaim(int id) async =>
      GuaranteeClaim.fromJson(asMap(await client.post('/guarantee-claims/$id/withdraw/')));
  Future<GuaranteeClaim> escalateGuaranteeClaim(int id, {String details = ''}) async => GuaranteeClaim.fromJson(
      asMap(await client.post('/guarantee-claims/$id/escalate/', body: {'details': details})));

  // ---- Reviews & complaints ---------------------------------------------
  Future<Review> createReview(int bookingId, int rating, String comment) async => Review.fromJson(
      asMap(await client.post('/reviews/', body: {'booking': bookingId, 'rating': rating, 'comment': comment})));

  /// Adds a photo to your review (up to 3). The server removes location data.
  Future<ReviewPhoto> addReviewPhoto(int reviewId, UploadFile image) async =>
      ReviewPhoto.fromJson(asMap(await client.multipart('POST', '/reviews/$reviewId/photos/', fields: {}, files: [image])));
  Future<void> deleteReviewPhoto(int reviewId, int photoId) => client.delete('/reviews/$reviewId/photos/$photoId/');

  /// The reviewed worker answers in public, once.
  Future<Review> replyToReview(int reviewId, String reply) async =>
      Review.fromJson(asMap(await client.post('/reviews/$reviewId/reply/', body: {'reply': reply})));

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

  // ---- Worker schedule ---------------------------------------------------
  Future<WorkerSchedule> mySchedule() async => WorkerSchedule.fromJson(asMap(await client.get('/workers/me/schedule/')));
  Future<WorkerSchedule> saveHours(List<WorkingHours> hours) async => WorkerSchedule.fromJson(asMap(
      await client.put('/workers/me/schedule/', body: {'hours': [for (final h in hours) h.toJson()]})));
  Future<TimeOffEntry> addTimeOff(DateTime start, DateTime end, {String reason = ''}) async {
    String d(DateTime x) => '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
    return TimeOffEntry.fromJson(asMap(await client.post('/workers/me/time-off/',
        body: {'start_date': d(start), 'end_date': d(end), 'reason': reason})));
  }

  Future<void> deleteTimeOff(int id) => client.delete('/workers/me/time-off/$id/');
}
