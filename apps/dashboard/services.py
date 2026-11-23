from apps.common.utils import client_ip

from .models import AuditLog


def audit(actor, action, target, request=None, **metadata):
    return AuditLog.objects.create(
        actor=actor if actor and actor.is_authenticated else None,
        action=action,
        target_type=target.__class__.__name__,
        target_id=str(target.pk),
        metadata=metadata,
        ip_address=client_ip(request) if request is not None else None,
    )
