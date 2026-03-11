-- ElderEase MySQL schema
-- Compatible with MySQL 8+

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS admins (
  admin_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  username VARCHAR(80) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  username VARCHAR(80) NOT NULL UNIQUE,
  email VARCHAR(120) NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  phone_number VARCHAR(30) NULL,
  birthday DATE NULL,
  address TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS volunteers (
  volunteer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  phone_number VARCHAR(30) NULL,
  rating_avg DECIMAL(3,2) NOT NULL DEFAULT 0.00,
  skills TEXT NULL,
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  admin_id INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_volunteer_admin
    FOREIGN KEY (admin_id) REFERENCES admins(admin_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS services (
  service_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  service_name VARCHAR(150) NOT NULL,
  description TEXT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS service_requests (
  request_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  external_request_id VARCHAR(40) NULL UNIQUE,
  user_id INT UNSIGNED NOT NULL,
  volunteer_id INT UNSIGNED NULL,
  schedule_datetime DATETIME NOT NULL,
  address TEXT NOT NULL,
  status ENUM('requested','matched','en_route','arrived','completed','cancelled')
    NOT NULL DEFAULT 'requested',
  notes TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_request_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_request_volunteer
    FOREIGN KEY (volunteer_id) REFERENCES volunteers(volunteer_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_request_user_created (user_id, created_at),
  INDEX idx_request_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Correct normalization for multiple selected services in one request
CREATE TABLE IF NOT EXISTS request_items (
  request_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  service_id INT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  CONSTRAINT fk_request_item_request
    FOREIGN KEY (request_id) REFERENCES service_requests(request_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_request_item_service
    FOREIGN KEY (service_id) REFERENCES services(service_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE KEY uniq_request_service (request_id, service_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS feedback (
  feedback_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  request_id BIGINT UNSIGNED NOT NULL,
  volunteer_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  rating_score TINYINT UNSIGNED NOT NULL,
  comments TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_feedback_request
    FOREIGN KEY (request_id) REFERENCES service_requests(request_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_feedback_volunteer
    FOREIGN KEY (volunteer_id) REFERENCES volunteers(volunteer_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_feedback_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CHECK (rating_score BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Starter service catalog (optional)
INSERT INTO services (service_id, service_name, description) VALUES
  (1, 'LPG Gas Tank Replacement', 'Safe replacement of LPG gas tanks at home.'),
  (2, 'Grocery Collection', 'Pick up and deliver groceries from the market.'),
  (3, 'Garden Maintenance', 'Trimming, weeding, and general garden care.'),
  (4, 'Utility Assistance', 'Help with utility-related errands and account coordination.'),
  (5, 'Water Container Refill', 'Lift and place heavy water containers.'),
  (6, 'Medical Prescription Pickup', 'Collect medicine from pharmacy.')
ON DUPLICATE KEY UPDATE
  service_name = VALUES(service_name),
  description = VALUES(description);
