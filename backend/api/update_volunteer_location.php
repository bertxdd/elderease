<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$requestId = trim((string)($input['request_id'] ?? ''));
$username = trim((string)($input['username'] ?? ''));
$lat = (float)($input['lat'] ?? 0);
$lng = (float)($input['lng'] ?? 0);

if ($requestId === '' || $username === '') {
    respond(422, ['success' => false, 'message' => 'request_id and username are required']);
}

if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
    respond(422, ['success' => false, 'message' => 'Invalid latitude/longitude']);
}

try {
    $pdo = db();

    $findName = $pdo->prepare(
        'SELECT full_name
         FROM users
         WHERE username = :username
         LIMIT 1'
    );
    $findName->execute(['username' => $username]);
    $fullName = trim((string)($findName->fetchColumn() ?: ''));
    if ($fullName === '') {
        $fullName = $username;
    }

    $findVolunteer = $pdo->prepare(
        'SELECT volunteer_id
         FROM volunteers
         WHERE full_name = :full_name
         LIMIT 1'
    );
    $findVolunteer->execute(['full_name' => $fullName]);
    $volunteerId = (int)($findVolunteer->fetchColumn() ?: 0);

    if ($volunteerId <= 0) {
        respond(404, ['success' => false, 'message' => 'Volunteer not found']);
    }

    $update = $pdo->prepare(
        'UPDATE service_requests
         SET volunteer_lat = :volunteer_lat,
             volunteer_lng = :volunteer_lng,
             volunteer_location_updated_at = NOW()
         WHERE (request_id = :request_id_int OR external_request_id = :request_id_external)
           AND volunteer_id = :volunteer_id'
    );
    $update->execute([
        'volunteer_lat' => $lat,
        'volunteer_lng' => $lng,
        'request_id_int' => ctype_digit($requestId) ? (int)$requestId : -1,
        'request_id_external' => $requestId,
        'volunteer_id' => $volunteerId,
    ]);

    if ($update->rowCount() <= 0) {
        respond(403, ['success' => false, 'message' => 'Request is not assigned to this volunteer']);
    }

    respond(200, ['success' => true]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
