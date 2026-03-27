<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/utils.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$requestId = trim((string)($input['request_id'] ?? ''));
$status = normalize_status((string)($input['status'] ?? 'requested'));
$volunteerId = (int)($input['volunteer_id'] ?? 0);
$username = trim((string)($input['username'] ?? ''));

if ($requestId === '') {
    respond(422, ['success' => false, 'message' => 'request_id is required']);
}

try {
    $pdo = db();

    $resolvedVolunteerId = $volunteerId;
    if ($resolvedVolunteerId <= 0 && $username !== '') {
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
        $resolvedVolunteerId = (int)($findVolunteer->fetchColumn() ?: 0);
    }

    $requiresAssignedVolunteer = in_array($status, ['en_route', 'arrived', 'completed'], true);
    if ($requiresAssignedVolunteer && $resolvedVolunteerId <= 0) {
        respond(422, ['success' => false, 'message' => 'username or volunteer_id is required for this status']);
    }

    $sql = 'UPDATE service_requests SET status = :status';
    $params = ['status' => $status];

    if ($resolvedVolunteerId > 0) {
        $sql .= ', volunteer_id = :volunteer_id';
        $params['volunteer_id'] = $resolvedVolunteerId;
    }

    $sql .= ' WHERE request_id = :request_id OR external_request_id = :external_request_id';
    $params['request_id'] = ctype_digit($requestId) ? (int)$requestId : -1;
    $params['external_request_id'] = $requestId;

    if ($requiresAssignedVolunteer) {
        $sql .= ' AND volunteer_id = :assigned_volunteer_id';
        $params['assigned_volunteer_id'] = $resolvedVolunteerId;
    }

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    respond(200, [
        'success' => true,
        'updated_rows' => $stmt->rowCount(),
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
