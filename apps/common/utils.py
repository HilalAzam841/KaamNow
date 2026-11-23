import uuid

from django.utils.deconstruct import deconstructible


@deconstructible
class RandomUploadPath:
    """upload_to callable that stores files under random, non-guessable names."""

    def __init__(self, prefix):
        self.prefix = prefix

    def __call__(self, instance, filename):
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
        return f"{self.prefix}/{uuid.uuid4().hex}.{ext}"

    def __eq__(self, other):
        return isinstance(other, RandomUploadPath) and other.prefix == self.prefix


def client_ip(request):
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")
