from decimal import Decimal

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone

from apps.common.models import TimeStampedModel
from apps.common.storage import private_storage
from apps.common.utils import RandomUploadPath
from apps.common.validators import (
    normalize_pk_phone,
    validate_cnic,
    validate_document_upload,
    validate_image_upload,
    validate_pk_phone,
)


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, phone, password, **extra):
        if not phone:
            raise ValueError("Phone number is required.")
        phone = normalize_pk_phone(phone)
        email = extra.pop("email", None)
        email = self.normalize_email(email) if email else None
        user = self.model(phone=phone, email=email, **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, phone, password=None, **extra):
        extra.setdefault("is_staff", False)
        extra.setdefault("is_superuser", False)
        extra.setdefault("role", User.Role.CUSTOMER)
        return self._create_user(phone, password, **extra)

    def create_superuser(self, phone, password=None, **extra):
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        extra.setdefault("role", User.Role.ADMIN)
        extra.setdefault("full_name", "Administrator")
        if extra.get("is_staff") is not True or extra.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_staff=True and is_superuser=True.")
        return self._create_user(phone, password, **extra)


class User(AbstractBaseUser, PermissionsMixin, TimeStampedModel):
    class Language(models.TextChoices):
        ENGLISH = "en", "English"
        URDU = "ur", "اردو"

    class Role(models.TextChoices):
        CUSTOMER = "customer", "Customer"
        WORKER = "worker", "Service provider"
        ADMIN = "admin", "Administrator"

    phone = models.CharField(max_length=13, unique=True, validators=[validate_pk_phone])
    email = models.EmailField(unique=True, null=True, blank=True)
    full_name = models.CharField(max_length=150)
    role = models.CharField(max_length=10, choices=Role.choices, default=Role.CUSTOMER, db_index=True)
    avatar = models.ImageField(
        upload_to=RandomUploadPath("avatars"), null=True, blank=True, validators=[validate_image_upload]
    )
    default_address = models.CharField(max_length=255, blank=True)
    language = models.CharField(
        max_length=2, choices=Language.choices, default=Language.ENGLISH,
        help_text="Language for alerts and server messages. The app keeps it in sync with the user's choice.",
    )
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_suspended = models.BooleanField(default=False, db_index=True)
    suspended_reason = models.CharField(max_length=255, blank=True)
    date_joined = models.DateTimeField(default=timezone.now)
    phone_verified_at = models.DateTimeField(
        null=True, blank=True, help_text="When the user confirmed this phone number with an SMS code."
    )

    objects = UserManager()

    USERNAME_FIELD = "phone"
    REQUIRED_FIELDS = []

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.full_name} ({self.phone})"

    @property
    def phone_verified(self):
        return self.phone_verified_at is not None

    @property
    def is_customer(self):
        return self.role == self.Role.CUSTOMER

    @property
    def is_worker(self):
        return self.role == self.Role.WORKER

    @property
    def is_platform_admin(self):
        return self.role == self.Role.ADMIN or self.is_staff


class PhoneCode(models.Model):
    """A one-time SMS code. Only an HMAC of the code is stored."""

    class Purpose(models.TextChoices):
        VERIFY = "verify", "Verify phone number"
        RESET = "reset", "Reset password"

    phone = models.CharField(max_length=13, db_index=True)
    purpose = models.CharField(max_length=10, choices=Purpose.choices)
    code_hash = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["phone", "purpose", "created_at"])]

    def __str__(self):
        return f"{self.get_purpose_display()} code for {self.phone}"


class WorkerProfile(TimeStampedModel):
    class VerificationStatus(models.TextChoices):
        PENDING = "pending", "Pending review"
        VERIFIED = "verified", "Verified"
        REJECTED = "rejected", "Rejected"

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="worker_profile")
    cnic_number = models.CharField(max_length=13, unique=True, validators=[validate_cnic])
    bio = models.TextField(blank=True, max_length=2000)
    experience_years = models.PositiveSmallIntegerField(default=0, validators=[MaxValueValidator(60)])
    profile_picture = models.ImageField(
        upload_to=RandomUploadPath("workers/pictures"), null=True, blank=True, validators=[validate_image_upload]
    )
    base_latitude = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True,
        validators=[MinValueValidator(Decimal("-90")), MaxValueValidator(Decimal("90"))],
    )
    base_longitude = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True,
        validators=[MinValueValidator(Decimal("-180")), MaxValueValidator(Decimal("180"))],
    )
    service_area = models.CharField(max_length=255, blank=True, help_text="e.g. Gulberg, Lahore")
    service_radius_km = models.DecimalField(
        max_digits=5, decimal_places=2, default=Decimal("10.00"),
        validators=[MinValueValidator(Decimal("1")), MaxValueValidator(Decimal("50"))],
    )
    is_available = models.BooleanField(default=False)
    verification_status = models.CharField(
        max_length=10, choices=VerificationStatus.choices, default=VerificationStatus.PENDING, db_index=True
    )
    rejection_reason = models.CharField(max_length=500, blank=True)
    verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name="verified_workers"
    )
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=Decimal("0.00"))
    rating_count = models.PositiveIntegerField(default=0)
    completed_jobs_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["verification_status", "is_available"]),
            models.Index(fields=["base_latitude", "base_longitude"]),
        ]

    def __str__(self):
        return f"Worker: {self.user.full_name}"

    @property
    def is_verified(self):
        return self.verification_status == self.VerificationStatus.VERIFIED

    @property
    def can_receive_jobs(self):
        user = self.user
        return self.is_verified and self.is_available and user.is_active and not user.is_suspended


class WorkerDocument(TimeStampedModel):
    class DocumentType(models.TextChoices):
        CNIC_FRONT = "cnic_front", "CNIC front"
        CNIC_BACK = "cnic_back", "CNIC back"
        CERTIFICATE = "certificate", "Skill certificate"
        OTHER = "other", "Other"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    worker = models.ForeignKey(WorkerProfile, on_delete=models.CASCADE, related_name="documents")
    document_type = models.CharField(max_length=20, choices=DocumentType.choices)
    file = models.FileField(
        storage=private_storage, upload_to=RandomUploadPath("worker_documents"),
        validators=[validate_document_upload],
    )
    original_filename = models.CharField(max_length=255, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["worker", "document_type"])]

    def __str__(self):
        return f"{self.get_document_type_display()} for {self.worker}"
