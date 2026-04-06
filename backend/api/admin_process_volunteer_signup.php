<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/admin_auth.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$signupId = (int)($input['signup_id'] ?? 0);
$action = strtolower(trim((string)($input['action'] ?? '')));
$adminNote = trim((string)($input['admin_note'] ?? ''));

if ($signupId <= 0) {
    respond(422, ['success' => false, 'message' => 'signup_id is required']);
}

if (!in_array($action, ['approve', 'reject'], true)) {
    respond(422, ['success' => false, 'message' => 'action must be approve or reject']);
}

try {
    $pdo = db();
    $admin = require_admin_auth($pdo);
    $pdo->beginTransaction();

    $signupStmt = $pdo->prepare(
        'SELECT
            signup_id,
            full_name,
            username,
            email,
            password_hash,
            phone_number,
            birthday,
            address,
            status
         FROM volunteer_signup_requests
         WHERE signup_id = :signup_id
         LIMIT 1
         FOR UPDATE'
    );
    $signupStmt->execute(['signup_id' => $signupId]);
    $signup = $signupStmt->fetch();

    if (!$signup) {
        $pdo->rollBack();
        respond(404, ['success' => false, 'message' => 'Signup request not found']);
    }

    if ((string)$signup['status'] !== 'pending') {
        $pdo->rollBack();
        respond(409, ['success' => false, 'message' => 'Signup request has already been reviewed']);
    }

    if ($action === 'reject') {
        $rejectStmt = $pdo->prepare(
            'UPDATE volunteer_signup_requests
             SET status = :status,
                 admin_note = :admin_note,
                 reviewed_at = NOW(),
                 reviewed_by_admin_id = :admin_id
             WHERE signup_id = :signup_id'
        );
        $rejectStmt->execute([
            'status' => 'rejected',
            'admin_note' => $adminNote !== '' ? $adminNote : null,
            'admin_id' => $admin['admin_id'],
            'signup_id' => $signupId,
        ]);

        $pdo->commit();
        respond(200, ['success' => true, 'message' => 'Volunteer signup rejected']);
    }

    $username = (string)$signup['username'];
    $email = (string)($signup['email'] ?? '');

    $checkUser = $pdo->prepare('SELECT user_id FROM users WHERE username = :username LIMIT 1');
    $checkUser->execute(['username' => $username]);
    if ($checkUser->fetch()) {
        $pdo->rollBack();
        respond(409, ['success' => false, 'message' => 'Username already exists in users']);
    }

    if ($email !== '') {
        $checkEmail = $pdo->prepare('SELECT user_id FROM users WHERE email = :email LIMIT 1');
        $checkEmail->execute(['email' => $email]);
        if ($checkEmail->fetch()) {
            $pdo->rollBack();
            respond(409, ['success' => false, 'message' => 'Email already exists in users']);
        }
    }

    $insertUser = $pdo->prepare(
        'INSERT INTO users (full_name, username, role, email, password_hash, phone_number, birthday, address)
         VALUES (:full_name, :username, :role, :email, :password_hash, :phone_number, :birthday, :address)'
    );
    $insertUser->execute([
        'full_name' => (string)$signup['full_name'],
        'username' => $username,
        'role' => 'volunteer',
        'email' => $email !== '' ? $email : null,
        'password_hash' => (string)$signup['password_hash'],
        'phone_number' => ((string)($signup['phone_number'] ?? '')) !== '' ? (string)$signup['phone_number'] : null,
        'birthday' => ((string)($signup['birthday'] ?? '')) !== '' ? (string)$signup['birthday'] : null,
        'address' => ((string)($signup['address'] ?? '')) !== '' ? (string)$signup['address'] : null,
    ]);
    $newUserId = (int)$pdo->lastInsertId();

    $insertVolunteer = $pdo->prepare(
        'INSERT INTO volunteers (full_name, phone_number, admin_id, is_verified)
         VALUES (:full_name, :phone_number, :admin_id, :is_verified)'
    );
    $insertVolunteer->execute([
        'full_name' => (string)$signup['full_name'],
        'phone_number' => ((string)($signup['phone_number'] ?? '')) !== '' ? (string)$signup['phone_number'] : null,
        'admin_id' => $admin['admin_id'],
        'is_verified' => 1,
    ]);
    $newVolunteerId = (int)$pdo->lastInsertId();

    $approveStmt = $pdo->prepare(
        'UPDATE volunteer_signup_requests
         SET status = :status,
             admin_note = :admin_note,
             reviewed_at = NOW(),
             reviewed_by_admin_id = :admin_id,
             approved_user_id = :approved_user_id,
             approved_volunteer_id = :approved_volunteer_id
         WHERE signup_id = :signup_id'
    );
    $approveStmt->execute([
        'status' => 'approved',
        'admin_note' => $adminNote !== '' ? $adminNote : null,
        'admin_id' => $admin['admin_id'],
        'approved_user_id' => $newUserId,
        'approved_volunteer_id' => $newVolunteerId,
        'signup_id' => $signupId,
    ]);

    $pdo->commit();

    respond(200, [
        'success' => true,
        'message' => 'Volunteer signup approved and account created',
        'user_id' => $newUserId,
        'volunteer_id' => $newVolunteerId,
    ]);
} catch (Throwable $e) {
    if (isset($pdo) && $pdo instanceof PDO && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}