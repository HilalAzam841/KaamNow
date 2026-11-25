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
      this.minPayout = '500.00', this.commissionDebtLimit = '0.00', this.updatedAt});
  factory PlatformSettings.fromJson(Map<String, dynamic> j) => PlatformSettings(
      commissionPercent: str(j['commission_percent']),
      emergencyFee: str(j['emergency_fee']),
      emergencyEnabled: j['emergency_enabled'] == true,
      minPayout: j['min_payout'] == null ? '500.00' : str(j['min_payout']),
      commissionDebtLimit: j['commission_debt_limit'] == null ? '0.00' : str(j['commission_debt_limit']),
      updatedAt: parseDate(j['updated_at']));
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
