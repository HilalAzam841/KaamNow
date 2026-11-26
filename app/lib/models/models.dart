import 'json.dart';

export 'json.dart';

enum UserRole { customer, worker, admin }

class User {
  User({required this.id, required this.phone, required this.fullName, required this.role, this.email,
      this.avatar, this.defaultAddress = '', this.workerProfileId, this.language = 'en', this.phoneVerified = false,
      this.bookingReminders = true});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: parseInt(j['id']),
        phone: str(j['phone']),
        fullName: str(j['full_name']),
        role: UserRole.values.firstWhere((r) => r.name == j['role'], orElse: () => UserRole.customer),
        email: j['email'] as String?,
        avatar: j['avatar'] as String?,
        defaultAddress: str(j['default_address']),
        workerProfileId: j['worker_profile_id'] as int?,
        language: j['language'] == 'ur' ? 'ur' : 'en',
        phoneVerified: j['phone_verified'] == true,
        bookingReminders: j['booking_reminders'] != false,
      );

  final int id;
  final String phone;
  final String fullName;
  final UserRole role;
  final String? email;
  final String? avatar;
  final String defaultAddress;
  final int? workerProfileId;

  /// 'en' or 'ur': the language the server writes this user's alerts in.
  final String language;

  /// Confirmed with an SMS code.
  final bool phoneVerified;

  /// Reminders the day before and an hour before a booked job.
  final bool bookingReminders;

  bool get isWorker => role == UserRole.worker;
  bool get isCustomer => role == UserRole.customer;
  bool get isAdmin => role == UserRole.admin;
  String get firstName => fullName.split(' ').first;
}

class ServiceCategory {
  ServiceCategory({required this.id, required this.name, this.description = '', this.icon = ''});
  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
      id: parseInt(j['id']), name: str(j['name']), description: str(j['description']), icon: str(j['icon']));
  final int id;
  final String name;
  final String description;
  final String icon;
}

class WorkerServiceInline {
  WorkerServiceInline({required this.id, required this.category, required this.categoryName,
      this.description = '', this.startingPrice, this.isActive = true});
  factory WorkerServiceInline.fromJson(Map<String, dynamic> j) => WorkerServiceInline(
        id: parseInt(j['id']),
        category: parseInt(j['category']),
        categoryName: str(j['category_name']),
        description: str(j['description']),
        startingPrice: j['starting_price'] as String?,
        isActive: j['is_active'] != false,
      );
  final int id;
  final int category;
  final String categoryName;
  final String description;
  final String? startingPrice;
  final bool isActive;
}

/// Public worker card (never contains phone, CNIC or home location).
class PublicWorker {
  PublicWorker({required this.id, required this.fullName, this.profilePicture, this.bio = '',
      this.experienceYears = 0, this.serviceArea = '', this.isVerified = false, this.averageRating = '0.00',
      this.ratingCount = 0, this.completedJobs = 0, this.planBadge = '', this.services = const [],
      this.distanceKm, this.isAvailable, this.isSponsored = false, this.workingHours = const [],
      this.isFavourite = false, this.lastBookedAt, this.portfolio = const []});

  factory PublicWorker.fromJson(Map<String, dynamic> j) => PublicWorker(
        id: parseInt(j['id']),
        fullName: str(j['full_name']),
        profilePicture: j['profile_picture'] as String?,
        bio: str(j['bio']),
        experienceYears: parseInt(j['experience_years']),
        serviceArea: str(j['service_area']),
        isVerified: j['is_verified'] == true,
        averageRating: str(j['average_rating']).isEmpty ? '0.00' : str(j['average_rating']),
        ratingCount: parseInt(j['rating_count']),
        completedJobs: parseInt(j['completed_jobs_count']),
        planBadge: str(j['plan_badge']),
        services: parseList(j['services'], WorkerServiceInline.fromJson),
        distanceKm: parseDouble(j['distance_km']),
        isAvailable: j['is_available'] as bool?,
        isSponsored: j['is_sponsored'] == true,
        workingHours: parseList(j['working_hours'], WorkingHours.fromJson),
        isFavourite: j['is_favourite'] == true,
        portfolio: parseList(j['portfolio'], PortfolioPhoto.fromJson),
        lastBookedAt: parseDate(j['last_booked_at']),
      );

  final int id;
  final String fullName;
  final String? profilePicture;
  final String bio;
  final int experienceYears;
  final String serviceArea;
  final bool isVerified;
  final String averageRating;
  final int ratingCount;
  final int completedJobs;
  final String planBadge;
  final List<WorkerServiceInline> services;
  final double? distanceKm;
  final bool? isAvailable;
  final bool isSponsored;

  /// Weekly hours; empty means the worker takes jobs at any time.
  final List<WorkingHours> workingHours;

  /// Whether the signed-in customer saved this worker (worker profile and My workers only).
  final bool isFavourite;

  /// Photos of past work (profile page only).
  final List<PortfolioPhoto> portfolio;

  /// When this worker last finished a job for the customer (My workers only).
  final DateTime? lastBookedAt;

  List<WorkerServiceInline> get activeServices => services.where((s) => s.isActive).toList();
}

class WorkerProfile {
  WorkerProfile({required this.id, required this.fullName, required this.phone, this.cnicNumber = '',
      this.bio = '', this.experienceYears = 0, this.profilePicture, this.baseLatitude, this.baseLongitude,
      this.serviceArea = '', this.serviceRadiusKm = '10', this.isAvailable = false,
      this.verificationStatus = 'pending', this.rejectionReason = '', this.averageRating = '0.00',
      this.ratingCount = 0, this.completedJobs = 0, this.services = const [], this.documentsUploaded = const []});

  factory WorkerProfile.fromJson(Map<String, dynamic> j) => WorkerProfile(
        id: parseInt(j['id']),
        fullName: str(j['full_name']),
        phone: str(j['phone']),
        cnicNumber: str(j['cnic_number']),
        bio: str(j['bio']),
        experienceYears: parseInt(j['experience_years']),
        profilePicture: j['profile_picture'] as String?,
        baseLatitude: parseDouble(j['base_latitude']),
        baseLongitude: parseDouble(j['base_longitude']),
        serviceArea: str(j['service_area']),
        serviceRadiusKm: str(j['service_radius_km']),
        isAvailable: j['is_available'] == true,
        verificationStatus: str(j['verification_status']),
        rejectionReason: str(j['rejection_reason']),
        averageRating: str(j['average_rating']),
        ratingCount: parseInt(j['rating_count']),
        completedJobs: parseInt(j['completed_jobs_count']),
        services: parseList(j['services'], WorkerServiceInline.fromJson),
        documentsUploaded: (j['documents_uploaded'] as List? ?? const []).map((e) => '$e').toList(),
      );

  final int id;
  final String fullName;
  final String phone;
  final String cnicNumber;
  final String bio;
  final int experienceYears;
  final String? profilePicture;
  final double? baseLatitude;
  final double? baseLongitude;
  final String serviceArea;
  final String serviceRadiusKm;
  final bool isAvailable;
  final String verificationStatus;
  final String rejectionReason;
  final String averageRating;
  final int ratingCount;
  final int completedJobs;
  final List<WorkerServiceInline> services;
  final List<String> documentsUploaded;

  bool get isVerified => verificationStatus == 'verified';
}

class WorkerDocument {
  WorkerDocument({required this.id, required this.documentType, required this.filename, required this.status});
  factory WorkerDocument.fromJson(Map<String, dynamic> j) => WorkerDocument(
      id: parseInt(j['id']),
      documentType: str(j['document_type']),
      filename: str(j['original_filename']),
      status: str(j['status']));
  final int id;
  final String documentType;
  final String filename;
  final String status;
}

class ServiceRequest {
  ServiceRequest({required this.id, required this.category, required this.categoryName, required this.title,
      required this.description, required this.latitude, required this.longitude, this.address = '',
      this.area = '', this.preferredTime, this.budget, this.isEmergency = false, this.emergencyFee = '0.00',
      required this.status, this.images = const [], this.offersCount = 0, this.bookingId,
      this.matchedWorkersCount, this.cancelReason = '', this.createdAt, this.durationMinutes = 120,
      this.invitedWorkerId, this.invitedWorkerName = '', this.isDirect = false});

  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
        id: parseInt(j['id']),
        category: parseInt(j['category']),
        categoryName: str(j['category_name']),
        title: str(j['title']),
        description: str(j['description']),
        latitude: parseDouble(j['latitude']),
        longitude: parseDouble(j['longitude']),
        address: str(j['address']),
        area: str(j['area']),
        preferredTime: parseDate(j['preferred_time']),
        durationMinutes: parseInt(j['duration_minutes'], 120),
        budget: j['budget'] as String?,
        isEmergency: j['is_emergency'] == true,
        emergencyFee: str(j['emergency_fee']),
        status: str(j['status']),
        images: parseList(j['images'], (m) => str(m['image'])),
        offersCount: parseInt(j['offers_count']),
        bookingId: j['booking_id'] as int?,
        matchedWorkersCount: j['matched_workers_count'] as int?,
        cancelReason: str(j['cancel_reason']),
        createdAt: parseDate(j['created_at']),
        invitedWorkerId: j['invited_worker'] is Map ? parseInt((j['invited_worker'] as Map)['id']) : null,
        invitedWorkerName: j['invited_worker'] is Map ? str((j['invited_worker'] as Map)['full_name']) : '',
        isDirect: j['is_direct'] == true,
      );

  /// Customer side: the one worker this job was sent to (book again), null when open to everyone.
  final int? invitedWorkerId;
  final String invitedWorkerName;

  /// Worker side: the customer asked for you by name.
  final bool isDirect;

  final int id;
  final int category;
  final String categoryName;
  final String title;
  final String description;
  final double? latitude;
  final double? longitude;
  final String address;
  final String area;
  final DateTime? preferredTime;
  final int durationMinutes;
  final String? budget;
  final bool isEmergency;
  final String emergencyFee;
  final String status;
  final List<String> images;
  final int offersCount;
  final int? bookingId;
  final int? matchedWorkersCount;
  final String cancelReason;
  final DateTime? createdAt;

  bool get isOpen => status == 'open';
}

class Negotiation {
  Negotiation({required this.party, required this.action, this.amount, this.message = '', this.createdAt});
  factory Negotiation.fromJson(Map<String, dynamic> j) => Negotiation(
      party: str(j['party']),
      action: str(j['action']),
      amount: j['amount'] as String?,
      message: str(j['message']),
      createdAt: parseDate(j['created_at']));
  final String party;
  final String action;
  final String? amount;
  final String message;
  final DateTime? createdAt;
}

class WorkerOffer {
  WorkerOffer({required this.id, required this.requestId, required this.worker, required this.initialPrice,
      required this.currentPrice, required this.awaiting, required this.etaMinutes, this.message = '',
      this.additionalInfo = '', this.distanceKm, required this.status, this.negotiations = const [],
      this.bookingId, this.createdAt});

  factory WorkerOffer.fromJson(Map<String, dynamic> j) => WorkerOffer(
        id: parseInt(j['id']),
        requestId: parseInt(j['request']),
        worker: PublicWorker.fromJson(asMap(j['worker'])),
        initialPrice: str(j['initial_price']),
        currentPrice: str(j['current_price']),
        awaiting: str(j['awaiting']),
        etaMinutes: parseInt(j['estimated_arrival_minutes']),
        message: str(j['message']),
        additionalInfo: str(j['additional_info']),
        distanceKm: parseDouble(j['distance_km']),
        status: str(j['status']),
        negotiations: parseList(j['negotiations'], Negotiation.fromJson),
        bookingId: j['booking_id'] as int?,
        createdAt: parseDate(j['created_at']),
      );

  final int id;
  final int requestId;
  final PublicWorker worker;
  final String initialPrice;
  final String currentPrice;
  final String awaiting; // "customer" or "worker": whose turn it is
  final int etaMinutes;
  final String message;
  final String additionalInfo;
  final double? distanceKm;
  final String status;
  final List<Negotiation> negotiations;
  final int? bookingId;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
}

class BookingStatusLog {
  BookingStatusLog({required this.toStatus, this.fromStatus = '', this.note = '', this.createdAt});
  factory BookingStatusLog.fromJson(Map<String, dynamic> j) => BookingStatusLog(
      toStatus: str(j['to_status']),
      fromStatus: str(j['from_status']),
      note: str(j['note']),
      createdAt: parseDate(j['created_at']));
  final String toStatus;
  final String fromStatus;
  final String note;
  final DateTime? createdAt;
}

class Booking {
  Booking({required this.id, required this.requestId, required this.title, required this.categoryName,
      this.preferredTime, required this.agreedPrice, required this.emergencyFee, required this.totalAmount,
      required this.status, required this.worker, required this.customerName, this.contact = const {},
      this.cancelReason = '', this.completedAt, this.statusHistory = const [], this.commission,
      this.hasReview = false, this.createdAt, this.durationMinutes = 120, this.noShowReported,
      this.canReportNoShow, this.noShowOpensAt, this.canSos = false, this.sosStatus, this.sharingUntil});

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: parseInt(j['id']),
        requestId: parseInt(j['request_id']),
        title: str(j['title']),
        categoryName: str(j['category_name']),
        preferredTime: parseDate(j['preferred_time']),
        durationMinutes: parseInt(j['duration_minutes'], 120),
        agreedPrice: str(j['agreed_price']),
        emergencyFee: str(j['emergency_fee']),
        totalAmount: str(j['total_amount']),
        status: str(j['status']),
        worker: PublicWorker.fromJson(asMap(j['worker'])),
        customerName: str(j['customer_name']),
        contact: asMap(j['contact']),
        cancelReason: str(j['cancel_reason']),
        completedAt: parseDate(j['completed_at']),
        statusHistory: parseList(j['status_history'], BookingStatusLog.fromJson),
        commission: j['commission'] == null ? null : asMap(j['commission']),
        hasReview: j['has_review'] == true,
        noShowReported: asMap(j['no_show'])['reported'] as String?,
        canReportNoShow: asMap(j['no_show'])['you_can_report'] as String?,
        noShowOpensAt: parseDate(asMap(j['no_show'])['opens_at']),
        canSos: asMap(j['safety'])['can_sos'] == true,
        sosStatus: asMap(j['safety'])['sos_status'] as String?,
        sharingUntil: parseDate(asMap(j['safety'])['sharing_until']),
        createdAt: parseDate(j['created_at']),
      );

  final int id;
  final int requestId;
  final String title;
  final String categoryName;
  final DateTime? preferredTime;
  final int durationMinutes;
  final String agreedPrice;
  final String emergencyFee;
  final String totalAmount;
  final String status;
  final PublicWorker worker;
  final String customerName;
  final Map<String, dynamic> contact;
  final String cancelReason;
  final DateTime? completedAt;
  final List<BookingStatusLog> statusHistory;
  final Map<String, dynamic>? commission;
  final bool hasReview;

  /// 'worker' or 'customer' when that side was reported as a no-show.
  final String? noShowReported;

  /// Who the signed-in user may report as a no-show ('worker' or 'customer'), from [noShowOpensAt].
  final String? canReportNoShow;

  /// The SOS button is shown (during the job and up to an hour after).
  final bool canSos;

  /// The viewer's own SOS: open or acknowledged, null when none is open.
  final String? sosStatus;

  /// When the viewer's trip-sharing link stops working, or null when not shared.
  final DateTime? sharingUntil;
  final DateTime? noShowOpensAt;
  final DateTime? createdAt;

  static const activeStatuses = {'confirmed', 'on_the_way', 'arrived', 'in_progress'};
  bool get isActive => activeStatuses.contains(status);
  bool get isCompleted => status == 'completed';

  /// The next status a worker can move to, or null.
  String? get nextWorkerStatus => switch (status) {
        'confirmed' => 'on_the_way',
        'on_the_way' => 'arrived',
        'arrived' => 'in_progress',
        _ => null,
      };
}

class ChatMessage {
  ChatMessage({required this.id, required this.body, required this.isMine, this.isRead = false, this.createdAt});
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
      id: parseInt(j['id']),
      body: str(j['body']),
      isMine: j['is_mine'] == true,
      isRead: j['is_read'] == true,
      createdAt: parseDate(j['created_at']));

  /// WebSocket events do not know the viewer, so they carry `sender`; work out is_mine ourselves.
  factory ChatMessage.fromEvent(Map<String, dynamic> j, int myUserId) =>
      ChatMessage.fromJson({...j, 'is_mine': j['is_mine'] ?? (parseInt(j['sender']) == myUserId)});

  final int id;
  final String body;
  final bool isMine;
  final bool isRead;
  final DateTime? createdAt;
}

class LocationPoint {
  LocationPoint({required this.latitude, required this.longitude, this.distanceKm, this.etaMinutes,
      this.recordedAt, this.bookingStatus});
  factory LocationPoint.fromJson(Map<String, dynamic> j) => LocationPoint(
      latitude: parseDouble(j['latitude']) ?? 0,
      longitude: parseDouble(j['longitude']) ?? 0,
      distanceKm: parseDouble(j['distance_to_customer_km']),
      etaMinutes: j['eta_minutes'] == null ? null : parseInt(j['eta_minutes']),
      recordedAt: parseDate(j['recorded_at']),
      bookingStatus: j['booking_status'] as String?);
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final int? etaMinutes;
  final DateTime? recordedAt;
  final String? bookingStatus;
}

class LiveLocation {
  LiveLocation({this.latest, this.trail = const []});
  factory LiveLocation.fromJson(Map<String, dynamic> j) => LiveLocation(
      latest: j['latest'] == null ? null : LocationPoint.fromJson(asMap(j['latest'])),
      trail: parseList(j['trail'], LocationPoint.fromJson));
  final LocationPoint? latest;
  final List<LocationPoint> trail;
}

class Checkout {
  Checkout({required this.url, required this.method, required this.fields});
  factory Checkout.fromJson(Map<String, dynamic> j) => Checkout(
      url: str(j['url']),
      method: str(j['method']).isEmpty ? 'POST' : str(j['method']),
      fields: asMap(j['fields']).map((k, v) => MapEntry(k, '$v')));
  final String url;
  final String method;
  final Map<String, String> fields;
}

class Payment {
  Payment({required this.id, required this.purpose, this.bookingId, required this.amount, required this.method,
      required this.status, this.reference = '', this.failureReason = '', this.checkout, this.createdAt,
      this.refundedAmount = '0.00', this.discountAmount = '0.00'});
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: parseInt(j['id']),
        purpose: str(j['purpose']),
        bookingId: j['booking'] as int?,
        amount: str(j['amount']),
        method: str(j['method']),
        status: str(j['status']),
        reference: str(j['reference']),
        failureReason: str(j['failure_reason']),
        checkout: j['checkout'] == null ? null : Checkout.fromJson(asMap(j['checkout'])),
        createdAt: parseDate(j['created_at']),
        refundedAmount: j['refunded_amount'] == null ? '0.00' : str(j['refunded_amount']),
        discountAmount: j['discount_amount'] == null ? '0.00' : str(j['discount_amount']),
      );
  final int id;
  final String purpose;
  final int? bookingId;
  final String amount;
  final String method;
  final String status;
  final String reference;
  final String failureReason;
  final Checkout? checkout;
  final DateTime? createdAt;

  /// Money KaamNow sent back to the customer for this payment (0 when none).
  final String refundedAmount;
  bool get hasRefund => (double.tryParse(refundedAmount) ?? 0) > 0;

  /// Promo code and credit taken off the booking total (paid by KaamNow).
  final String discountAmount;
  bool get hasDiscount => (double.tryParse(discountAmount) ?? 0) > 0;
}

class AppNotification {
  AppNotification({required this.id, required this.type, required this.title, required this.body,
      this.data = const {}, this.isRead = false, this.createdAt});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
      id: parseInt(j['id']),
      type: str(j['type']),
      title: str(j['title']),
      body: str(j['body']),
      data: asMap(j['data']),
      isRead: j['is_read'] == true,
      createdAt: parseDate(j['created_at']));
  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;
}

class Review {
  Review({required this.id, required this.rating, this.comment = '', this.customerName = '',
      this.categoryName = '', this.createdAt});
  factory Review.fromJson(Map<String, dynamic> j) => Review(
      id: parseInt(j['id']),
      rating: parseInt(j['rating']),
      comment: str(j['comment']),
      customerName: str(j['customer_name']),
      categoryName: str(j['category_name']),
      createdAt: parseDate(j['created_at']));
  final int id;
  final int rating;
  final String comment;
  final String customerName;
  final String categoryName;
  final DateTime? createdAt;
}

class Commission {
  Commission({required this.bookingId, required this.gross, required this.ratePercent, required this.commission,
      required this.earning, required this.status, this.createdAt});
  factory Commission.fromJson(Map<String, dynamic> j) => Commission(
      bookingId: parseInt(j['booking']),
      gross: str(j['gross_amount']),
      ratePercent: str(j['rate_percent']),
      commission: str(j['commission_amount']),
      earning: str(j['worker_earning']),
      status: str(j['status']),
      createdAt: parseDate(j['created_at']));
  final int bookingId;
  final String gross;
  final String ratePercent;
  final String commission;
  final String earning;
  final String status;
  final DateTime? createdAt;
}

class EarningsSummary {
  EarningsSummary({required this.completedJobs, required this.gross, required this.commission, required this.net,
      required this.commissionPending, required this.commissionPercent, this.recent = const []});
  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
      completedJobs: parseInt(j['completed_jobs']),
      gross: str(j['gross_amount']),
      commission: str(j['commission_amount']),
      net: str(j['net_earnings']),
      commissionPending: str(j['commission_pending']),
      commissionPercent: str(j['current_commission_percent']),
      recent: parseList(j['recent'], Commission.fromJson));
  final int completedJobs;
  final String gross;
  final String commission;
  final String net;
  final String commissionPending;
  final String commissionPercent;
  final List<Commission> recent;
}

class SubscriptionPlan {
  SubscriptionPlan({required this.id, required this.name, required this.price, this.description = '',
      this.durationDays = 30, this.commissionPercent, this.dailyOfferLimit, this.benefits = const [],
      this.badge = '', this.isDefault = false, this.isActive = true, this.slug = ''});
  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
      id: parseInt(j['id']),
      name: str(j['name']),
      price: str(j['price']),
      description: str(j['description']),
      durationDays: parseInt(j['duration_days'], 30),
      commissionPercent: j['commission_percent'] as String?,
      dailyOfferLimit: j['daily_offer_limit'] as int?,
      benefits: j['benefits'] is List ? (j['benefits'] as List).map((e) => '$e').toList() : const [],
      badge: str(j['badge']),
      isDefault: j['is_default'] == true,
      isActive: j['is_active'] != false,
      slug: str(j['slug']));
  final int id;
  final String name;
  final String price;
  final String description;
  final int durationDays;
  final String? commissionPercent;
  final int? dailyOfferLimit;
  final List<String> benefits;
  final String badge;
  final bool isDefault;
  final bool isActive;
  final String slug;
}

class MySubscription {
  MySubscription({required this.plan, this.endsAt, required this.offersToday, this.offersRemaining,
      required this.commissionPercent});
  factory MySubscription.fromJson(Map<String, dynamic> j) => MySubscription(
      plan: SubscriptionPlan.fromJson(asMap(j['plan'])),
      endsAt: parseDate(asMap(j['subscription'])['ends_at']),
      offersToday: parseInt(j['offers_today']),
      offersRemaining: j['offers_remaining_today'] as int?,
      commissionPercent: str(j['commission_percent']));
  final SubscriptionPlan plan;
  final DateTime? endsAt;
  final int offersToday;
  final int? offersRemaining;
  final String commissionPercent;
}

class Complaint {
  Complaint({required this.id, this.bookingId, required this.category, required this.subject,
      required this.description, required this.status, this.resolution = '', this.createdAt});
  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
      id: parseInt(j['id']),
      bookingId: j['booking'] as int?,
      category: str(j['category']),
      subject: str(j['subject']),
      description: str(j['description']),
      status: str(j['status']),
      resolution: str(j['resolution']),
      createdAt: parseDate(j['created_at']));
  final int id;
  final int? bookingId;
  final String category;
  final String subject;
  final String description;
  final String status;
  final String resolution;
  final DateTime? createdAt;
}

class PaymentMethodOption {
  PaymentMethodOption({required this.code, required this.label, required this.available});
  factory PaymentMethodOption.fromJson(Map<String, dynamic> j) =>
      PaymentMethodOption(code: str(j['code']), label: str(j['label']), available: j['available'] == true);
  final String code;
  final String label;
  final bool available;
}

class ClientConfig {
  ClientConfig({required this.cityLat, required this.cityLng, required this.emergencyEnabled,
      required this.emergencyFee, required this.paymentMethods, required this.minOfferPrice,
      required this.minWebVersion, this.supportEmail = '', this.supportPhone = '',
      this.webPushEnabled = false, this.webPushPublicKey = '', this.phonePushEnabled = false,
      this.phoneVerificationRequired = false,
      this.smsAvailable = false, this.googleMapsBrowserKey = ''});
  factory ClientConfig.fromJson(Map<String, dynamic> j) {
    final city = asMap(j['city']);
    final em = asMap(j['emergency']);
    return ClientConfig(
      cityLat: parseDouble(city['latitude']) ?? 31.5204,
      cityLng: parseDouble(city['longitude']) ?? 74.3587,
      emergencyEnabled: em['enabled'] == true,
      emergencyFee: str(em['fee']),
      paymentMethods: parseList(j['payment_methods'], PaymentMethodOption.fromJson),
      minOfferPrice: str(asMap(j['offer_price'])['min']),
      minWebVersion: str(asMap(j['min_supported_version'])['web']),
      supportEmail: str(asMap(j['support'])['email']),
      supportPhone: str(asMap(j['support'])['phone']),
      webPushEnabled: asMap(j['web_push'])['enabled'] == true,
      webPushPublicKey: str(asMap(j['web_push'])['public_key']),
      phonePushEnabled: j['push_enabled'] == true,
      googleMapsBrowserKey: str(asMap(j['maps'])['google_browser_key']),
      phoneVerificationRequired: asMap(j['phone_verification'])['required'] == true,
      smsAvailable: asMap(j['phone_verification'])['sms_available'] == true,
    );
  }
  static ClientConfig fallback() => ClientConfig(cityLat: 31.5204, cityLng: 74.3587, emergencyEnabled: false,
      emergencyFee: '0.00', paymentMethods: [PaymentMethodOption(code: 'cash', label: 'Cash', available: true)],
      minOfferPrice: '100', minWebVersion: '1.0.0');
  final double cityLat;
  final double cityLng;
  final bool emergencyEnabled;
  final String emergencyFee;
  final List<PaymentMethodOption> paymentMethods;
  final String minOfferPrice;
  final String minWebVersion;
  final String supportEmail;
  final String supportPhone;
  final bool webPushEnabled;
  final String webPushPublicKey;

  /// The server can send Firebase push to the Android and iPhone apps.
  final bool phonePushEnabled;

  /// Google Maps key for the web app (restricted to the site's address); empty when not set up.
  final String googleMapsBrowserKey;

  /// Customers and workers must confirm their number by SMS before using the app.
  final bool phoneVerificationRequired;

  /// The server can send SMS codes (also used for "Forgot password").
  final bool smsAvailable;
}

/// A payout to a worker, or a commission payment from one (see the server's wallet.py).
class Settlement {
  Settlement({required this.id, required this.kind, required this.status, required this.amount,
      this.earningsAmount = '0', this.commissionAmount = '0', this.method = '', this.accountTitle = '',
      this.accountNumber = '', this.reference = '', this.note = '', this.workerId = 0, this.workerName = '',
      this.workerPhone = '', this.bookings = const [], this.createdAt, this.processedAt});
  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
      id: parseInt(j['id']),
      kind: str(j['kind']),
      status: str(j['status']),
      amount: str(j['amount']),
      earningsAmount: str(j['earnings_amount']),
      commissionAmount: str(j['commission_amount']),
      method: str(j['method']),
      accountTitle: str(j['account_title']),
      accountNumber: str(j['account_number']),
      reference: str(j['reference']),
      note: str(j['note']),
      workerId: parseInt(j['worker']),
      workerName: str(j['worker_name']),
      workerPhone: str(j['worker_phone']),
      bookings: [for (final b in (j['bookings'] is List ? j['bookings'] as List : const [])) parseInt(b)],
      createdAt: parseDate(j['created_at']),
      processedAt: parseDate(j['processed_at']));
  final int id;
  final String kind;
  final String status;
  final String amount;
  final String earningsAmount;
  final String commissionAmount;
  final String method;
  final String accountTitle;
  final String accountNumber;
  final String reference;
  final String note;
  final int workerId;
  final String workerName;
  final String workerPhone;
  final List<int> bookings;
  final DateTime? createdAt;
  final DateTime? processedAt;
  bool get isPayout => kind == 'payout';
  bool get isOpen => status == 'requested';
}

class PayoutAccount {
  const PayoutAccount({required this.method, required this.accountTitle, required this.accountNumber});
  factory PayoutAccount.fromJson(Map<String, dynamic> j) => PayoutAccount(
      method: str(j['method']), accountTitle: str(j['account_title']), accountNumber: str(j['account_number']));
  final String method;
  final String accountTitle;
  final String accountNumber;
}

class Wallet {
  Wallet({required this.earningsHeld, required this.commissionOwed, required this.balance, required this.minPayout,
      this.commissionDebtLimit = '0', this.canRequestPayout = false, this.mustPayCommission = false,
      this.offersBlocked = false, this.openSettlement, this.lastPayoutAccount, this.settlements = const []});
  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
      earningsHeld: str(j['earnings_held']),
      commissionOwed: str(j['commission_owed']),
      balance: str(j['balance']),
      minPayout: str(j['min_payout']),
      commissionDebtLimit: str(j['commission_debt_limit']),
      canRequestPayout: j['can_request_payout'] == true,
      mustPayCommission: j['must_pay_commission'] == true,
      offersBlocked: j['offers_blocked'] == true,
      openSettlement: j['open_settlement'] == null ? null : Settlement.fromJson(asMap(j['open_settlement'])),
      lastPayoutAccount:
          j['last_payout_account'] == null ? null : PayoutAccount.fromJson(asMap(j['last_payout_account'])),
      settlements: parseList(j['settlements'], Settlement.fromJson));
  final String earningsHeld;
  final String commissionOwed;
  final String balance;
  final String minPayout;
  final String commissionDebtLimit;
  final bool canRequestPayout;
  final bool mustPayCommission;
  final bool offersBlocked;
  final Settlement? openSettlement;
  final PayoutAccount? lastPayoutAccount;
  final List<Settlement> settlements;
  double get balanceValue => double.tryParse(balance) ?? 0;
}

/// What a customer would pay for a booking with a promo code and/or credit (`POST promos/check/`).
class PaymentQuote {
  PaymentQuote({required this.total, this.promoCode = '', this.promoDescription = '', this.promoDiscount = '0.00',
      this.creditBalance = '0.00', this.creditUsed = '0.00', this.discount = '0.00', required this.amount});
  factory PaymentQuote.fromJson(Map<String, dynamic> j) => PaymentQuote(
        total: str(j['total']),
        promoCode: str(j['promo_code']),
        promoDescription: str(j['promo_description']),
        promoDiscount: str(j['promo_discount']),
        creditBalance: str(j['credit_balance']),
        creditUsed: str(j['credit_used']),
        discount: str(j['discount']),
        amount: str(j['amount']),
      );
  final String total;
  final String promoCode;
  final String promoDescription;
  final String promoDiscount;
  final String creditBalance;
  final String creditUsed;
  final String discount;
  final String amount;

  static bool _positive(String v) => (double.tryParse(v) ?? 0) > 0;
  bool get hasCredit => _positive(creditBalance);
  bool get hasDiscount => _positive(discount);
  bool get hasPromo => promoCode.isNotEmpty;
  bool get usesCredit => _positive(creditUsed);
}

class CreditEntry {
  CreditEntry({required this.id, required this.amount, required this.kind, this.note = '', this.createdAt});
  factory CreditEntry.fromJson(Map<String, dynamic> j) => CreditEntry(
        id: parseInt(j['id']),
        amount: str(j['amount']),
        kind: str(j['kind']),
        note: str(j['note']),
        createdAt: parseDate(j['created_at']),
      );
  final int id;
  final String amount;
  final String kind;
  final String note;
  final DateTime? createdAt;
}

/// The user's invite code, credit and invite rewards (`GET referrals/me/`).
class ReferralSummary {
  ReferralSummary({required this.code, required this.inviteLink, this.creditBalance = '0.00', this.invited = 0,
      this.rewarded = 0, this.rewardsEarned = '0.00', this.referralReward = '0.00', this.welcomeCredit = '0.00',
      this.minBooking = '0.00', this.creditHistory = const []});
  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        code: str(j['code']),
        inviteLink: str(j['invite_link']),
        creditBalance: str(j['credit_balance']),
        invited: parseInt(j['invited']),
        rewarded: parseInt(j['rewarded']),
        rewardsEarned: str(j['rewards_earned']),
        referralReward: str(j['referral_reward']),
        welcomeCredit: str(j['welcome_credit']),
        minBooking: str(j['min_booking']),
        creditHistory: [for (final e in (j['credit_history'] as List? ?? const [])) CreditEntry.fromJson(asMap(e))],
      );
  final String code;
  final String inviteLink;
  final String creditBalance;
  final int invited;
  final int rewarded;
  final String rewardsEarned;
  final String referralReward;
  final String welcomeCredit;
  final String minBooking;
  final List<CreditEntry> creditHistory;
}


// ---- Availability (Stage 17) -------------------------------------------------

/// One working day: weekday 0 = Monday .. 6 = Sunday, times as "HH:MM" (Pakistan time).
class WorkingHours {
  const WorkingHours({required this.weekday, required this.start, required this.end});

  factory WorkingHours.fromJson(Map<String, dynamic> j) =>
      WorkingHours(weekday: parseInt(j['weekday']), start: str(j['start']), end: str(j['end']));

  final int weekday;
  final String start;
  final String end;

  Map<String, dynamic> toJson() => {'weekday': weekday, 'start': start, 'end': end};
}

class TimeOffEntry {
  TimeOffEntry({required this.id, required this.startDate, required this.endDate, this.reason = ''});

  factory TimeOffEntry.fromJson(Map<String, dynamic> j) => TimeOffEntry(
        id: parseInt(j['id']),
        startDate: DateTime.parse(str(j['start_date'])),
        endDate: DateTime.parse(str(j['end_date'])),
        reason: str(j['reason']),
      );

  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
}

/// The worker's own schedule (`GET workers/me/schedule/`).
class WorkerSchedule {
  WorkerSchedule({this.hours = const [], this.timeOff = const []});

  factory WorkerSchedule.fromJson(Map<String, dynamic> j) => WorkerSchedule(
        hours: parseList(j['hours'], WorkingHours.fromJson),
        timeOff: parseList(j['time_off'], TimeOffEntry.fromJson),
      );

  final List<WorkingHours> hours;
  final List<TimeOffEntry> timeOff;
}

/// A bookable time slot with how many matching workers nearby are free (`GET requests/slots/`).
class TimeSlot {
  TimeSlot({required this.start, required this.end, required this.freeWorkers});

  factory TimeSlot.fromJson(Map<String, dynamic> j) => TimeSlot(
        start: parseDate(j['start'])!,
        end: parseDate(j['end'])!,
        freeWorkers: parseInt(j['free_workers']),
      );

  final DateTime start;
  final DateTime end;
  final int freeWorkers;
}

/// One of a worker's 2-hour slots and whether they are free (`GET workers/{id}/slots/`).
class WorkerSlot {
  WorkerSlot({required this.start, required this.end, required this.free});

  factory WorkerSlot.fromJson(Map<String, dynamic> j) =>
      WorkerSlot(start: parseDate(j['start'])!, end: parseDate(j['end'])!, free: j['free'] == true);

  final DateTime start;
  final DateTime end;
  final bool free;
}

/// One visit of a repeating job and the request posted for it.
class RecurringVisit {
  RecurringVisit({required this.id, this.scheduledFor, required this.outcome, this.note = '', this.requestId,
      this.bookingId});

  factory RecurringVisit.fromJson(Map<String, dynamic> j) => RecurringVisit(
        id: parseInt(j['id']),
        scheduledFor: parseDate(j['scheduled_for']),
        outcome: str(j['outcome']),
        note: str(j['note']),
        requestId: j['request_id'] == null ? null : parseInt(j['request_id']),
        bookingId: j['booking_id'] == null ? null : parseInt(j['booking_id']),
      );

  final int id;
  final DateTime? scheduledFor;

  /// worker (sent to the usual worker), all (sent to every worker nearby) or failed.
  final String outcome;
  final String note;
  final int? requestId;
  final int? bookingId;
}

/// A job that repeats every week, every two weeks or every month, normally with the same worker.
///
/// The customer sees everything. The worker sees no address: [customerName] and [area] only.
class RecurringJob {
  RecurringJob({required this.id, required this.title, required this.categoryName, this.area = '',
      this.address = '', this.durationMinutes = 120, this.budget, required this.frequency, this.nextVisit,
      required this.status, this.workerId, this.workerName, this.customerName = '', this.recentVisits = const []});

  factory RecurringJob.fromJson(Map<String, dynamic> j) {
    final w = j['worker'] == null ? null : asMap(j['worker']);
    return RecurringJob(
      id: parseInt(j['id']),
      title: str(j['title']),
      categoryName: str(j['category_name']),
      area: str(j['area']),
      address: str(j['address']),
      durationMinutes: parseInt(j['duration_minutes'], 120),
      budget: j['budget'] as String?,
      frequency: str(j['frequency']),
      nextVisit: parseDate(j['next_visit']),
      status: str(j['status']),
      workerId: w == null ? null : parseInt(w['id']),
      workerName: w == null ? null : str(w['full_name']),
      customerName: str(j['customer_name']),
      recentVisits: parseList(j['recent_visits'], RecurringVisit.fromJson),
    );
  }

  final int id;
  final String title;
  final String categoryName;
  final String area;
  final String address;
  final int durationMinutes;
  final String? budget;
  final String frequency;
  final DateTime? nextVisit;
  final String status;
  final int? workerId;
  final String? workerName;
  final String customerName;
  final List<RecurringVisit> recentVisits;

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
}

class EmergencyContact {
  EmergencyContact({required this.id, required this.name, required this.phone});
  factory EmergencyContact.fromJson(Map<String, dynamic> j) =>
      EmergencyContact(id: parseInt(j['id']), name: str(j['name']), phone: str(j['phone']));
  final int id;
  final String name;
  final String phone;
}

/// A private trip-sharing link. The url is only shown when it is made.
class TripShare {
  TripShare({required this.url, this.expiresAt, this.contactsTexted = 0});
  factory TripShare.fromJson(Map<String, dynamic> j) => TripShare(
      url: str(j['url']), expiresAt: parseDate(j['expires_at']), contactsTexted: parseInt(j['contacts_texted']));
  final String url;
  final DateTime? expiresAt;
  final int contactsTexted;
}

/// What family sees with a shared link: no phone numbers and no address.
class SharedJob {
  SharedJob({required this.title, required this.categoryName, this.area = '', required this.status,
      this.preferredTime, this.durationMinutes = 120, required this.sharedBy, this.customerName = '',
      required this.workerName, this.workerVerified = false, this.workerRating = '0', this.workerJobs = 0,
      this.workerLat, this.workerLng, this.locationAt, this.expiresAt});

  factory SharedJob.fromJson(Map<String, dynamic> j) {
    final w = asMap(j['worker']);
    final loc = j['worker_location'] == null ? null : asMap(j['worker_location']);
    return SharedJob(
      title: str(j['title']),
      categoryName: str(j['category_name']),
      area: str(j['area']),
      status: str(j['status']),
      preferredTime: parseDate(j['preferred_time']),
      durationMinutes: parseInt(j['duration_minutes'], 120),
      sharedBy: str(j['shared_by']),
      customerName: str(j['customer_name']),
      workerName: str(w['name']),
      workerVerified: w['is_verified'] == true,
      workerRating: str(w['average_rating']),
      workerJobs: parseInt(w['completed_jobs_count']),
      workerLat: loc == null ? null : double.tryParse(str(loc['latitude'])),
      workerLng: loc == null ? null : double.tryParse(str(loc['longitude'])),
      locationAt: loc == null ? null : parseDate(loc['recorded_at']),
      expiresAt: parseDate(j['expires_at']),
    );
  }

  final String title;
  final String categoryName;
  final String area;
  final String status;
  final DateTime? preferredTime;
  final int durationMinutes;
  final String sharedBy;
  final String customerName;
  final String workerName;
  final bool workerVerified;
  final String workerRating;
  final int workerJobs;
  final double? workerLat;
  final double? workerLng;
  final DateTime? locationAt;
  final DateTime? expiresAt;
}

/// A photo of a worker's past work. [isHidden] and [hiddenReason] are only sent to the worker and admins.
class PortfolioPhoto {
  PortfolioPhoto({required this.id, required this.image, this.caption = '', this.category, this.categoryName,
      this.fromJob = false, this.isHidden = false, this.hiddenReason = '', this.workerId, this.workerName = '',
      this.createdAt});
  factory PortfolioPhoto.fromJson(Map<String, dynamic> j) => PortfolioPhoto(
        id: parseInt(j['id']),
        image: str(j['image']),
        caption: str(j['caption']),
        category: j['category'] == null ? null : parseInt(j['category']),
        categoryName: j['category_name'] as String?,
        fromJob: j['from_job'] == true,
        isHidden: j['is_hidden'] == true,
        hiddenReason: str(j['hidden_reason']),
        workerId: j['worker'] == null ? null : parseInt(j['worker']),
        workerName: str(j['worker_name']),
        createdAt: parseDate(j['created_at']),
      );
  final int id;
  final String image;
  final String caption;
  final int? category;
  final String? categoryName;
  final bool fromJob;
  final bool isHidden;
  final String hiddenReason;
  final int? workerId;
  final String workerName;
  final DateTime? createdAt;
}

/// A place the customer posts jobs from. Only its owner sees it.
class SavedAddress {
  SavedAddress({required this.id, required this.label, this.name = '', required this.address, this.area = '',
      required this.latitude, required this.longitude, this.isDefault = false});
  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: parseInt(j['id']),
        label: str(j['label']),
        name: str(j['name']),
        address: str(j['address']),
        area: str(j['area']),
        latitude: double.tryParse(str(j['latitude'])) ?? 0,
        longitude: double.tryParse(str(j['longitude'])) ?? 0,
        isDefault: j['is_default'] == true,
      );
  final int id;

  /// home, work or other.
  final String label;
  final String name;
  final String address;
  final String area;
  final double latitude;
  final double longitude;
  final bool isDefault;
}

/// Money totals for a date range in an earnings report.
class ReportTotals {
  ReportTotals({this.jobs = 0, this.gross = '0', this.commission = '0', this.discount = '0', this.earnings = '0',
      this.adjustments = '0', this.net = '0'});
  factory ReportTotals.fromJson(Map<String, dynamic> j) => ReportTotals(
        jobs: parseInt(j['jobs']),
        gross: str(j['gross']),
        commission: str(j['commission']),
        discount: str(j['discount']),
        earnings: str(j['earnings']),
        adjustments: str(j['adjustments']),
        net: str(j['net']),
      );
  final int jobs;
  final String gross;
  final String commission;
  final String discount;

  /// From jobs only.
  final String earnings;

  /// Refund shares charged to the worker (negative) and other wallet changes.
  final String adjustments;

  /// earnings + adjustments.
  final String net;
}

class ReportBucket {
  ReportBucket({required this.start, this.jobs = 0, this.gross = '0', this.net = '0'});
  factory ReportBucket.fromJson(Map<String, dynamic> j) => ReportBucket(
      start: DateTime.parse(str(j['start'])), jobs: parseInt(j['jobs']), gross: str(j['gross']), net: str(j['net']));
  final DateTime start;
  final int jobs;
  final String gross;
  final String net;
}

class ServiceEarning {
  ServiceEarning({required this.category, required this.name, this.jobs = 0, this.net = '0'});
  factory ServiceEarning.fromJson(Map<String, dynamic> j) => ServiceEarning(
      category: parseInt(j['category']), name: str(j['name']), jobs: parseInt(j['jobs']), net: str(j['net']));
  final int category;
  final String name;
  final int jobs;
  final String net;
}

class EarningsReport {
  EarningsReport({required this.start, required this.end, required this.group, required this.totals,
      required this.averagePerJob, required this.previous, this.series = const [], this.byService = const [],
      this.byPayment = const {}});
  factory EarningsReport.fromJson(Map<String, dynamic> j) {
    final pay = asMap(j['by_payment']);
    return EarningsReport(
      start: DateTime.parse(str(j['start'])),
      end: DateTime.parse(str(j['end'])),
      group: str(j['group']),
      totals: ReportTotals.fromJson(asMap(j['totals'])),
      averagePerJob: str(j['average_per_job']),
      previous: ReportTotals.fromJson(asMap(j['previous'])),
      series: parseList(j['series'], ReportBucket.fromJson),
      byService: parseList(j['by_service'], ServiceEarning.fromJson),
      byPayment: {for (final k in ['cash', 'online', 'unpaid']) k: ReportTotals.fromJson(asMap(pay[k]))},
    );
  }
  final DateTime start;
  final DateTime end;

  /// day, week or month: the step of [series].
  final String group;
  final ReportTotals totals;
  final String averagePerJob;

  /// The same number of days just before [start].
  final ReportTotals previous;
  final List<ReportBucket> series;
  final List<ServiceEarning> byService;

  /// cash, online and unpaid.
  final Map<String, ReportTotals> byPayment;

  int get days => end.difference(start).inDays + 1;
}

class ReceiptLine {
  ReceiptLine(this.label, this.amount);
  final String label;
  final String amount;
}

class ReceiptRefund {
  ReceiptRefund({required this.date, required this.amount, this.reference = ''});
  final DateTime date;
  final String amount;
  final String reference;
}

/// A receipt for a completed payment. Labels in [lines] come from the server in the app's language.
class Receipt {
  Receipt({required this.number, this.issuedAt, required this.status, required this.purpose, this.bookingId,
      this.title = '', this.service = '', this.billedTo = '', this.worker = '', required this.method,
      this.methodLabel = '', this.transactionId = '', this.lines = const [], required this.total,
      this.refunds = const [], this.refunded = '0.00', required this.netPaid, this.company = 'KaamNow',
      this.companyAddress = '', this.taxNumber = ''});
  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
        number: str(j['number']),
        issuedAt: parseDate(j['issued_at']),
        status: str(j['status']),
        purpose: str(j['purpose']),
        bookingId: j['booking'] == null ? null : parseInt(j['booking']),
        title: str(j['title']),
        service: str(j['service']),
        billedTo: str(j['billed_to']),
        worker: str(j['worker']),
        method: str(j['method']),
        methodLabel: str(j['method_label']),
        transactionId: str(j['transaction_id']),
        lines: [for (final l in (j['lines'] as List? ?? const [])) ReceiptLine(str(l['label']), str(l['amount']))],
        total: str(j['total']),
        refunds: [
          for (final r in (j['refunds'] as List? ?? const []))
            ReceiptRefund(date: DateTime.parse(str(r['date'])), amount: str(r['amount']), reference: str(r['reference']))
        ],
        refunded: str(j['refunded']),
        netPaid: str(j['net_paid']),
        company: str(j['company']),
        companyAddress: str(j['company_address']),
        taxNumber: str(j['tax_number']),
      );
  final String number;
  final DateTime? issuedAt;
  final String status;
  final String purpose;
  final int? bookingId;
  final String title;
  final String service;
  final String billedTo;
  final String worker;
  final String method;
  final String methodLabel;
  final String transactionId;
  final List<ReceiptLine> lines;
  final String total;
  final List<ReceiptRefund> refunds;
  final String refunded;
  final String netPaid;
  final String company;
  final String companyAddress;
  final String taxNumber;
}
