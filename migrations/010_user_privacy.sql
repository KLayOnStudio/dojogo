-- Migration 010: User privacy + sensor mode + announcements
-- Adds is_public column to users table (default true = visible in search)
-- Adds sensor_mode column to sessions table (mount | phone | other)
-- Creates announcements table for dev team posts

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_public');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE users ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT TRUE',
    'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'sensor_mode');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN sensor_mode ENUM(''mount'',''phone'',''other'') NOT NULL DEFAULT ''phone''',
    'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

CREATE TABLE IF NOT EXISTS announcements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    image_url VARCHAR(500) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP DEFAULT NULL
);
