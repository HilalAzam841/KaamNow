import 'json.dart';

export 'json.dart';

enum UserRole { customer, worker, admin }

class User {
  User({required this.id, required this.phone, required this.fullName, required this.role, this.email,
      this.avatar, this.defaultAddress = '', this.workerProfileId, this.language = 'en', this.phoneVerified = false});

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
      this.distanceKm, this.isAvailable, this.isSponsored = false});

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
      this.matchedWorkersCount, this.cancelReason = '', this.createdAt});

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
      );

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
      this.hasReview = false, this.createdAt});

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: parseInt(j['id']),
        requestId: parseInt(j['request_id']),
        title: str(j['title']),
        categoryName: str(j['category_name']),
        preferredTime: parseDate(j['preferred_time']),
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
        createdAt: parseDate(j['created_at']),
      );

  final int id;
  final int requestId;
  final String title;
  final String categoryName;
  final DateTime? preferredTime;
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
      required this.status, this.reference = '', this.failureReason = '', this.checkout, this.createdAt});
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
      this.smsAvailable = false});
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

  /// Customers and workers must confirm their number by SMS before using the app.
  final bool phoneVerificationRequired;

  /// The server can send SMS codes (also used for "Forgot password").
  final bool smsAvailable;
}
