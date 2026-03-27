<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$username = trim((string)($_GET['username'] ?? ''));
$scope = strtolower(trim((string)($_GET['scope'] ?? 'open')));
if ($username === '') {
    respond(422, ['success' => false, 'message' => 'username is required']);
}

if (!in_array($scope, ['open', 'assigned'], true)) {
    respond(422, ['success' => false, 'message' => 'scope must be open or assigned']);
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

    if ($scope === 'open') {
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
                NULL AS helper_name
             FROM service_requests r
             INNER JOIN users u ON u.user_id = r.user_id
             WHERE r.status = :status_requested
               AND r.volunteer_id IS NULL
             ORDER BY r.created_at DESC'
        );
        $stmt->execute(['status_requested' => 'requested']);
    } else {
        if ($volunteerId <= 0) {
            respond(200, ['success' => true, 'data' => []]);
        }

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
             WHERE r.volunteer_id = :volunteer_id
               AND r.status IN (:status_matched, :status_en_route, :status_arrived)
             ORDER BY r.created_at DESC'
        );
        $stmt->execute([
            'volunteer_id' => $volunteerId,
            'status_matched' => 'matched',
            'status_en_route' => 'en_route',
            'status_arrived' => 'arrived',
        ]);
    }

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
