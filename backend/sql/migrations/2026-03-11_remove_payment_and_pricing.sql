-- Migration: Remove payment and pricing schema for volunteer-only flow
-- Date: 2026-03-11
-- Target: MySQL 8+

START TRANSACTION;

-- 1) Remove payment table entirely.
DROP TABLE IF EXISTS payments;

-- 2) Remove pricing columns from service catalog.
ALTER TABLE services
  DROP COLUMN IF EXISTS base_price;

-- 3) Remove total cost from service requests.
ALTER TABLE service_requests
  DROP COLUMN IF EXISTS total_cost;

-- 4) Remove per-item pricing fields from request items.
ALTER TABLE request_items
  DROP COLUMN IF EXISTS unit_price,
  DROP COLUMN IF EXISTS subtotal;

-- 5) Rename payment-oriented seeded service to neutral volunteer wording.
UPDATE services
SET service_name = 'Utility Assistance',
    description = 'Help with utility-related errands and account coordination.'
WHERE service_name = 'Utility Bill Payments';

COMMIT;
