from rest_framework.permissions import SAFE_METHODS, BasePermission


def _role(user):
    return getattr(user, "role", None) if user and user.is_authenticated else None


class IsCustomer(BasePermission):
    message = "Only customers can perform this action."

    def has_permission(self, request, view):
        return _role(request.user) == "customer"


class IsWorker(BasePermission):
    message = "Only service providers can perform this action."

    def has_permission(self, request, view):
        return _role(request.user) == "worker" and hasattr(request.user, "worker_profile")


class IsVerifiedWorker(BasePermission):
    message = "Your service provider account must be verified by KaamNow first."

    def has_permission(self, request, view):
        user = request.user
        return (
            _role(user) == "worker"
            and hasattr(user, "worker_profile")
            and user.worker_profile.is_verified
        )


class IsPlatformAdmin(BasePermission):
    message = "Administrator access required."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and (user.role == "admin" or user.is_staff))


class IsAdminOrReadOnly(BasePermission):
    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        return IsPlatformAdmin().has_permission(request, view)
