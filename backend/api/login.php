<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$username = trim((string)($input['username'] ?? ''));
$password = (string)($input['password'] ?? '');

if ($username === '' || $password === '') {
    respond(422, ['success' => false, 'message' => 'username and password are required']);
}

try {
    $pdo = db();

    $stmt = $pdo->prepare(
        'SELECT user_id, full_name, username, email, password_hash, phone_number, address
         FROM users
         WHERE username = :username
         LIMIT 1'
    );
    $stmt->execute([':username' => $username]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, (string)$user['password_hash'])) {
        respond(401, ['success' => false, 'message' => 'Invalid username or password']);
    }

    respond(200, [
        'success' => true,
        'user' => [
            'user_id' => (int)$user['user_id'],
            'full_name' => (string)$user['full_name'],
            'username' => (string)$user['username'],
            'email' => (string)($user['email'] ?? ''),
            'phone_number' => (string)($user['phone_number'] ?? ''),
            'address' => (string)($user['address'] ?? ''),
        ],
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
