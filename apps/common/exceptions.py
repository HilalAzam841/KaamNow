import logging

from django.core.exceptions import PermissionDenied, ValidationError as DjangoValidationError
from django.http import Http404
from rest_framework import exceptions, status
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger(__name__)


class BusinessRuleError(exceptions.APIException):
    """Raised by service-layer code when a business rule is violated."""

    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "This action is not allowed."
    default_code = "business_rule_violation"

    def __init__(self, detail=None, code=None, status_code=None):
        super().__init__(detail, code)
        if status_code is not None:
            self.status_code = status_code


class ConflictError(BusinessRuleError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "conflict"


def _first_message(detail):
    if isinstance(detail, list) and detail:
        return _first_message(detail[0])
    if isinstance(detail, dict) and detail:
        key, value = next(iter(detail.items()))
        msg = _first_message(value)
        return msg if key in ("non_field_errors", "detail") else f"{key}: {msg}"
    return str(detail)


def api_exception_handler(exc, context):
    if isinstance(exc, DjangoValidationError):
        exc = exceptions.ValidationError(exc.message_dict if hasattr(exc, "message_dict") else exc.messages)
    elif isinstance(exc, Http404):
        exc = exceptions.NotFound()
    elif isinstance(exc, PermissionDenied):
        exc = exceptions.PermissionDenied()

    response = exception_handler(exc, context)
    if response is None:
        logger.exception("Unhandled API error", exc_info=exc)
        return Response(
            {"success": False, "error": {"code": "server_error", "message": "Internal server error.", "details": None}},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    detail = exc.detail if isinstance(exc, exceptions.APIException) else response.data
    codes = exc.get_codes() if isinstance(exc, exceptions.APIException) else "error"
    code = codes if isinstance(codes, str) else ("validation_error" if isinstance(exc, exceptions.ValidationError) else "error")
    response.data = {
        "success": False,
        "error": {
            "code": code,
            "message": _first_message(detail),
            "details": detail if isinstance(detail, (dict, list)) else None,
        },
    }
    return response
