<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';

function notify_volunteer_approved(array $signup): array
{
    $emailSent = false;
    $smsSent = false;
    $errors = [];

    $fullName = trim((string)($signup['full_name'] ?? 'Volunteer'));
    $email = trim((string)($signup['email'] ?? ''));
    $phoneNumber = trim((string)($signup['phone_number'] ?? ''));

    $message = sprintf(
        'Congratulations %s! Your ElderEase volunteer registration has been approved. You can now log in and start accepting requests.',
        $fullName
    );

    if ($email !== '') {
        $emailResult = send_emailjs_approval_email($email, $fullName, $phoneNumber, $message);
        $emailSent = $emailResult['sent'];
        if (!$emailResult['sent'] && $emailResult['error'] !== '') {
            $errors[] = 'EmailJS: ' . $emailResult['error'];
        }
    }

    if ($phoneNumber !== '') {
        $smsResult = send_philsms_approval_sms($phoneNumber, $message);
        $smsSent = $smsResult['sent'];
        if (!$smsResult['sent'] && $smsResult['error'] !== '') {
            $errors[] = 'PhilSMS: ' . $smsResult['error'];
        }
    }

    return [
        'email_sent' => $emailSent,
        'sms_sent' => $smsSent,
        'errors' => $errors,
    ];
}

function send_emailjs_approval_email(string $email, string $fullName, string $phoneNumber, string $message): array
{
    if (EMAILJS_SERVICE_ID === '' || EMAILJS_TEMPLATE_ID === '' || EMAILJS_PUBLIC_KEY === '' || EMAILJS_PRIVATE_KEY === '') {
        return ['sent' => false, 'error' => 'EmailJS keys are not configured'];
    }

    $payload = [
        'service_id' => EMAILJS_SERVICE_ID,
        'template_id' => EMAILJS_TEMPLATE_ID,
        'user_id' => EMAILJS_PUBLIC_KEY,
        'accessToken' => EMAILJS_PRIVATE_KEY,
        'template_params' => [
            'email' => $email,
            'name' => $fullName,
            'title' => 'Volunteer Registration Approved',
            'time' => date('Y-m-d H:i:s'),
            'to_email' => $email,
            'to_name' => $fullName,
            'phone_number' => $phoneNumber,
            'message' => $message,
            'subject' => 'ElderEase Volunteer Registration Approved',
        ],
    ];

    return execute_json_post_request(EMAILJS_ENDPOINT, $payload, []);
}

function send_philsms_approval_sms(string $phoneNumber, string $message): array
{
    if (PHILSMS_TOKEN === '' || PHILSMS_SENDER_ID === '') {
        return ['sent' => false, 'error' => 'PhilSMS token or sender ID is not configured'];
    }

    $normalizedPhone = normalize_ph_phone_number($phoneNumber);
    if ($normalizedPhone === '') {
        return ['sent' => false, 'error' => 'Recipient phone number is invalid'];
    }

    $payload = [
        'recipient' => $normalizedPhone,
        'sender_id' => PHILSMS_SENDER_ID,
        'type' => 'plain',
        'message' => $message,
    ];

    $headers = [
        'Authorization: Bearer ' . PHILSMS_TOKEN,
    ];

    return execute_json_post_request(PHILSMS_API_URL, $payload, $headers);
}

function normalize_ph_phone_number(string $raw): string
{
    $digits = preg_replace('/[^0-9+]/', '', trim($raw));
    if (!is_string($digits) || $digits === '') {
        return '';
    }

    if (str_starts_with($digits, '+63')) {
        $digits = substr($digits, 1);
    }

    if (str_starts_with($digits, '09') && strlen($digits) === 11) {
        return '63' . substr($digits, 1);
    }

    if (str_starts_with($digits, '639') && strlen($digits) === 12) {
        return $digits;
    }

    return '';
}

function execute_json_post_request(string $url, array $payload, array $extraHeaders): array
{
    $ch = curl_init($url);
    if ($ch === false) {
        return ['sent' => false, 'error' => 'Unable to initialize cURL'];
    }

    $headers = array_merge([
        'Content-Type: application/json',
        'Accept: application/json',
    ], $extraHeaders);

    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload, JSON_UNESCAPED_UNICODE));
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);

    $raw = curl_exec($ch);
    $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr = curl_error($ch);
    curl_close($ch);

    if ($raw === false) {
        return ['sent' => false, 'error' => $curlErr !== '' ? $curlErr : 'Request failed'];
    }

    if ($httpCode < 200 || $httpCode >= 300) {
        return ['sent' => false, 'error' => sprintf('HTTP %d: %s', $httpCode, trim($raw))];
    }

    return ['sent' => true, 'error' => ''];
}
