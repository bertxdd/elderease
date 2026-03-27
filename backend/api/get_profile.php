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
        'SELECT user_id, full_name, username, email, phone_number, birthday, address, created_at
         FROM users
         WHERE username = :username
         LIMIT 1'
    );
    $stmt->execute(['username' => $username]);
    $user = $stmt->fetch();

    if (!$user) {
        respond(404, ['success' => false, 'message' => 'User not found']);
    }

    respond(200, [
        'success' => true,
        'user' => [
            'user_id' => (int)$user['user_id'],
            'full_name' => (string)($user['full_name'] ?? ''),
            'username' => (string)($user['username'] ?? ''),
            'email' => (string)($user['email'] ?? ''),
            'phone_number' => (string)($user['phone_number'] ?? ''),
            'birthday' => (string)($user['birthday'] ?? ''),
            'address' => (string)($user['address'] ?? ''),
            'created_at' => (string)($user['created_at'] ?? ''),
        ],
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
