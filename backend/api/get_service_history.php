<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$username = trim((string)($_GET['username'] ?? ''));
$role = trim((string)($_GET['role'] ?? ''));

if ($username === '' || $role === '') {
    respond(422, ['success' => false, 'message' => 'username and role are required']);
}

try {
    $pdo = db();

    if ($role === 'user') {
        // Get completed service history for users
        $stmt = $pdo->prepare(
            'SELECT
                r.request_id,
                r.external_request_id,
                u.username,
                r.schedule_datetime,
                r.address,
                r.status,
                r.notes,
                r.created_at,
                r.updated_at,
                v.full_name AS volunteer_name,
                v.rating_avg,
                f.rating_score,
                f.comments AS feedback_comments
             FROM service_requests r
             INNER JOIN users u ON u.user_id = r.user_id
             LEFT JOIN volunteers v ON v.volunteer_id = r.volunteer_id
             LEFT JOIN feedback f ON f.request_id = r.request_id
             WHERE u.username = :username
               AND r.status = :status_completed
             ORDER BY r.updated_at DESC'
        );
        $stmt->execute([
            'username' => $username,
            'status_completed' => 'completed',
        ]);
    } elseif ($role === 'volunteer') {
        // Get completed service history for volunteers
        $stmt = $pdo->prepare(
            'SELECT
                r.request_id,
                r.external_request_id,
                u.username,
                u.full_name AS user_name,
                r.schedule_datetime,
                r.address,
                r.status,
                r.notes,
                r.created_at,
                r.updated_at,
                v.full_name AS volunteer_name,
                v.rating_avg,
                f.rating_score,
                f.comments AS feedback_comments
             FROM service_requests r
             INNER JOIN users u ON u.user_id = r.user_id
             INNER JOIN volunteers v ON v.volunteer_id = r.volunteer_id
             LEFT JOIN feedback f ON f.request_id = r.request_id
             WHERE v.full_name IN (
                SELECT full_name FROM volunteers 
                WHERE volunteer_id = (
                    SELECT volunteer_id FROM volunteers 
                    WHERE full_name = (
                        SELECT full_name FROM volunteers 
                        LIMIT 1
                    )
                )
             )
               AND r.status = :status_completed
             ORDER BY r.updated_at DESC'
        );
        // Simpler approach: get volunteer_id from volunteers table using full_name
        $getVolStmt = $pdo->prepare('SELECT volunteer_id FROM volunteers WHERE full_name = :full_name LIMIT 1');
        $getVolStmt->execute(['full_name' => $username]);
        $volRow = $getVolStmt->fetch();
        
        if (!$volRow) {
            respond(404, ['success' => false, 'message' => 'Volunteer not found']);
        }

        $volunteerId = (int)$volRow['volunteer_id'];

        $stmt = $pdo->prepare(
            'SELECT
                r.request_id,
                r.external_request_id,
                u.username,
                u.full_name AS user_name,
                r.schedule_datetime,
                r.address,
                r.status,
                r.notes,
                r.created_at,
                r.updated_at,
                v.full_name AS volunteer_name,
                v.rating_avg,
                f.rating_score,
                f.comments AS feedback_comments
             FROM service_requests r
             INNER JOIN users u ON u.user_id = r.user_id
             INNER JOIN volunteers v ON v.volunteer_id = r.volunteer_id
             LEFT JOIN feedback f ON f.request_id = r.request_id
             WHERE v.volunteer_id = :volunteer_id
               AND r.status = :status_completed
             ORDER BY r.updated_at DESC'
        );
        $stmt->execute([
            'volunteer_id' => $volunteerId,
            'status_completed' => 'completed',
        ]);
    } else {
        respond(422, ['success' => false, 'message' => 'Invalid role']);
    }

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

        $historyItem = [
            'id' => (string)($row['external_request_id'] ?: $requestId),
            'username' => (string)$row['username'],
            'services' => $services,
            'scheduled_at' => (string)$row['schedule_datetime'],
            'address' => (string)$row['address'],
            'notes' => (string)($row['notes'] ?? ''),
            'status' => (string)$row['status'],
            'created_at' => (string)$row['created_at'],
            'updated_at' => (string)$row['updated_at'],
            'rating' => $row['rating_score'] !== null ? (int)$row['rating_score'] : null,
            'feedback' => $row['feedback_comments'] !== null ? (string)$row['feedback_comments'] : null,
        ];

        if ($role === 'user') {
            $historyItem['volunteer_name'] = $row['volunteer_name'] !== null ? (string)$row['volunteer_name'] : null;
            $historyItem['volunteer_rating'] = $row['rating_avg'] !== null ? (float)$row['rating_avg'] : null;
        } else {
            $historyItem['user_name'] = $row['user_name'] !== null ? (string)$row['user_name'] : null;
        }

        $data[] = $historyItem;
    }

    respond(200, ['success' => true, 'data' => $data]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
