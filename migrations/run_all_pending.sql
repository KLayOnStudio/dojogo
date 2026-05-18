-- Combined migration script - safe to run even if some have already been applied
-- Run this against the production MySQL database

-- 002: Add mode column to sessions (if not exists)
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'sessions' AND COLUMN_NAME = 'mode' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE sessions ADD COLUMN mode VARCHAR(10) NOT NULL DEFAULT ''guided''',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 003: Rename tap_count → swing_count (if not already renamed)
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'sessions' AND COLUMN_NAME = 'tap_count' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 1,
    'ALTER TABLE sessions CHANGE COLUMN tap_count swing_count INT NOT NULL DEFAULT 0',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 003: Reset total_count from swing-era sessions only
UPDATE users u
SET total_count = COALESCE((
    SELECT SUM(s.swing_count)
    FROM sessions s
    WHERE s.user_id = u.id
      AND s.mode IN ('guided', 'free')
), 0);

-- 004: Add missing kendo experience columns
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'kendo_experience_years' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN kendo_experience_years INT DEFAULT 0 AFTER kendo_rank',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'kendo_experience_months' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN kendo_experience_months INT DEFAULT 0 AFTER kendo_experience_years',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Also ensure kendo_rank column exists
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'kendo_rank' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN kendo_rank VARCHAR(20) AFTER nickname_last_changed',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 005: Add home_dojo column
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'home_dojo' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN home_dojo VARCHAR(100) DEFAULT NULL AFTER kendo_experience_months',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 009b: Add prize_image_url to campaigns table
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'campaigns' AND COLUMN_NAME = 'prize_image_url');
SET @stmt = IF(@col_exists = 0,
    'ALTER TABLE campaigns ADD COLUMN prize_image_url VARCHAR(500) DEFAULT NULL AFTER prize_url',
    'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- 010: User privacy (is_public), sensor mode, announcements table
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_public');
SET @stmt = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT TRUE',
    'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'sensor_mode');
SET @stmt = IF(@col_exists = 0,
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

-- 011: Avatar choice per user
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'avatar');
SET @stmt = IF(@col_exists = 0,
    "ALTER TABLE users ADD COLUMN avatar VARCHAR(50) DEFAULT 'kendoka' AFTER home_dojo",
    'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- 012: Per-user notifications (campaign invites, friend accepted)
CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    type ENUM('campaign_invite', 'friend_accepted') NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    data JSON DEFAULT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_read (user_id, is_read)
);

-- 013: Announcement views tracking
CREATE TABLE IF NOT EXISTS announcement_views (
    user_id VARCHAR(255) NOT NULL,
    announcement_id INT NOT NULL,
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, announcement_id),
    INDEX idx_announcement (announcement_id)
);

-- 014: Audio assets manifest (remote BGM and SFX, updatable without app release)
CREATE TABLE IF NOT EXISTS audio_assets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    type ENUM('bgm', 'sfx') NOT NULL,
    url VARCHAR(500) NOT NULL,
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_active (is_active)
);
