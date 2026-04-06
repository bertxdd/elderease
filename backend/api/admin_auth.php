<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';

function get_authorization_header(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (is_string($header) && trim($header) !== '') {
        return trim($header);
    }

    if (function_exists('getallheaders')) {
        $headers = getallheaders();
        if (is_array($headers)) {
            foreach ($headers as $name => $value) {
                if (strtolower((string)$name) === 'authorization') {
                    return trim((string)$value);
                }
            }
        }
    }

    return '';
}

function require_admin_auth(PDO $pdo): array
{
    $authHeader = get_authorization_header();
    if ($authHeader === '' || stripos($authHeader, 'Bearer ') !== 0) {
        respond(401, ['success' => false, 'message' => 'Missing Bearer token']);
    }

    $token = trim(substr($authHeader, 7));
    if ($token === '') {
        respond(401, ['success' => false, 'message' => 'Invalid Bearer token']);
    }

    $tokenHash = hash('sha256', $token);

    $stmt = $pdo->prepare(
        'SELECT
            s.session_id,
            s.admin_id,
            s.expires_at,
            a.username,
            a.full_name
         FROM admin_sessions s
         INNER JOIN admins a ON a.admin_id = s.admin_id
         WHERE s.token_hash = :token_hash
         LIMIT 1'
    );
    $stmt->execute(['token_hash' => $tokenHash]);
    $row = $stmt->fetch();

    if (!$row) {
        respond(401, ['success' => false, 'message' => 'Invalid session']);
    }

    $expiresAt = (string)($row['expires_at'] ?? '');
    if ($expiresAt === '' || strtotime($expiresAt) <= time()) {
        $deleteStmt = $pdo->prepare('DELETE FROM admin_sessions WHERE session_id = :session_id');
        $deleteStmt->execute(['session_id' => (int)$row['session_id']]);
        respond(401, ['success' => false, 'message' => 'Session expired']);
    }

    return [
        'session_id' => (int)$row['session_id'],
        'admin_id' => (int)$row['admin_id'],
        'username' => (string)$row['username'],
        'full_name' => (string)$row['full_name'],
        'expires_at' => $expiresAt,
    ];
}