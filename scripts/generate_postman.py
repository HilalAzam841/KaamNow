"""Generates docs/KaamNow.postman_collection.json covering the Stage 1 and Stage 2 flows.

WebSockets are not covered by Postman collections: see README section "WebSocket protocol".

Run:  python scripts/generate_postman.py

Import the JSON into Postman, set {{base_url}}, and run the folders in order.
Test scripts store tokens and ids into collection variables automatically.
"""

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "docs" / "KaamNow.postman_collection.json"


def save(var, expr):
    return f"pm.collectionVariables.set('{var}', pm.response.json().data{expr});"


def req(name, method, path, body=None, token="customer_access", tests=None, form=None):
    item = {
        "name": name,
        "request": {
            "method": method,
            "header": [{"key": "Content-Type", "value": "application/json"}] if body is not None else [],
            "url": {"raw": "{{base_url}}" + path, "host": ["{{base_url}}"], "path": [p for p in path.split("/") if p]},
        },
    }
    if token:
        item["request"]["auth"] = {"type": "bearer", "bearer": [{"key": "token", "value": "{{" + token + "}}"}]}
    else:
        item["request"]["auth"] = {"type": "noauth"}
    if body is not None:
        item["request"]["body"] = {"mode": "raw", "raw": json.dumps(body, indent=2)}
    if form is not None:
        item["request"]["body"] = {"mode": "formdata", "formdata": form}
    if tests:
        item["event"] = [{"listen": "test", "script": {"type": "text/javascript", "exec": tests}}]
    return item


folders = [
    ("1. Auth", [
        req("App config (public)", "GET", "/app/config/", token=None),
        req("Register customer", "POST", "/auth/register/", {
            "phone": "03001234567", "password": "Lahore-Pass-2026", "full_name": "Ayesha Khan", "role": "customer",
        }, token=None, tests=[save("customer_access", ".tokens.access"), save("customer_refresh", ".tokens.refresh")]),
        req("Register worker", "POST", "/auth/register/", {
            "phone": "03017654321", "password": "Lahore-Pass-2026", "full_name": "Bilal Ahmed", "role": "worker",
            "cnic_number": "35202-1234567-1",
        }, token=None, tests=[save("worker_access", ".tokens.access")]),
        req("Login (customer)", "POST", "/auth/login/", {"phone": "03001234567", "password": "Lahore-Pass-2026"},
            token=None, tests=[save("customer_access", ".tokens.access"), save("customer_refresh", ".tokens.refresh")]),
        req("Login (admin, after seed_demo_data)", "POST", "/auth/login/",
            {"phone": "03000000001", "password": "KaamNow-Demo-2026"}, token=None,
            tests=[save("admin_access", ".tokens.access")]),
        req("Me", "GET", "/auth/me/"),
        req("Update my profile", "PATCH", "/auth/me/", {"full_name": "Ayesha K.", "email": "ayesha@example.com"}),
        req("Refresh token", "POST", "/auth/token/refresh/", {"refresh": "{{customer_refresh}}"}, token=None,
            tests=[save("customer_access", ".access"), save("customer_refresh", ".refresh")]),
        req("Password reset request", "POST", "/auth/password-reset/", {"email": "ayesha@example.com"}, token=None),
        req("Password reset confirm", "POST", "/auth/password-reset/confirm/",
            {"uid": "<from email>", "token": "<from email>", "new_password": "New-Lahore-Pass-1"}, token=None),
    ]),
    ("2. Worker onboarding", [
        req("Get my worker profile", "GET", "/workers/me/", token="worker_access",
            tests=[save("worker_id", ".id")]),
        req("Set location, radius, bio", "PATCH", "/workers/me/", {
            "base_latitude": "31.510000", "base_longitude": "74.344000", "service_radius_km": "10",
            "service_area": "Gulberg, Lahore", "experience_years": 8, "bio": "Licensed electrician",
        }, token="worker_access"),
        req("Upload CNIC front", "POST", "/workers/documents/", token="worker_access", form=[
            {"key": "document_type", "value": "cnic_front", "type": "text"},
            {"key": "file", "type": "file", "src": ""},
        ]),
        req("Upload CNIC back", "POST", "/workers/documents/", token="worker_access", form=[
            {"key": "document_type", "value": "cnic_back", "type": "text"},
            {"key": "file", "type": "file", "src": ""},
        ]),
        req("Add service (Electrician = 1)", "POST", "/services/workers/",
            {"category": 1, "starting_price": "500", "description": "Wiring, fans, DB boards"}, token="worker_access"),
        req("Go online", "POST", "/workers/availability/", {"is_available": True}, token="worker_access"),
    ]),
    ("3. Admin", [
        req("Pending workers", "GET", "/admin/workers/pending/", token="admin_access"),
        req("Verify worker", "POST", "/admin/workers/{{worker_id}}/verify/", token="admin_access"),
        req("Reject worker", "POST", "/admin/workers/{{worker_id}}/reject/", {"reason": "CNIC unreadable"},
            token="admin_access"),
        req("Download document (audited)", "GET", "/admin/documents/1/file/", token="admin_access"),
        req("Create category", "POST", "/services/categories/", {"name": "Solar Installation"}, token="admin_access"),
        req("Deactivate category", "PATCH", "/services/categories/14/", {"is_active": False}, token="admin_access"),
        req("Dashboard", "GET", "/admin/dashboard/", token="admin_access"),
        req("Bookings", "GET", "/admin/bookings/?status=completed", token="admin_access"),
        req("Revenue", "GET", "/admin/revenue/?date_from=2026-01-01", token="admin_access"),
        req("Commissions", "GET", "/admin/commissions/", token="admin_access"),
        req("Get commission rate", "GET", "/admin/settings/commission/", token="admin_access"),
        req("Set commission rate", "PATCH", "/admin/settings/commission/", {"commission_percent": "10.00"},
            token="admin_access"),
        req("Reports", "GET", "/admin/reports/", token="admin_access"),
        req("Suspend user", "POST", "/admin/users/2/suspend/", {"reason": "Fraud"}, token="admin_access"),
        req("Audit log", "GET", "/admin/audit-logs/", token="admin_access"),
    ]),
    ("4. Customer request", [
        req("List categories", "GET", "/services/categories/", token=None),
        req("Nearby workers", "GET", "/workers/nearby/?category=1&latitude=31.5100&longitude=74.3440"),
        req("Create request", "POST", "/requests/", {
            "category": 1, "title": "Ceiling fan not working",
            "description": "Bedroom fan stopped after a power surge, makes a humming sound.",
            "latitude": "31.512000", "longitude": "74.345000", "address": "House 12, Street 4, Gulberg III",
            "area": "Gulberg III", "preferred_time": "2026-12-01T15:00:00+05:00",
        }, tests=[save("request_id", ".id")]),
        req("My requests", "GET", "/requests/"),
        req("Request detail", "GET", "/requests/{{request_id}}/"),
        req("Matching workers for request", "GET", "/requests/{{request_id}}/nearby-workers/"),
        req("Edit request", "PATCH", "/requests/{{request_id}}/", {"title": "Two ceiling fans not working"}),
    ]),
    ("5. Offers & negotiation", [
        req("Worker feed (nearby open requests)", "GET", "/requests/", token="worker_access"),
        req("Worker submits offer Rs.1000", "POST", "/requests/{{request_id}}/offers/",
            {"price": "1000", "estimated_arrival_minutes": 30, "message": "Can come in 30 min"},
            token="worker_access", tests=[save("offer_id", ".id")]),
        req("Customer compares offers", "GET", "/requests/{{request_id}}/offers/?ordering=price"),
        req("Customer counters Rs.800", "POST", "/offers/{{offer_id}}/negotiate/", {"action": "counter", "amount": "800"}),
        req("Worker counters Rs.900", "POST", "/offers/{{offer_id}}/negotiate/", {"action": "counter", "amount": "900"},
            token="worker_access"),
        req("Negotiation history", "GET", "/offers/{{offer_id}}/negotiations/"),
        req("Worker: my offers", "GET", "/offers/?status=pending", token="worker_access"),
        req("Customer accepts Rs.900 (creates booking)", "POST", "/offers/{{offer_id}}/accept/", {},
            tests=[save("booking_id", ".id")]),
        req("Reject / withdraw offer", "POST", "/offers/{{offer_id}}/reject/", {"reason": "Found another worker"}),
    ]),
    ("6. Booking & completion", [
        req("Booking detail", "GET", "/bookings/{{booking_id}}/"),
        req("Worker: on the way", "POST", "/bookings/{{booking_id}}/status/", {"status": "on_the_way"},
            token="worker_access"),
        req("Worker: arrived", "POST", "/bookings/{{booking_id}}/status/", {"status": "arrived"}, token="worker_access"),
        req("Worker: work started", "POST", "/bookings/{{booking_id}}/status/", {"status": "in_progress"},
            token="worker_access"),
        req("Customer: get completion OTP", "POST", "/bookings/{{booking_id}}/completion-otp/",
            tests=[save("otp", ".otp")]),
        req("Worker: complete with OTP", "POST", "/bookings/{{booking_id}}/complete/", {"otp": "{{otp}}"},
            token="worker_access"),
        req("Customer: confirm completion in-app (alternative)", "POST", "/bookings/{{booking_id}}/complete/",
            {"confirm": True}),
        req("Cancel booking", "POST", "/bookings/{{booking_id}}/cancel/", {"reason": "Plans changed"}),
    ]),
    ("7. Payment, review, notifications", [
        req("Customer records cash payment", "POST", "/payments/", {"booking": "{{booking_id}}", "method": "cash"},
            tests=[save("payment_id", ".id")]),
        req("Worker confirms cash received", "POST", "/payments/{{payment_id}}/confirm/", token="worker_access"),
        req("My payments", "GET", "/payments/"),
        req("Worker earnings", "GET", "/payments/earnings/", token="worker_access"),
        req("Review worker", "POST", "/reviews/", {"booking": "{{booking_id}}", "rating": 5, "comment": "Quick and tidy"}),
        req("Worker reviews (public)", "GET", "/workers/{{worker_id}}/reviews/", token=None),
        req("Notifications", "GET", "/notifications/"),
        req("Mark notification read", "POST", "/notifications/1/read/"),
        req("Logout", "POST", "/auth/logout/", {"refresh": "{{customer_refresh}}"}),
    ]),
    ("8. Chat & live tracking (Stage 2)", [
        req("Send chat message", "POST", "/bookings/{{booking_id}}/messages/", {"body": "Please bring a ladder"}),
        req("Chat history", "GET", "/bookings/{{booking_id}}/messages/"),
        req("Mark messages read", "POST", "/bookings/{{booking_id}}/messages/read/", token="worker_access"),
        req("Worker shares location", "POST", "/bookings/{{booking_id}}/location/",
            {"latitude": "31.520000", "longitude": "74.344000", "speed_kmh": "25"}, token="worker_access"),
        req("Customer gets live location + ETA", "GET", "/bookings/{{booking_id}}/location/"),
    ]),
    ("9. Online payments (Stage 2)", [
        req("Pay with JazzCash (returns checkout)", "POST", "/payments/", {"booking": "{{booking_id}}",
                                                                            "method": "jazzcash"}),
        req("Pay with Easypaisa (returns checkout)", "POST", "/payments/", {"booking": "{{booking_id}}",
                                                                             "method": "easypaisa"}),
        req("JazzCash callback (sent by JazzCash, signed)", "POST", "/payments/callbacks/jazzcash/",
            {"pp_TxnRefNo": "<reference>", "pp_ResponseCode": "000", "pp_SecureHash": "<hmac>"}, token=None),
        req("Easypaisa postback (server re-checks via inquiry API)", "GET",
            "/payments/callbacks/easypaisa/?orderRefNumber=<reference>", token=None),
    ]),
    ("10. Subscriptions & featured (Stage 2)", [
        req("Subscription plans", "GET", "/subscriptions/plans/", token=None),
        req("Subscribe to Professional", "POST", "/subscriptions/", {"plan": 2, "method": "jazzcash"},
            token="worker_access"),
        req("My subscription", "GET", "/subscriptions/my-subscription/", token="worker_access"),
        req("Subscription history", "GET", "/subscriptions/history/", token="worker_access"),
        req("Featured plans", "GET", "/featured/plans/", token=None),
        req("Buy featured placement", "POST", "/featured/", {"plan": 1, "category": 1, "method": "jazzcash"},
            token="worker_access"),
        req("My featured listings", "GET", "/featured/", token="worker_access"),
    ]),
    ("11. Emergency, push, complaints (Stage 2)", [
        req("Create emergency request", "POST", "/requests/", {
            "category": 2, "title": "Water pipe burst", "description": "Main pipe burst in the kitchen, urgent.",
            "latitude": "31.512000", "longitude": "74.345000", "address": "House 12, Gulberg III",
            "preferred_time": "2026-12-01T15:00:00+05:00", "is_emergency": True,
        }),
        req("Register device for push", "POST", "/notifications/devices/",
            {"token": "<firebase registration token>", "platform": "android"}),
        req("Unregister device", "DELETE", "/notifications/devices/", {"token": "<firebase registration token>"}),
        req("Report a problem", "POST", "/complaints/", {
            "booking": "{{booking_id}}", "category": "overcharging", "subject": "Charged extra",
            "description": "Worker asked for more money than the agreed price at the end.",
        }),
        req("My complaints", "GET", "/complaints/"),
    ]),
    ("12. Admin (Stage 2)", [
        req("Platform settings (commission, emergency fee)", "PATCH", "/admin/settings/",
            {"emergency_fee": "300.00", "emergency_enabled": True}, token="admin_access"),
        req("Subscription plans", "GET", "/admin/subscription-plans/", token="admin_access"),
        req("Update plan price", "PATCH", "/admin/subscription-plans/2/", {"price": "1500.00"}, token="admin_access"),
        req("Featured plans", "GET", "/admin/featured-plans/", token="admin_access"),
        req("Subscriptions", "GET", "/admin/subscriptions/?status=active", token="admin_access"),
        req("Activate subscription manually", "POST", "/admin/subscriptions/1/activate/", token="admin_access"),
        req("Featured listings", "GET", "/admin/featured-listings/", token="admin_access"),
        req("Cancel featured listing", "POST", "/admin/featured-listings/1/cancel/", {"reason": "Policy violation"},
            token="admin_access"),
        req("Complaints", "GET", "/admin/complaints/?status=open", token="admin_access"),
        req("Resolve complaint", "POST", "/admin/complaints/1/status/",
            {"status": "resolved", "resolution": "Refunded the difference."}, token="admin_access"),
        req("Other revenue", "GET", "/admin/revenue/other/", token="admin_access"),
    ]),
]

collection = {
    "info": {
        "name": "KaamNow API v1",
        "description": "Full backend flow (Stage 1 + Stage 2). Set base_url, then run folders in order. "
                       "Responses use the envelope {success, data, message}.",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    },
    "variable": [{"key": "base_url", "value": "http://localhost:8000/api/v1"}] + [
        {"key": k, "value": ""} for k in (
            "customer_access", "customer_refresh", "worker_access", "admin_access", "worker_id", "request_id",
            "offer_id", "booking_id", "otp", "payment_id",
        )
    ],
    "item": [{"name": name, "item": items} for name, items in folders],
}

if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(collection, indent=2))
    print(f"Wrote {OUT} ({sum(len(i) for _, i in folders)} requests)")
