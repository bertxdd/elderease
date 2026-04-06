<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$adminUsername = trim((string)($_GET['admin_username'] ?? ''));
if ($adminUsername === '') {
    respond(422, ['success' => false, 'message' => 'admin_username is required']);
}

try {
    $pdo = db();

    $checkAdmin = $pdo->prepare(
        'SELECT admin_id
         FROM admins
         WHERE username = :username
         LIMIT 1'
    );
    $checkAdmin->execute(['username' => $adminUsername]);
    if (!$checkAdmin->fetch()) {
        respond(403, ['success' => false, 'message' => 'Admin account not found']);
    }

    $stmt = $pdo->query(
        'SELECT volunteer_id, full_name, phone_number, rating_avg, is_verified, created_at
         FROM volunteers
         ORDER BY full_name ASC'
    );

    $data = [];
    foreach ($stmt->fetchAll() as $row) {
        $data[] = [
            'volunteer_id' => (int)$row['volunteer_id'],
            'full_name' => (string)$row['full_name'],
            'phone_number' => (string)($row['phone_number'] ?? ''),
            'rating_avg' => (float)($row['rating_avg'] ?? 0),
            'is_verified' => ((int)($row['is_verified'] ?? 0)) === 1,
            'created_at' => (string)($row['created_at'] ?? ''),
        ];
    }

    respond(200, ['success' => true, 'data' => $data]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}