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

if ($requestId === '') {
    respond(422, ['success' => false, 'message' => 'request_id is required']);
}

try {
    $pdo = db();

    $sql = 'UPDATE service_requests SET status = :status';
    $params = [':status' => $status];

    if ($volunteerId > 0) {
        $sql .= ', volunteer_id = :volunteer_id';
        $params[':volunteer_id'] = $volunteerId;
    }

    $sql .= ' WHERE request_id = :request_id OR external_request_id = :external_request_id';
    $params[':request_id'] = ctype_digit($requestId) ? (int)$requestId : -1;
    $params[':external_request_id'] = $requestId;

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
