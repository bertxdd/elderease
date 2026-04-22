ALTER TABLE volunteer_signup_requests
  ADD COLUMN certification_image_url VARCHAR(255) NULL AFTER address,
  ADD COLUMN certification_image_name VARCHAR(190) NULL AFTER certification_image_url;
