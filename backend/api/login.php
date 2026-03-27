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
$role = strtolower(trim((string)($input['role'] ?? 'user')));

if ($identifier === '' || $password === '') {
    respond(422, ['success' => false, 'message' => 'identifier and password are required']);
}

if (!in_array($role, ['user', 'volunteer'], true)) {
    respond(422, ['success' => false, 'message' => 'role must be user or volunteer']);
}

try {
    $pdo = db();

    $stmt = $pdo->prepare(
        'SELECT user_id, full_name, username, role, email, password_hash, phone_number, birthday, address, created_at
         FROM users
            WHERE username = :identifier_username OR email = :identifier_email
         LIMIT 1'
    );
        $stmt->execute([
            'identifier_username' => $identifier,
            'identifier_email' => $identifier,
        ]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, (string)$user['password_hash'])) {
        respond(401, ['success' => false, 'message' => 'Invalid username or password']);
    }

    $storedRole = strtolower((string)($user['role'] ?? 'user'));
    if ($storedRole !== $role) {
        respond(403, ['success' => false, 'message' => 'Role mismatch for this account']);
    }

    respond(200, [
        'success' => true,
        'user' => [
            'user_id' => (int)$user['user_id'],
            'full_name' => (string)$user['full_name'],
            'username' => (string)$user['username'],
            'role' => $storedRole,
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
