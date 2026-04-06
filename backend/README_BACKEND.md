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
- `api/admin_login.php`: authenticates admin account
- `api/admin_logout.php`: invalidates active admin session token
- `api/get_profile.php`: fetches profile details by username
- `api/update_profile.php`: updates profile details by username
- `api/assign_volunteer.php`: assigns helper to request and sets status to matched
- `api/admin_assign_volunteer.php`: admin-only volunteer assignment (Bearer token)
- `api/update_request_status.php`: updates request status (for admin/volunteer tools)
- `api/admin_update_request_status.php`: admin-only status update (Bearer token)
- `api/list_services.php`: fetches active services catalog
- `api/admin_list_requests.php`: lists all requests for admin dashboard
- `api/list_volunteers.php`: lists all volunteers for admin assignment UI
- `api/admin_list_volunteer_signups.php`: lists volunteer signups awaiting admin review
- `api/admin_process_volunteer_signup.php`: approve/reject volunteer signups
- `api/migrate_hash_admin_passwords.php`: one-time plaintext-to-bcrypt admin password migration (debug-only)
- `api/submit_feedback.php`: inserts feedback and updates volunteer rating

## Hostinger Setup

1. Create MySQL database in Hostinger hPanel.
2. Open phpMyAdmin and import `sql/elderease_schema.sql`.
3. If your database already exists, run `sql/migrations/2026_04_06_create_admin_sessions.sql`.
4. If your database already exists, run `sql/migrations/2026_04_06_create_volunteer_signup_requests.sql`.
5. Upload `api/` files to `public_html/api/` in your hosting account.
6. Edit `public_html/api/config.php` with your actual credentials.
7. Set `APP_DEBUG` to `false` in production.

## Flutter Base URL

Your Flutter app should point to:

`https://elderease.uslsbsit.com/api`

Current Flutter config already uses this in `lib/config/app_config.dart`.

Admin web dashboard entry page:

`https://elderease.uslsbsit.com/admin.html`

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
  "role": "user",
  "email": "mg@gmail.com",
  "password": "secret123",
  "phone_number": "09086149697",
  "birthday": "1999-05-12",
  "address": "Bacolod City"
}
```

Volunteer signups are now placed in a pending queue and are not immediately created in `users`.
An admin must approve the signup from the admin dashboard before volunteer login works.

### Login

`POST https://elderease.uslsbsit.com/api/login.php`

```json
{
  "identifier": "margrethe",
  "password": "secret123",
  "role": "user"
}
```

### Admin login

`POST https://elderease.uslsbsit.com/api/admin_login.php`

```json
{
  "identifier": "admin1",
  "password": "secret123"
}
```

Returns a `token` that must be sent in `Authorization: Bearer <token>`.

### Admin list requests

`GET https://elderease.uslsbsit.com/api/admin_list_requests.php`

Header:

`Authorization: Bearer <token>`

### List volunteers (admin)

`GET https://elderease.uslsbsit.com/api/list_volunteers.php`

Header:

`Authorization: Bearer <token>`

### Admin assign volunteer

`POST https://elderease.uslsbsit.com/api/admin_assign_volunteer.php`

Header:

`Authorization: Bearer <token>`

Body:

```json
{
  "request_id": "1741716486000",
  "volunteer_id": 1
}
```

### Admin update request status

`POST https://elderease.uslsbsit.com/api/admin_update_request_status.php`

Header:

`Authorization: Bearer <token>`

Body:

```json
{
  "request_id": "1741716486000",
  "status": "en_route",
  "volunteer_id": 1
}
```

### Admin list volunteer signups

`GET https://elderease.uslsbsit.com/api/admin_list_volunteer_signups.php?status=pending`

Header:

`Authorization: Bearer <token>`

### Admin approve/reject volunteer signup

`POST https://elderease.uslsbsit.com/api/admin_process_volunteer_signup.php`

Header:

`Authorization: Bearer <token>`

Body:

```json
{
  "signup_id": 5,
  "action": "approve",
  "admin_note": "Verified profile"
}
```

### Admin logout

`POST https://elderease.uslsbsit.com/api/admin_logout.php`

Header:

`Authorization: Bearer <token>`

### One-time: hash old plaintext admin passwords

If legacy admin passwords were stored as plaintext, run this once:

`POST https://elderease.uslsbsit.com/api/migrate_hash_admin_passwords.php`

Body:

```json
{
  "confirm": "HASH_ADMIN_PASSWORDS"
}
```

Important:

- Works only when `APP_DEBUG = true`
- Set `APP_DEBUG = false` after migration
- Delete `api/migrate_hash_admin_passwords.php` after successful run

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
