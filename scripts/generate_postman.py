"""Generates docs/KaamNow.postman_collection.json covering the full Stage 1 flow.

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
]

collection = {
    "info": {
        "name": "KaamNow API v1",
        "description": "Stage 1 backend flow. Set base_url, then run folders in order. "
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
