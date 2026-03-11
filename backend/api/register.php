<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$fullName = trim((string)($input['full_name'] ?? ''));
$username = trim((string)($input['username'] ?? ''));
$email = trim((string)($input['email'] ?? ''));
$password = (string)($input['password'] ?? '');
$phone = trim((string)($input['phone_number'] ?? ''));
$birthday = trim((string)($input['birthday'] ?? ''));
$address = trim((string)($input['address'] ?? ''));

if ($fullName === '' || $username === '' || $password === '') {
    respond(422, ['success' => false, 'message' => 'full_name, username, and password are required']);
}

if (strlen($password) < 6) {
    respond(422, ['success' => false, 'message' => 'Password must be at least 6 characters']);
}

if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(422, ['success' => false, 'message' => 'Invalid email format']);
}

if ($birthday !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $birthday)) {
    respond(422, ['success' => false, 'message' => 'birthday must be YYYY-MM-DD']);
}

try {
    $pdo = db();

    $check = $pdo->prepare('SELECT user_id FROM users WHERE username = :username LIMIT 1');
    $check->execute([':username' => $username]);
    if ($check->fetch()) {
        respond(409, ['success' => false, 'message' => 'Username already exists']);
    }

    if ($email !== '') {
        $checkEmail = $pdo->prepare('SELECT user_id FROM users WHERE email = :email LIMIT 1');
        $checkEmail->execute([':email' => $email]);
        if ($checkEmail->fetch()) {
            respond(409, ['success' => false, 'message' => 'Email already exists']);
        }
    }

    $insert = $pdo->prepare(
        'INSERT INTO users (full_name, username, email, password_hash, phone_number, birthday, address)
         VALUES (:full_name, :username, :email, :password_hash, :phone_number, :birthday, :address)'
    );
    $insert->execute([
        ':full_name' => $fullName,
        ':username' => $username,
        ':email' => $email !== '' ? $email : null,
        ':password_hash' => password_hash($password, PASSWORD_BCRYPT),
        ':phone_number' => $phone !== '' ? $phone : null,
        ':birthday' => $birthday !== '' ? $birthday : null,
        ':address' => $address !== '' ? $address : null,
    ]);

    respond(201, [
        'success' => true,
        'user' => [
            'user_id' => (int)$pdo->lastInsertId(),
            'full_name' => $fullName,
            'username' => $username,
            'email' => $email,
            'phone_number' => $phone,
            'birthday' => $birthday,
            'address' => $address,
        ],
    ]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
