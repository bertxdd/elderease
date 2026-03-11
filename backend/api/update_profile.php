<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$username = trim((string)($input['username'] ?? ''));
$fullName = trim((string)($input['full_name'] ?? ''));
$email = trim((string)($input['email'] ?? ''));
$phone = trim((string)($input['phone_number'] ?? ''));
$birthday = trim((string)($input['birthday'] ?? ''));
$address = trim((string)($input['address'] ?? ''));

if ($username === '' || $fullName === '') {
    respond(422, ['success' => false, 'message' => 'username and full_name are required']);
}

if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    respond(422, ['success' => false, 'message' => 'Invalid email format']);
}

if ($birthday !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $birthday)) {
    respond(422, ['success' => false, 'message' => 'birthday must be YYYY-MM-DD']);
}

try {
    $pdo = db();

    if ($email !== '') {
      $checkEmail = $pdo->prepare(
          'SELECT user_id FROM users WHERE email = :email AND username <> :username LIMIT 1'
      );
      $checkEmail->execute([
          ':email' => $email,
          ':username' => $username,
      ]);
      if ($checkEmail->fetch()) {
          respond(409, ['success' => false, 'message' => 'Email already in use']);
      }
    }

    $update = $pdo->prepare(
        'UPDATE users
         SET full_name = :full_name,
             email = :email,
             phone_number = :phone_number,
             birthday = :birthday,
             address = :address
         WHERE username = :username'
    );

    $update->execute([
        ':full_name' => $fullName,
        ':email' => $email !== '' ? $email : null,
        ':phone_number' => $phone !== '' ? $phone : null,
        ':birthday' => $birthday !== '' ? $birthday : null,
        ':address' => $address !== '' ? $address : null,
        ':username' => $username,
    ]);

    if ($update->rowCount() === 0) {
        $exists = $pdo->prepare('SELECT user_id FROM users WHERE username = :username LIMIT 1');
        $exists->execute([':username' => $username]);
        if (!$exists->fetch()) {
            respond(404, ['success' => false, 'message' => 'User not found']);
        }
    }

    respond(200, ['success' => true, 'message' => 'Profile updated']);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
