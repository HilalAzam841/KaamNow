import 'models.dart';

class AdminUser {
  AdminUser({required this.id, required this.phone, required this.fullName, required this.role, this.email,
      this.isActive = true, this.isSuspended = false, this.suspendedReason = '', this.dateJoined, this.lastLogin});
  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: parseInt(j['id']),
        phone: str(j['phone']),
        fullName: str(j['full_name']),
        role: str(j['role']),
        email: j['email'] as String?,
        isActive: j['is_active'] != false,
        isSuspended: j['is_suspended'] == true,
        suspendedReason: str(j['suspended_reason']),
        dateJoined: parseDate(j['date_joined']),
        lastLogin: parseDate(j['last_login']),
      );
  final int id;
  final String phone;
  final String fullName;
  final String role;
  final String? email;
  final bool isActive;
  final bool isSuspended;
  final String suspendedReason;
  final DateTime? dateJoined;
  final DateTime? lastLogin;
}

class AdminDocument {
  AdminDocument({required this.id, required this.type, required this.filename, required this.status, this.createdAt});
  factory AdminDocument.fromJson(Map<String, dynamic> j) => AdminDocument(
      id: parseInt(j['id']),
      type: str(j['document_type']),
      filename: str(j['original_filename']),
      status: str(j['status']),
      createdAt: parseDate(j['created_at']));
  final int id;
  final String type;
  final String filename;
  final String status;
  final DateTime? createdAt;

  bool get isPdf => filename.toLowerCase().endsWith('.pdf');
}

/// A worker as admins see it: the full profile plus private documents.
class AdminWorker {
  AdminWorker({required this.profile, this.email, this.documents = const [], this.createdAt});
  factory AdminWorker.fromJson(Map<String, dynamic> j) => AdminWorker(
        profile: WorkerProfile.fromJson(j),
        email: j['email'] as String?,
        documents: parseList(j['documents'], AdminDocument.fromJson),
        createdAt: parseDate(j['created_at']),
      );
  final WorkerProfile profile;
  final String? email;
  final List<AdminDocument> documents;
  final DateTime? createdAt;

  bool get hasBothCnicSides =>
      documents.any((d) => d.type == 'cnic_front') && documents.any((d) => d.type == 'cnic_back');
}

class AdminComplaint {
  AdminComplaint({required this.complaint, required this.raisedByName, required this.raisedByRole,
      this.againstUserName, this.resolvedAt});
  factory AdminComplaint.fromJson(Map<String, dynamic> j) => AdminComplaint(
        complaint: Complaint.fromJson(j),
        raisedByName: str(j['raised_by_name']),
        raisedByRole: str(j['raised_by_role']),
        againstUserName: j['against_user_name'] as String?,
        resolvedAt: parseDate(j['resolved_at']),
      );
  final Complaint complaint;
  final String raisedByName;
  final String raisedByRole;
  final String? againstUserName;
  final DateTime? resolvedAt;
}

class AuditEntry {
  AuditEntry({required this.id, required this.actorName, required this.action, required this.targetType,
      required this.targetId, this.metadata = const {}, this.ip, this.createdAt});
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
      id: parseInt(j['id']),
      actorName: str(j['actor_name']),
      action: str(j['action']),
      targetType: str(j['target_type']),
      targetId: str(j['target_id']),
      metadata: asMap(j['metadata']),
      ip: j['ip_address'] as String?,
      createdAt: parseDate(j['created_at']));
  final int id;
  final String actorName;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> metadata;
  final String? ip;
  final DateTime? createdAt;
}

class AdminCommission {
  AdminCommission({required this.commission, required this.workerName});
  factory AdminCommission.fromJson(Map<String, dynamic> j) =>
      AdminCommission(commission: Commission.fromJson(j), workerName: str(j['worker_name']));
  final Commission commission;
  final String workerName;
}

class FeaturedPlan {
  FeaturedPlan({required this.id, required this.name, required this.durationDays, required this.price, this.isActive = true});
  factory FeaturedPlan.fromJson(Map<String, dynamic> j) => FeaturedPlan(
      id: parseInt(j['id']),
      name: str(j['name']),
      durationDays: parseInt(j['duration_days']),
      price: str(j['price']),
      isActive: j['is_active'] != false);
  final int id;
  final String name;
  final int durationDays;
  final String price;
  final bool isActive;
}

class AdminSubscription {
  AdminSubscription({required this.id, required this.workerName, required this.planName, required this.status,
      required this.amount, this.startsAt, this.endsAt, this.paymentMethod = '', this.createdAt});
  factory AdminSubscription.fromJson(Map<String, dynamic> j) => AdminSubscription(
        id: parseInt(j['id']),
        workerName: str(j['worker_name']),
        planName: str(asMap(j['plan'])['name']),
        status: str(j['status']),
        amount: str(j['amount']),
        startsAt: parseDate(j['starts_at']),
        endsAt: parseDate(j['ends_at']),
        paymentMethod: str(asMap(j['payment'])['method']),
        createdAt: parseDate(j['created_at']),
      );
  final int id;
  final String workerName;
  final String planName;
  final String status;
  final String amount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String paymentMethod;
  final DateTime? createdAt;
}

class AdminFeaturedListing {
  AdminFeaturedListing({required this.id, required this.workerName, required this.categoryName,
      required this.planName, required this.status, required this.amount, this.endsAt});
  factory AdminFeaturedListing.fromJson(Map<String, dynamic> j) => AdminFeaturedListing(
        id: parseInt(j['id']),
        workerName: str(j['worker_name']),
        categoryName: str(j['category_name']),
        planName: str(asMap(j['plan'])['name']),
        status: str(j['status']),
        amount: str(j['amount']),
        endsAt: parseDate(j['ends_at']),
      );
  final int id;
  final String workerName;
  final String categoryName;
  final String planName;
  final String status;
  final String amount;
  final DateTime? endsAt;
}

class PlatformSettings {
  PlatformSettings({required this.commissionPercent, required this.emergencyFee, required this.emergencyEnabled,
      this.minPayout = '500.00', this.commissionDebtLimit = '0.00', this.referralReward = '0.00',
      this.referralWelcomeCredit = '0.00', this.referralMinBooking = '0.00', this.maxDiscountPercent = '50.00',
      this.reminderSmsEnabled = false, this.noShowGraceMinutes = 30, this.cancellationFeeEnabled = true,
      this.cancellationFreeMinutes = 5, this.cancellationWindowMinutes = 120, this.lateCancellationFee = '200.00',
      this.onTheWayCancellationFee = '300.00', this.tipsEnabled = true, this.tipMaxAmount = '5000.00',
      this.tipWindowDays = 7, this.updatedAt});
  factory PlatformSettings.fromJson(Map<String, dynamic> j) => PlatformSettings(
      commissionPercent: str(j['commission_percent']),
      emergencyFee: str(j['emergency_fee']),
      emergencyEnabled: j['emergency_enabled'] == true,
      minPayout: j['min_payout'] == null ? '500.00' : str(j['min_payout']),
      commissionDebtLimit: j['commission_debt_limit'] == null ? '0.00' : str(j['commission_debt_limit']),
      referralReward: j['referral_reward'] == null ? '0.00' : str(j['referral_reward']),
      referralWelcomeCredit: j['referral_welcome_credit'] == null ? '0.00' : str(j['referral_welcome_credit']),
      referralMinBooking: j['referral_min_booking'] == null ? '0.00' : str(j['referral_min_booking']),
      maxDiscountPercent: j['max_discount_percent'] == null ? '50.00' : str(j['max_discount_percent']),
      reminderSmsEnabled: j['reminder_sms_enabled'] == true,
      noShowGraceMinutes: parseInt(j['no_show_grace_minutes'], 30),
      cancellationFeeEnabled: j['cancellation_fee_enabled'] != false,
      cancellationFreeMinutes: parseInt(j['cancellation_free_minutes'], 5),
      cancellationWindowMinutes: parseInt(j['cancellation_window_minutes'], 120),
      lateCancellationFee: j['late_cancellation_fee'] == null ? '200.00' : str(j['late_cancellation_fee']),
      onTheWayCancellationFee: j['on_the_way_cancellation_fee'] == null ? '300.00' : str(j['on_the_way_cancellation_fee']),
      tipsEnabled: j['tips_enabled'] != false,
      tipMaxAmount: j['tip_max_amount'] == null ? '5000.00' : str(j['tip_max_amount']),
      tipWindowDays: parseInt(j['tip_window_days'], 7),
      updatedAt: parseDate(j['updated_at']));
  final bool cancellationFeeEnabled;
  final int cancellationFreeMinutes;
  final int cancellationWindowMinutes;
  final String lateCancellationFee;
  final String onTheWayCancellationFee;
  final bool tipsEnabled;
  final String tipMaxAmount;
  final int tipWindowDays;
  final bool reminderSmsEnabled;
  final int noShowGraceMinutes;
  final String referralReward;
  final String referralWelcomeCredit;
  final String referralMinBooking;
  final String maxDiscountPercent;
  final String minPayout;
  final String commissionDebtLimit;
  final String commissionPercent;
  final String emergencyFee;
  final bool emergencyEnabled;
  final DateTime? updatedAt;
}

class WorkerBalance {
  WorkerBalance({required this.workerId, required this.workerName, required this.workerPhone,
      required this.earningsHeld, required this.commissionOwed, required this.balance});
  factory WorkerBalance.fromJson(Map<String, dynamic> j) => WorkerBalance(
      workerId: parseInt(j['worker']),
      workerName: str(j['worker_name']),
      workerPhone: str(j['worker_phone']),
      earningsHeld: str(j['earnings_held']),
      commissionOwed: str(j['commission_owed']),
      balance: str(j['balance']));
  final int workerId;
  final String workerName;
  final String workerPhone;
  final String earningsHeld;
  final String commissionOwed;
  final String balance;
}

class AdminRefund {
  AdminRefund({required this.id, required this.amount, required this.workerShare, required this.method,
      required this.reason, required this.reference, this.complaintId, this.createdByName = '', this.createdAt});
  factory AdminRefund.fromJson(Map<String, dynamic> j) => AdminRefund(
        id: parseInt(j['id']),
        amount: str(j['amount']),
        workerShare: str(j['worker_share']),
        method: str(j['method']),
        reason: str(j['reason']),
        reference: str(j['reference']),
        complaintId: j['complaint'] as int?,
        createdByName: str(j['created_by_name']),
        createdAt: parseDate(j['created_at']),
      );
  final int id;
  final String amount;
  final String workerShare;
  final String method;
  final String reason;
  final String reference;
  final int? complaintId;
  final String createdByName;
  final DateTime? createdAt;
}

/// A payment as admins see it (with who paid, the gateway transaction and refunds).
class AdminPayment {
  AdminPayment({required this.payment, required this.payerName, required this.payerPhone, this.workerName,
      this.gatewayTransactionId = '', this.refundableAmount = '0.00', this.refunds = const []});
  factory AdminPayment.fromJson(Map<String, dynamic> j) => AdminPayment(
        payment: Payment.fromJson(j),
        payerName: str(j['payer_name']),
        payerPhone: str(j['payer_phone']),
        workerName: j['worker_name'] as String?,
        gatewayTransactionId: str(j['gateway_transaction_id']),
        refundableAmount: j['refundable_amount'] == null ? '0.00' : str(j['refundable_amount']),
        refunds: [for (final r in (j['refunds'] as List? ?? const [])) AdminRefund.fromJson(asMap(r))],
      );
  final Payment payment;
  final String payerName;
  final String payerPhone;
  final String? workerName;
  final String gatewayTransactionId;
  final String refundableAmount;
  final List<AdminRefund> refunds;

  int get id => payment.id;
  bool get canRefund => (double.tryParse(refundableAmount) ?? 0) > 0;
  bool get isDisputed => payment.status == 'disputed';
}

class AdminPromoCode {
  AdminPromoCode({required this.id, required this.code, this.description = '', required this.kind, required this.value,
      this.maxDiscount, this.minOrder = '0.00', this.categoryId, this.categoryName, this.startsAt, this.endsAt,
      this.maxUses, this.maxUsesPerUser = 1, this.firstBookingOnly = false, this.isActive = true, this.uses = 0,
      this.discountGiven = '0.00'});
  factory AdminPromoCode.fromJson(Map<String, dynamic> j) => AdminPromoCode(
        id: parseInt(j['id']),
        code: str(j['code']),
        description: str(j['description']),
        kind: str(j['kind']),
        value: str(j['value']),
        maxDiscount: j['max_discount'] as String?,
        minOrder: str(j['min_order']),
        categoryId: j['category'] as int?,
        categoryName: j['category_name'] as String?,
        startsAt: parseDate(j['starts_at']),
        endsAt: parseDate(j['ends_at']),
        maxUses: j['max_uses'] as int?,
        maxUsesPerUser: j['max_uses_per_user'] == null ? 1 : parseInt(j['max_uses_per_user']),
        firstBookingOnly: j['first_booking_only'] == true,
        isActive: j['is_active'] != false,
        uses: j['uses'] == null ? 0 : parseInt(j['uses']),
        discountGiven: j['discount_given'] == null ? '0.00' : str(j['discount_given']),
      );
  final int id;
  final String code;
  final String description;
  final String kind;
  final String value;
  final String? maxDiscount;
  final String minOrder;
  final int? categoryId;
  final String? categoryName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? maxUses;
  final int maxUsesPerUser;
  final bool firstBookingOnly;
  final bool isActive;
  final int uses;
  final String discountGiven;

  bool get isPercent => kind == 'percent';
}

/// A no-show report for admins (`admin/no-shows/`).
class AdminNoShow {
  AdminNoShow({required this.id, required this.bookingId, required this.bookingTitle, this.preferredTime,
      required this.side, required this.reportedByName, required this.againstName, required this.againstRole,
      required this.againstTotal, this.note = '', required this.review, this.adminNote = '', this.createdAt});
  factory AdminNoShow.fromJson(Map<String, dynamic> j) => AdminNoShow(
      id: parseInt(j['id']),
      bookingId: parseInt(j['booking']),
      bookingTitle: str(j['booking_title']),
      preferredTime: parseDate(j['preferred_time']),
      side: str(j['side']),
      reportedByName: str(j['reported_by_name']),
      againstName: str(j['against_name']),
      againstRole: str(j['against_role']),
      againstTotal: parseInt(j['against_total']),
      note: str(j['note']),
      review: str(j['review']),
      adminNote: str(j['admin_note']),
      createdAt: parseDate(j['created_at']));
  final int id;
  final int bookingId;
  final String bookingTitle;
  final DateTime? preferredTime;
  final String side;
  final String reportedByName;
  final String againstName;
  final String againstRole;
  final int againstTotal;
  final String note;
  final String review;
  final String adminNote;
  final DateTime? createdAt;
}

/// An SOS raised during a job, with both phone numbers so an admin can call straight away.
class AdminSosAlert {
  AdminSosAlert({required this.id, required this.bookingId, required this.bookingTitle, this.bookingStatus = '',
      this.address = '', required this.role, required this.raisedByName, required this.raisedByPhone,
      this.otherName = '', this.otherPhone = '', this.otherRole = '', this.latitude, this.longitude,
      this.note = '', required this.status, this.contactsTexted = 0, this.handledByName, this.adminNote = '',
      this.createdAt});
  factory AdminSosAlert.fromJson(Map<String, dynamic> j) {
    final other = asMap(j['other_party']);
    return AdminSosAlert(
      id: parseInt(j['id']),
      bookingId: parseInt(j['booking']),
      bookingTitle: str(j['booking_title']),
      bookingStatus: str(j['booking_status']),
      address: str(j['address']),
      role: str(j['role']),
      raisedByName: str(j['raised_by_name']),
      raisedByPhone: str(j['raised_by_phone']),
      otherName: str(other['name']),
      otherPhone: str(other['phone']),
      otherRole: str(other['role']),
      latitude: j['latitude'] as String?,
      longitude: j['longitude'] as String?,
      note: str(j['note']),
      status: str(j['status']),
      contactsTexted: parseInt(j['contacts_texted']),
      handledByName: j['handled_by_name'] as String?,
      adminNote: str(j['admin_note']),
      createdAt: parseDate(j['created_at']),
    );
  }
  final int id;
  final int bookingId;
  final String bookingTitle;
  final String bookingStatus;
  final String address;
  final String role;
  final String raisedByName;
  final String raisedByPhone;
  final String otherName;
  final String otherPhone;
  final String otherRole;
  final String? latitude;
  final String? longitude;
  final String note;
  final String status;
  final int contactsTexted;
  final String? handledByName;
  final String adminNote;
  final DateTime? createdAt;
}

/// A late cancellation fee as admins see it.
class AdminCancellationFee {
  AdminCancellationFee({required this.id, required this.bookingId, this.bookingTitle = '', required this.reason,
      required this.amount, required this.workerShare, required this.status, this.customerName = '',
      this.workerName = '', this.waivedReason = '', this.createdAt});
  factory AdminCancellationFee.fromJson(Map<String, dynamic> j) => AdminCancellationFee(
        id: parseInt(j['id']),
        bookingId: parseInt(j['booking']),
        bookingTitle: str(j['booking_title']),
        reason: str(j['reason']),
        amount: str(j['amount']),
        workerShare: str(j['worker_share']),
        status: str(j['status']),
        customerName: str(j['customer_name']),
        workerName: str(j['worker_name']),
        waivedReason: str(j['waived_reason']),
        createdAt: parseDate(j['created_at']),
      );
  final int id;
  final int bookingId;
  final String bookingTitle;
  final String reason;
  final String amount;
  final String workerShare;
  final String status;
  final String customerName;
  final String workerName;
  final String waivedReason;
  final DateTime? createdAt;
}

/// A review as admins see it, with hidden photos and the reply.
class AdminReview {
  AdminReview({required this.id, required this.rating, this.comment = '', this.customerName = '',
      this.workerName = '', this.bookingId, this.isVisible = true, this.photos = const [], this.reply = '',
      this.createdAt});
  factory AdminReview.fromJson(Map<String, dynamic> j) => AdminReview(
        id: parseInt(j['id']),
        rating: parseInt(j['rating']),
        comment: str(j['comment']),
        customerName: str(j['customer_name']),
        workerName: str(j['worker_name']),
        bookingId: j['booking'] == null ? null : parseInt(j['booking']),
        isVisible: j['is_visible'] != false,
        photos: parseList(j['photos'], AdminReviewPhoto.fromJson),
        reply: str(j['reply']),
        createdAt: parseDate(j['created_at']),
      );
  final int id;
  final int rating;
  final String comment;
  final String customerName;
  final String workerName;
  final int? bookingId;
  final bool isVisible;
  final List<AdminReviewPhoto> photos;
  final String reply;
  final DateTime? createdAt;
}

class AdminReviewPhoto {
  AdminReviewPhoto({required this.id, required this.image, this.isHidden = false, this.hiddenReason = ''});
  factory AdminReviewPhoto.fromJson(Map<String, dynamic> j) => AdminReviewPhoto(
      id: parseInt(j['id']), image: str(j['image']), isHidden: j['is_hidden'] == true,
      hiddenReason: str(j['hidden_reason']));
  final int id;
  final String image;
  final bool isHidden;
  final String hiddenReason;
}
