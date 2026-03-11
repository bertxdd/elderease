-- Migration: Add users.birthday for profile updates
-- Date: 2026-03-11
-- Target: MySQL 8+

START TRANSACTION;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS birthday DATE NULL AFTER phone_number;

COMMIT;
