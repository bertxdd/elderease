<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$requestId = trim((string)($input['request_id'] ?? ''));
$volunteerId = (int)($input['volunteer_id'] ?? 0);

if ($requestId === '' || $volunteerId <= 0) {
    respond(422, ['success' => false, 'message' => 'request_id and volunteer_id are required']);
}

try {
    $pdo = db();

    $checkVolunteer = $pdo->prepare('SELECT volunteer_id FROM volunteers WHERE volunteer_id = :volunteer_id LIMIT 1');
    $checkVolunteer->execute([':volunteer_id' => $volunteerId]);
    if (!$checkVolunteer->fetch()) {
        respond(404, ['success' => false, 'message' => 'Volunteer not found']);
    }

    $update = $pdo->prepare(
        'UPDATE service_requests
         SET volunteer_id = :volunteer_id, status = :status
         WHERE request_id = :request_id OR external_request_id = :external_request_id'
    );
    $update->execute([
        ':volunteer_id' => $volunteerId,
        ':status' => 'matched',
        ':request_id' => ctype_digit($requestId) ? (int)$requestId : -1,
        ':external_request_id' => $requestId,
    ]);

    respond(200, [
        'success' => true,
        'updated_rows' => $update->rowCount(),
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
