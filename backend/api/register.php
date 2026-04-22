<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

function save_certification_image(string $base64Payload, string $username): array
{
    if ($base64Payload === '') {
        return ['', ''];
    }

    $mime = 'image/jpeg';
    $rawBase64 = $base64Payload;
    if (preg_match('/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/', $base64Payload, $parts) === 1) {
        $mime = strtolower(trim((string)$parts[1]));
        $rawBase64 = (string)$parts[2];
    }

    $allowedMimeToExtension = [
        'image/jpeg' => 'jpg',
        'image/jpg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];

    if (!isset($allowedMimeToExtension[$mime])) {
        respond(422, ['success' => false, 'message' => 'Certification image must be JPG, PNG, or WEBP']);
    }

    $decoded = base64_decode($rawBase64, true);
    if ($decoded === false) {
        respond(422, ['success' => false, 'message' => 'Certification image is not valid base64']);
    }

    if (strlen($decoded) > 5 * 1024 * 1024) {
        respond(422, ['success' => false, 'message' => 'Certification image must be 5MB or less']);
    }

    $uploadDir = __DIR__ . '/uploads/volunteer_certifications';
    if (!is_dir($uploadDir) && !mkdir($uploadDir, 0755, true) && !is_dir($uploadDir)) {
        respond(500, ['success' => false, 'message' => 'Unable to prepare certification upload directory']);
    }

    $sanitizedUsername = preg_replace('/[^a-zA-Z0-9_-]/', '', strtolower($username));
    $timestamp = date('YmdHis');
    $extension = $allowedMimeToExtension[$mime];
    $fileName = sprintf('%s_%s_%s.%s', $sanitizedUsername !== '' ? $sanitizedUsername : 'volunteer', $timestamp, bin2hex(random_bytes(4)), $extension);
    $filePath = $uploadDir . '/' . $fileName;

    if (file_put_contents($filePath, $decoded) === false) {
        respond(500, ['success' => false, 'message' => 'Failed to store certification image']);
    }

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = (string)($_SERVER['HTTP_HOST'] ?? '');
    $basePath = rtrim(str_replace('\\', '/', dirname((string)($_SERVER['SCRIPT_NAME'] ?? '/api/register.php'))), '/');
    $basePath = $basePath !== '' ? $basePath : '/api';
    $publicUrl = sprintf('%s://%s%s/uploads/volunteer_certifications/%s', $scheme, $host, $basePath, rawurlencode($fileName));

    return [$publicUrl, $fileName];
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$fullName = trim((string)($input['full_name'] ?? ''));
$username = trim((string)($input['username'] ?? ''));
$email = trim((string)($input['email'] ?? ''));
$password = (string)($input['password'] ?? '');
$role = strtolower(trim((string)($input['role'] ?? 'user')));
$phone = trim((string)($input['phone_number'] ?? ''));
$birthday = trim((string)($input['birthday'] ?? ''));
$address = trim((string)($input['address'] ?? ''));
$certificationImageBase64 = trim((string)($input['certification_image_base64'] ?? ''));

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

if (!in_array($role, ['user', 'volunteer'], true)) {
    respond(422, ['success' => false, 'message' => 'role must be user or volunteer']);
}

if ($role === 'volunteer' && $certificationImageBase64 === '') {
    respond(422, ['success' => false, 'message' => 'certification_image_base64 is required for volunteer signup']);
}

try {
    $pdo = db();

    $check = $pdo->prepare('SELECT user_id FROM users WHERE username = :username LIMIT 1');
    $check->execute(['username' => $username]);
    if ($check->fetch()) {
        respond(409, ['success' => false, 'message' => 'Username already exists']);
    }

    if ($email !== '') {
        $checkEmail = $pdo->prepare('SELECT user_id FROM users WHERE email = :email LIMIT 1');
        $checkEmail->execute(['email' => $email]);
        if ($checkEmail->fetch()) {
            respond(409, ['success' => false, 'message' => 'Email already exists']);
        }
    }

    if ($role === 'volunteer') {
        [$certificationImageUrl, $certificationImageName] = save_certification_image($certificationImageBase64, $username);

        $checkPendingUsername = $pdo->prepare(
            'SELECT signup_id
             FROM volunteer_signup_requests
             WHERE username = :username
               AND status = :status
             LIMIT 1'
        );
        $checkPendingUsername->execute([
            'username' => $username,
            'status' => 'pending',
        ]);
        if ($checkPendingUsername->fetch()) {
            respond(409, ['success' => false, 'message' => 'Volunteer application is already pending for this username']);
        }

        if ($email !== '') {
            $checkPendingEmail = $pdo->prepare(
                'SELECT signup_id
                 FROM volunteer_signup_requests
                 WHERE email = :email
                   AND status = :status
                 LIMIT 1'
            );
            $checkPendingEmail->execute([
                'email' => $email,
                'status' => 'pending',
            ]);
            if ($checkPendingEmail->fetch()) {
                respond(409, ['success' => false, 'message' => 'Volunteer application is already pending for this email']);
            }
        }

        $insertPending = $pdo->prepare(
            'INSERT INTO volunteer_signup_requests
             (full_name, username, email, password_hash, phone_number, birthday, address, certification_image_url, certification_image_name, status)
             VALUES (:full_name, :username, :email, :password_hash, :phone_number, :birthday, :address, :certification_image_url, :certification_image_name, :status)'
        );
        $insertPending->execute([
            'full_name' => $fullName,
            'username' => $username,
            'email' => $email !== '' ? $email : null,
            'password_hash' => password_hash($password, PASSWORD_BCRYPT),
            'phone_number' => $phone !== '' ? $phone : null,
            'birthday' => $birthday !== '' ? $birthday : null,
            'address' => $address !== '' ? $address : null,
            'certification_image_url' => $certificationImageUrl !== '' ? $certificationImageUrl : null,
            'certification_image_name' => $certificationImageName !== '' ? $certificationImageName : null,
            'status' => 'pending',
        ]);

        respond(201, [
            'success' => true,
            'message' => 'Volunteer sign up submitted. Please wait for admin approval before logging in.',
            'signup' => [
                'signup_id' => (int)$pdo->lastInsertId(),
                'full_name' => $fullName,
                'username' => $username,
                'email' => $email,
                'phone_number' => $phone,
                'birthday' => $birthday,
                'address' => $address,
                'certification_image_url' => $certificationImageUrl,
                'certification_image_name' => $certificationImageName,
                'status' => 'pending',
            ],
        ]);
    }

    $insert = $pdo->prepare(
        'INSERT INTO users (full_name, username, role, email, password_hash, phone_number, birthday, address)
         VALUES (:full_name, :username, :role, :email, :password_hash, :phone_number, :birthday, :address)'
    );
    $insert->execute([
        'full_name' => $fullName,
        'username' => $username,
        'role' => $role,
        'email' => $email !== '' ? $email : null,
        'password_hash' => password_hash($password, PASSWORD_BCRYPT),
        'phone_number' => $phone !== '' ? $phone : null,
        'birthday' => $birthday !== '' ? $birthday : null,
        'address' => $address !== '' ? $address : null,
    ]);

    respond(201, [
        'success' => true,
        'user' => [
            'user_id' => (int)$pdo->lastInsertId(),
            'full_name' => $fullName,
            'username' => $username,
            'role' => $role,
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
