CREATE TABLE IF NOT EXISTS volunteer_signup_requests (
  signup_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  username VARCHAR(80) NOT NULL,
  email VARCHAR(120) NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone_number VARCHAR(30) NULL,
  birthday DATE NULL,
  address TEXT NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  admin_note TEXT NULL,
  reviewed_at DATETIME NULL,
  reviewed_by_admin_id INT UNSIGNED NULL,
  approved_user_id INT UNSIGNED NULL,
  approved_volunteer_id INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_signup_review_admin
    FOREIGN KEY (reviewed_by_admin_id) REFERENCES admins(admin_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_signup_approved_user
    FOREIGN KEY (approved_user_id) REFERENCES users(user_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_signup_approved_volunteer
    FOREIGN KEY (approved_volunteer_id) REFERENCES volunteers(volunteer_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_signup_status_created (status, created_at),
  INDEX idx_signup_username (username),
  INDEX idx_signup_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
