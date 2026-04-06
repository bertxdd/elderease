<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$identifier = trim((string)($input['identifier'] ?? ($input['username'] ?? '')));
$password = (string)($input['password'] ?? '');

if ($identifier === '' || $password === '') {
    respond(422, ['success' => false, 'message' => 'identifier and password are required']);
}

try {
    $pdo = db();

    $stmt = $pdo->prepare(
        'SELECT admin_id, full_name, username, password_hash, created_at
         FROM admins
         WHERE username = :username
         LIMIT 1'
    );
    $stmt->execute(['username' => $identifier]);
    $admin = $stmt->fetch();

    if (!$admin || !password_verify($password, (string)$admin['password_hash'])) {
        respond(401, ['success' => false, 'message' => 'Invalid admin username or password']);
    }

    respond(200, [
        'success' => true,
        'admin' => [
            'admin_id' => (int)$admin['admin_id'],
            'full_name' => (string)$admin['full_name'],
            'username' => (string)$admin['username'],
            'role' => 'admin',
            'created_at' => (string)($admin['created_at'] ?? ''),
        ],
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}