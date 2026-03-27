<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$username = trim((string)($_GET['username'] ?? ''));
if ($username === '') {
    respond(422, ['success' => false, 'message' => 'username is required']);
}

try {
    $pdo = db();

    $stmt = $pdo->prepare(
        'SELECT
            r.request_id,
            r.external_request_id,
            u.username,
            r.schedule_datetime,
            r.address,
            r.status,
            r.notes,
            r.volunteer_lat,
            r.volunteer_lng,
            r.volunteer_location_updated_at,
            r.created_at,
            v.full_name AS helper_name
         FROM service_requests r
         INNER JOIN users u ON u.user_id = r.user_id
         LEFT JOIN volunteers v ON v.volunteer_id = r.volunteer_id
         WHERE u.username = :username
         ORDER BY r.created_at DESC'
    );
    $stmt->execute(['username' => $username]);
    $rows = $stmt->fetchAll();

    $serviceStmt = $pdo->prepare(
        'SELECT
            ri.service_id,
            s.service_name,
            ri.quantity
         FROM request_items ri
         INNER JOIN services s ON s.service_id = ri.service_id
         WHERE ri.request_id = :request_id'
    );

    $data = [];

    foreach ($rows as $row) {
        $requestId = (int)$row['request_id'];

        $serviceStmt->execute(['request_id' => $requestId]);
        $serviceRows = $serviceStmt->fetchAll();

        $services = [];
        foreach ($serviceRows as $svc) {
            $services[] = [
                'id' => (string)$svc['service_id'],
                'name' => (string)$svc['service_name'],
                'quantity' => (int)$svc['quantity'],
            ];
        }

        $data[] = [
            'id' => (string)($row['external_request_id'] ?: $requestId),
            'username' => (string)$row['username'],
            'services' => $services,
            'scheduled_at' => (string)$row['schedule_datetime'],
            'address' => (string)$row['address'],
            'notes' => (string)($row['notes'] ?? ''),
            'status' => (string)$row['status'],
            'created_at' => (string)$row['created_at'],
            'synced' => true,
            'helper_name' => $row['helper_name'] !== null ? (string)$row['helper_name'] : null,
            'volunteer_lat' => $row['volunteer_lat'] !== null ? (float)$row['volunteer_lat'] : null,
            'volunteer_lng' => $row['volunteer_lng'] !== null ? (float)$row['volunteer_lng'] : null,
            'volunteer_location_updated_at' => $row['volunteer_location_updated_at'] !== null
                ? (string)$row['volunteer_location_updated_at']
                : null,
        ];
    }

    respond(200, ['success' => true, 'data' => $data]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
