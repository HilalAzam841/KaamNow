from django.core.management.base import BaseCommand

from apps.notifications.webpush import generate_vapid_keys


class Command(BaseCommand):
    help = "Prints a new VAPID key pair for browser push notifications. Put both lines in your .env."

    def handle(self, *args, **options):
        public, private = generate_vapid_keys()
        self.stdout.write(f"WEBPUSH_VAPID_PUBLIC_KEY={public}")
        self.stdout.write(f"WEBPUSH_VAPID_PRIVATE_KEY={private}")
