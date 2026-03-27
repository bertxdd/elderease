<?php

declare(strict_types=1);

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['success' => false, 'message' => 'Method not allowed']);
}

$input = read_json_body();
$requestId = trim((string)($input['request_id'] ?? ''));
$rating = (int)($input['rating_score'] ?? 0);
$comments = trim((string)($input['comments'] ?? ''));

if ($requestId === '' || $rating < 1 || $rating > 5) {
    respond(422, ['success' => false, 'message' => 'Invalid payload']);
}

try {
    $pdo = db();

    $lookup = $pdo->prepare(
        'SELECT request_id, volunteer_id, user_id
         FROM service_requests
         WHERE request_id = :request_id OR external_request_id = :external_request_id
         LIMIT 1'
    );
    $lookup->execute([
        'request_id' => ctype_digit($requestId) ? (int)$requestId : -1,
        'external_request_id' => $requestId,
    ]);

    $req = $lookup->fetch();
    if (!$req) {
        respond(404, ['success' => false, 'message' => 'Request not found']);
    }

    if ((int)$req['volunteer_id'] <= 0) {
        respond(422, ['success' => false, 'message' => 'No volunteer assigned yet']);
    }

    $insert = $pdo->prepare(
        'INSERT INTO feedback (request_id, volunteer_id, user_id, rating_score, comments)
         VALUES (:request_id, :volunteer_id, :user_id, :rating_score, :comments)'
    );
    $insert->execute([
        'request_id' => (int)$req['request_id'],
        'volunteer_id' => (int)$req['volunteer_id'],
        'user_id' => (int)$req['user_id'],
        'rating_score' => $rating,
        'comments' => $comments,
    ]);

    // Recompute aggregate volunteer rating.
    $recompute = $pdo->prepare(
        'UPDATE volunteers v
         JOIN (
            SELECT volunteer_id, AVG(rating_score) AS avg_rating
            FROM feedback
            WHERE volunteer_id = :volunteer_id
            GROUP BY volunteer_id
         ) r ON r.volunteer_id = v.volunteer_id
         SET v.rating_avg = r.avg_rating'
    );
    $recompute->execute(['volunteer_id' => (int)$req['volunteer_id']]);

    respond(200, ['success' => true]);
} catch (Throwable $e) {
    $message = APP_DEBUG ? $e->getMessage() : 'Server error';
    respond(500, ['success' => false, 'message' => $message]);
}
