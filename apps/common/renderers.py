from rest_framework.renderers import JSONRenderer


class EnvelopeJSONRenderer(JSONRenderer):
    """Wraps every JSON response in a consistent envelope.

    Success: {"success": true, "data": <payload>, "message": null}
    Error:   {"success": false, "error": {...}}  (built by the exception handler)
    """

    def render(self, data, accepted_media_type=None, renderer_context=None):
        renderer_context = renderer_context or {}
        response = renderer_context.get("response")

        if isinstance(data, dict) and "success" in data and ("data" in data or "error" in data):
            payload = data
        elif response is not None and response.status_code >= 400:
            payload = {
                "success": False,
                "error": {"code": "error", "message": "Request failed.", "details": data},
            }
        else:
            message = None
            if isinstance(data, dict) and set(data.keys()) == {"detail"}:
                message = data["detail"]
                data = None
            payload = {"success": True, "data": data, "message": message}
        return super().render(payload, accepted_media_type, renderer_context)
