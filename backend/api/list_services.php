<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

try {
    $pdo = db();
    $stmt = $pdo->query(
        'SELECT service_id, service_name, description
         FROM services
         WHERE is_active = 1
         ORDER BY service_name ASC'
    );

    $services = [];
    foreach ($stmt->fetchAll() as $row) {
        $services[] = [
            'id' => (string)$row['service_id'],
            'name' => (string)$row['service_name'],
            'description' => (string)($row['description'] ?? ''),
        ];
    }

    respond(200, ['success' => true, 'data' => $services]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
