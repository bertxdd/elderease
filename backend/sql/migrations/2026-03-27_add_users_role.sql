-- Migration: Add users.role for role-based login routing
-- Date: 2026-03-27
-- Target: MySQL 8+

START TRANSACTION;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role ENUM('user','volunteer') NOT NULL DEFAULT 'user' AFTER username;

COMMIT;
