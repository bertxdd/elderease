CREATE TABLE IF NOT EXISTS admin_sessions (
  session_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  admin_id INT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_admin_session_admin
    FOREIGN KEY (admin_id) REFERENCES admins(admin_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_admin_session_admin (admin_id),
  INDEX idx_admin_session_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
