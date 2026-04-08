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

if ($requestId === '' || $username === '') {
    respond(422, ['success' => false, 'message' => 'request_id and username are required']);
}

try {
    $pdo = db();
    $pdo->beginTransaction();

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
        $insertVolunteer = $pdo->prepare(
            'INSERT INTO volunteers (full_name)
             VALUES (:full_name)'
        );
        $insertVolunteer->execute(['full_name' => $fullName]);
        $volunteerId = (int)$pdo->lastInsertId();
    }

    $activeCountStmt = $pdo->prepare(
        'SELECT COUNT(*)
         FROM service_requests
         WHERE volunteer_id = :volunteer_id
           AND status IN (:status_matched, :status_en_route, :status_arrived)'
    );
    $activeCountStmt->execute([
        'volunteer_id' => $volunteerId,
        'status_matched' => 'matched',
        'status_en_route' => 'en_route',
        'status_arrived' => 'arrived',
    ]);

    $activeCount = (int)($activeCountStmt->fetchColumn() ?: 0);
    if ($activeCount > 0) {
        $pdo->rollBack();
        respond(409, [
            'success' => false,
            'message' => 'You already have an active assigned request. Complete it first.',
        ]);
    }

    $update = $pdo->prepare(
        'UPDATE service_requests
         SET volunteer_id = :volunteer_id,
             status = :status_matched
         WHERE (request_id = :request_id_int OR external_request_id = :request_id_external)
           AND volunteer_id IS NULL
           AND status = :status_requested'
    );
    $update->execute([
        'volunteer_id' => $volunteerId,
        'status_matched' => 'matched',
        'request_id_int' => ctype_digit($requestId) ? (int)$requestId : -1,
        'request_id_external' => $requestId,
        'status_requested' => 'requested',
    ]);

    if ($update->rowCount() <= 0) {
        $pdo->rollBack();
        respond(409, ['success' => false, 'message' => 'Request already accepted']);
    }

    $pdo->commit();

    respond(200, [
        'success' => true,
        'message' => 'Request accepted',
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }

    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
