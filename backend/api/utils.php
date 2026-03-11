<?php

declare(strict_types=1);

function normalize_status(string $status): string
{
    $clean = strtolower(trim($status));

    return match ($clean) {
        'matched' => 'matched',
        'enroute', 'en_route', 'en route' => 'en_route',
        'arrived' => 'arrived',
        'completed' => 'completed',
        'cancelled', 'canceled' => 'cancelled',
        default => 'requested',
    };
}
