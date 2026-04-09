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
