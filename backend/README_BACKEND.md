# ElderEase PHP + MySQL Backend (Hostinger)

This folder contains a ready-to-upload backend matching your Flutter app flow.

## Files

- `sql/elderease_schema.sql`: Database schema + starter service rows
- `api/config.php`: DB credentials
- `api/db.php`: PDO connection
- `api/response.php`: JSON + CORS helpers
- `api/utils.php`: shared status normalizer
- `api/create_request.php`: creates request + selected service items
- `api/list_requests.php`: lists requests and statuses for a username
- `api/register.php`: creates user account
- `api/login.php`: authenticates user account
- `api/get_profile.php`: fetches profile details by username
- `api/update_profile.php`: updates profile details by username
- `api/assign_volunteer.php`: assigns helper to request and sets status to matched
- `api/update_request_status.php`: updates request status (for admin/volunteer tools)
- `api/list_services.php`: fetches active services catalog
- `api/submit_feedback.php`: inserts feedback and updates volunteer rating

## Hostinger Setup

1. Create MySQL database in Hostinger hPanel.
2. Open phpMyAdmin and import `sql/elderease_schema.sql`.
3. Upload `api/` files to `public_html/api/` in your hosting account.
4. Edit `public_html/api/config.php` with your actual credentials.
5. Set `APP_DEBUG` to `false` in production.

## Flutter Base URL

Your Flutter app should point to:

`https://elderease.uslsbsit.com/api`

Current Flutter config already uses this in `lib/config/app_config.dart`.

## Quick Endpoint Tests

### Create request

`POST https://elderease.uslsbsit.com/api/create_request.php`

```json
{
  "id": "1741716486000",
  "username": "margrethe",
  "services": [
    {"id": "1", "name": "LPG Gas Tank Replacement"},
    {"id": "2", "name": "Grocery Collection"}
  ],
  "scheduled_at": "2026-03-12T09:00:00",
  "address": "123 Main St, Bacolod, 6100",
  "notes": "Please ring the bell.",
  "status": "requested"
}
```

### List requests

`GET https://elderease.uslsbsit.com/api/list_requests.php?username=margrethe`

### Register

`POST https://elderease.uslsbsit.com/api/register.php`

```json
{
  "full_name": "Margrethe V. Gilpo",
  "username": "margrethe",
  "email": "mg@gmail.com",
  "password": "secret123",
  "phone_number": "09086149697",
  "birthday": "1999-05-12",
  "address": "Bacolod City"
}
```

### Login

`POST https://elderease.uslsbsit.com/api/login.php`

```json
{
  "username": "margrethe",
  "password": "secret123"
}
```

### Get profile

`GET https://elderease.uslsbsit.com/api/get_profile.php?username=margrethe`

### Update profile

`POST https://elderease.uslsbsit.com/api/update_profile.php`

```json
{
  "username": "margrethe",
  "full_name": "Margrethe V. Gilpo",
  "email": "mg@gmail.com",
  "phone_number": "09086149697",
  "birthday": "1999-05-12",
  "address": "123 Main St, Bacolod, 6100"
}
```

### Assign volunteer

`POST https://elderease.uslsbsit.com/api/assign_volunteer.php`

```json
{
  "request_id": "1741716486000",
  "volunteer_id": 1
}
```

### Update status (admin or volunteer tooling)

`POST https://elderease.uslsbsit.com/api/update_request_status.php`

```json
{
  "request_id": "1741716486000",
  "status": "en_route",
  "volunteer_id": 1
}
```

### Submit feedback

`POST https://elderease.uslsbsit.com/api/submit_feedback.php`

```json
{
  "request_id": "1741716486000",
  "rating_score": 5,
  "comments": "Very respectful and careful."
}
```

## Notes About ERD vs Production Design

Your ERD is close, but one correction is important:

- A single service request can contain multiple services.
- So the schema uses `request_items` as a junction table between `service_requests` and `services`.

This makes your app and database consistent with the current multi-service request flow.
