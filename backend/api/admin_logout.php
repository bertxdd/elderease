<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/admin_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

try {
    $pdo = db();
    $admin = require_admin_auth($pdo);

    $stmt = $pdo->prepare('DELETE FROM admin_sessions WHERE session_id = :session_id');
    $stmt->execute(['session_id' => $admin['session_id']]);

    respond(200, [
        'success' => true,
        'message' => 'Logged out',
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}