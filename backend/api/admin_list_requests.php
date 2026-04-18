<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/admin_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$status = strtolower(trim((string)($_GET['status'] ?? 'all')));

$allowedStatuses = ['all', 'requested', 'matched', 'en_route', 'arrived', 'completed', 'cancelled'];
if (!in_array($status, $allowedStatuses, true)) {
    respond(422, ['success' => false, 'message' => 'Invalid status filter']);
}

try {
    $pdo = db();
    $admin = require_admin_auth($pdo);

    $sql =
        'SELECT
            r.request_id,
            r.external_request_id,
            u.username,
            u.full_name AS user_full_name,
            r.schedule_datetime,
            r.address,
            r.status,
            r.notes,
            r.created_at,
            r.updated_at,
            v.volunteer_id,
            v.full_name AS helper_name
         FROM service_requests r
         INNER JOIN users u ON u.user_id = r.user_id
         LEFT JOIN volunteers v ON v.volunteer_id = r.volunteer_id';

    $params = [];
    if ($status !== 'all') {
        $sql .= ' WHERE r.status = :status';
        $params['status'] = $status;
    }

    $sql .= ' ORDER BY r.created_at DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    $serviceStmt = $pdo->prepare(
        'SELECT
            ri.service_id,
            s.service_name,
            ri.quantity
         FROM request_items ri
         INNER JOIN services s ON s.service_id = ri.service_id AND s.is_active = 1
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
            'request_id' => (string)$requestId,
            'username' => (string)$row['username'],
            'user_full_name' => (string)($row['user_full_name'] ?? ''),
            'services' => $services,
            'scheduled_at' => (string)$row['schedule_datetime'],
            'address' => (string)$row['address'],
            'notes' => (string)($row['notes'] ?? ''),
            'status' => (string)$row['status'],
            'created_at' => (string)$row['created_at'],
            'updated_at' => (string)$row['updated_at'],
            'volunteer_id' => $row['volunteer_id'] !== null ? (int)$row['volunteer_id'] : null,
            'helper_name' => $row['helper_name'] !== null ? (string)$row['helper_name'] : null,
        ];
    }

    respond(200, [
        'success' => true,
        'admin' => [
            'username' => $admin['username'],
            'full_name' => $admin['full_name'],
        ],
        'data' => $data,
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}