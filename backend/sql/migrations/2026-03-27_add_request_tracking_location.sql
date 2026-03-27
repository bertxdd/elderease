-- Migration: Add volunteer live location columns to service_requests
-- Date: 2026-03-27
-- Target: MySQL 8+

START TRANSACTION;

ALTER TABLE service_requests
  ADD COLUMN IF NOT EXISTS volunteer_lat DECIMAL(10,7) NULL AFTER volunteer_id,
  ADD COLUMN IF NOT EXISTS volunteer_lng DECIMAL(10,7) NULL AFTER volunteer_lat,
  ADD COLUMN IF NOT EXISTS volunteer_location_updated_at DATETIME NULL AFTER volunteer_lng;

COMMIT;
