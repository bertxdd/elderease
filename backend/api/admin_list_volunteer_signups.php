<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/admin_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$status = strtolower(trim((string)($_GET['status'] ?? 'pending')));
$allowedStatuses = ['pending', 'approved', 'rejected', 'all'];
if (!in_array($status, $allowedStatuses, true)) {
    respond(422, ['success' => false, 'message' => 'Invalid status filter']);
}

try {
    $pdo = db();
    $admin = require_admin_auth($pdo);

    $sql =
        'SELECT
            s.signup_id,
            s.full_name,
            s.username,
            s.email,
            s.phone_number,
            s.birthday,
            s.address,
            s.status,
            s.admin_note,
            s.created_at,
            s.reviewed_at,
            s.approved_user_id,
            s.approved_volunteer_id,
            a.username AS reviewed_by
         FROM volunteer_signup_requests s
         LEFT JOIN admins a ON a.admin_id = s.reviewed_by_admin_id';

    $params = [];
    if ($status !== 'all') {
        $sql .= ' WHERE s.status = :status';
        $params['status'] = $status;
    }

    $sql .= ' ORDER BY s.created_at DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $rows = [];
    foreach ($stmt->fetchAll() as $row) {
        $rows[] = [
            'signup_id' => (int)$row['signup_id'],
            'full_name' => (string)$row['full_name'],
            'username' => (string)$row['username'],
            'email' => (string)($row['email'] ?? ''),
            'phone_number' => (string)($row['phone_number'] ?? ''),
            'birthday' => (string)($row['birthday'] ?? ''),
            'address' => (string)($row['address'] ?? ''),
            'status' => (string)$row['status'],
            'admin_note' => (string)($row['admin_note'] ?? ''),
            'created_at' => (string)$row['created_at'],
            'reviewed_at' => (string)($row['reviewed_at'] ?? ''),
            'reviewed_by' => (string)($row['reviewed_by'] ?? ''),
            'approved_user_id' => $row['approved_user_id'] !== null ? (int)$row['approved_user_id'] : null,
            'approved_volunteer_id' => $row['approved_volunteer_id'] !== null ? (int)$row['approved_volunteer_id'] : null,
        ];
    }

    respond(200, [
        'success' => true,
        'admin' => [
            'username' => $admin['username'],
            'full_name' => $admin['full_name'],
        ],
        'data' => $rows,
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}