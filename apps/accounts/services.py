from django.utils.translation import gettext as _
from django.db import transaction
from django.utils import timezone

from apps.common.exceptions import BusinessRuleError
from apps.dashboard.models import AuditLog
from apps.dashboard.services import audit
from apps.common.i18n import t
from apps.notifications.models import Notification
from apps.notifications.services import notify

from .models import User, WorkerDocument, WorkerProfile


@transaction.atomic
def register_user(*, phone, password, full_name, role, email=None, cnic_number=None, referral_code=""):
    if role not in (User.Role.CUSTOMER, User.Role.WORKER):
        raise BusinessRuleError(_("Only customer and worker accounts can self-register."))
    user = User.objects.create_user(phone=phone, password=password, full_name=full_name, role=role, email=email)
    if role == User.Role.WORKER:
        WorkerProfile.objects.create(user=user, cnic_number=cnic_number)
    if referral_code:
        from apps.promotions.services import apply_referral_code

        apply_referral_code(user, referral_code)
    return user


@transaction.atomic
def verify_worker(worker: WorkerProfile, admin_user, request=None):
    worker = WorkerProfile.objects.select_for_update().get(pk=worker.pk)
    if worker.is_verified:
        raise BusinessRuleError(_("This worker is already verified."))
    if not worker.documents.filter(
        document_type__in=[WorkerDocument.DocumentType.CNIC_FRONT, WorkerDocument.DocumentType.CNIC_BACK]
    ).exists():
        raise BusinessRuleError(_("Worker has not uploaded CNIC documents yet."))
    worker.verification_status = WorkerProfile.VerificationStatus.VERIFIED
    worker.verified_at = timezone.now()
    worker.verified_by = admin_user
    worker.rejection_reason = ""
    worker.save(update_fields=["verification_status", "verified_at", "verified_by", "rejection_reason", "updated_at"])
    worker.documents.filter(status=WorkerDocument.Status.PENDING).update(
        status=WorkerDocument.Status.APPROVED, reviewed_at=timezone.now()
    )
    audit(admin_user, AuditLog.Action.WORKER_VERIFIED, worker, request)
    notify(
        worker.user, Notification.Type.VERIFICATION, t("Account verified"),
        t("Your KaamNow service provider account is verified. You can now go online and receive jobs."),
    )
    from apps.levels.services import refresh as refresh_level

    return refresh_level(worker, notify_change=False)


@transaction.atomic
def reject_worker(worker: WorkerProfile, admin_user, reason, request=None):
    worker = WorkerProfile.objects.select_for_update().get(pk=worker.pk)
    worker.verification_status = WorkerProfile.VerificationStatus.REJECTED
    worker.rejection_reason = reason
    worker.is_available = False
    worker.verified_at = None
    worker.verified_by = None
    worker.save(update_fields=[
        "verification_status", "rejection_reason", "is_available", "verified_at", "verified_by", "updated_at",
    ])
    worker.documents.filter(status=WorkerDocument.Status.PENDING).update(
        status=WorkerDocument.Status.REJECTED, reviewed_at=timezone.now()
    )
    audit(admin_user, AuditLog.Action.WORKER_REJECTED, worker, request, reason=reason)
    notify(
        worker.user, Notification.Type.VERIFICATION, t("Verification unsuccessful"),
        t("Your verification was not approved: {reason}", reason=reason),
    )
    from apps.levels.services import refresh as refresh_level

    return refresh_level(worker, notify_change=False)


def set_availability(worker: WorkerProfile, is_available: bool):
    if is_available:
        if not worker.is_verified:
            raise BusinessRuleError(_("Your account must be verified before you can go online."))
        if worker.base_latitude is None or worker.base_longitude is None:
            raise BusinessRuleError(_("Set your service location before going online."))
        if not worker.services.filter(is_active=True, category__is_active=True).exists():
            raise BusinessRuleError(_("Add at least one service category before going online."))
    worker.is_available = is_available
    worker.save(update_fields=["is_available", "updated_at"])
    return worker


@transaction.atomic
def set_suspension(user: User, admin_user, suspend: bool, reason="", request=None):
    if user.pk == admin_user.pk:
        raise BusinessRuleError(_("You cannot suspend your own account."))
    user.is_suspended = suspend
    user.suspended_reason = reason if suspend else ""
    user.save(update_fields=["is_suspended", "suspended_reason", "updated_at"])
    if suspend and hasattr(user, "worker_profile"):
        user.worker_profile.is_available = False
        user.worker_profile.save(update_fields=["is_available", "updated_at"])
    if suspend:
        # Invalidate all outstanding refresh tokens.
        from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

        for token in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=token)
    audit(
        admin_user,
        AuditLog.Action.USER_SUSPENDED if suspend else AuditLog.Action.USER_REACTIVATED,
        user, request, reason=reason,
    )
    return user
