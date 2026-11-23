import os

from django.conf import settings
from django.core.files.storage import FileSystemStorage
from django.utils.deconstruct import deconstructible


@deconstructible
class PrivateMediaStorage(FileSystemStorage):
    """Storage for sensitive files (CNIC documents).

    Files live in PRIVATE_MEDIA_ROOT (outside MEDIA_ROOT) and have no public
    URL; they are only streamed through an authenticated, audited admin
    endpoint. In production, point PRIVATE_MEDIA_ROOT at a volume that the
    web server does not serve, or swap this class for a private S3 bucket.
    """

    @property
    def base_location(self):
        return str(settings.PRIVATE_MEDIA_ROOT)

    @property
    def location(self):
        return os.path.abspath(self.base_location)

    @property
    def base_url(self):
        return None

    def url(self, name):
        raise NotImplementedError("Private files are not accessible by URL.")


private_storage = PrivateMediaStorage()
