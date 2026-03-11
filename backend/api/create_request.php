<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/utils.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$username = trim((string)($input['username'] ?? ''));
$scheduledAt = trim((string)($input['scheduled_at'] ?? ''));
$address = trim((string)($input['address'] ?? ''));
$notes = trim((string)($input['notes'] ?? ''));
$status = normalize_status((string)($input['status'] ?? 'requested'));
$externalRequestId = trim((string)($input['id'] ?? ''));
$services = is_array($input['services'] ?? null) ? $input['services'] : [];

if ($username === '' || $scheduledAt === '' || $address === '' || empty($services)) {
    respond(422, ['success' => false, 'message' => 'Missing required fields']);
}

try {
    $pdo = db();
    $pdo->beginTransaction();

    // Ensure user exists. In production, replace this with authenticated user ID.
    $findUser = $pdo->prepare('SELECT user_id FROM users WHERE username = :username LIMIT 1');
    $findUser->execute([':username' => $username]);
    $userId = (int)($findUser->fetchColumn() ?: 0);

    if ($userId <= 0) {
        $insertUser = $pdo->prepare(
            'INSERT INTO users (full_name, username, password_hash) VALUES (:full_name, :username, :password_hash)'
        );
        $insertUser->execute([
            ':full_name' => $username,
            ':username' => $username,
            ':password_hash' => password_hash('temporary', PASSWORD_BCRYPT),
        ]);
        $userId = (int)$pdo->lastInsertId();
    }

    // Prevent duplicate request insert if the same external ID was already submitted.
    if ($externalRequestId !== '') {
        $dup = $pdo->prepare(
            'SELECT request_id FROM service_requests WHERE external_request_id = :external_request_id LIMIT 1'
        );
        $dup->execute([':external_request_id' => $externalRequestId]);
        $existingId = (int)($dup->fetchColumn() ?: 0);
        if ($existingId > 0) {
            $pdo->rollBack();
            respond(200, ['success' => true, 'request_id' => $existingId, 'message' => 'Already exists']);
        }
    }

    $insertRequest = $pdo->prepare(
        'INSERT INTO service_requests
            (external_request_id, user_id, schedule_datetime, address, status, notes)
         VALUES
            (:external_request_id, :user_id, :schedule_datetime, :address, :status, :notes)'
    );

    $insertRequest->execute([
        ':external_request_id' => $externalRequestId !== '' ? $externalRequestId : null,
        ':user_id' => $userId,
        ':schedule_datetime' => date('Y-m-d H:i:s', strtotime($scheduledAt)),
        ':address' => $address,
        ':status' => $status,
        ':notes' => $notes,
    ]);

    $requestId = (int)$pdo->lastInsertId();

    $insertItem = $pdo->prepare(
                'INSERT INTO request_items (request_id, service_id, quantity)
                 VALUES (:request_id, :service_id, :quantity)
         ON DUPLICATE KEY UPDATE
                     quantity = VALUES(quantity)'
    );

    $upsertService = $pdo->prepare(
                'INSERT INTO services (service_id, service_name, description)
                 VALUES (:service_id, :service_name, :description)
         ON DUPLICATE KEY UPDATE
           service_name = VALUES(service_name),
           description = VALUES(description)'
    );

    foreach ($services as $svc) {
        if (!is_array($svc)) {
            continue;
        }

        $serviceId = (int)($svc['id'] ?? 0);
        $serviceName = trim((string)($svc['name'] ?? 'Unnamed Service'));
        $quantity = max(1, (int)($svc['quantity'] ?? 1));

        if ($serviceId <= 0) {
            // For non-numeric IDs, auto-create service and use generated ID.
            $insertNewService = $pdo->prepare(
                'INSERT INTO services (service_name, description) VALUES (:service_name, :description)'
            );
            $insertNewService->execute([
                ':service_name' => $serviceName,
                ':description' => 'Auto-created from mobile request',
            ]);
            $serviceId = (int)$pdo->lastInsertId();
        } else {
            $upsertService->execute([
                ':service_id' => $serviceId,
                ':service_name' => $serviceName,
                ':description' => 'Synced from mobile request',
            ]);
        }

        $insertItem->execute([
            ':request_id' => $requestId,
            ':service_id' => $serviceId,
            ':quantity' => $quantity,
        ]);
    }

    $pdo->commit();

    respond(200, [
        'success' => true,
        'status' => 'ok',
        'request_id' => $requestId,
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
