-- Migration 007: Unify sessions table for ML training data collection
-- All sessions (authenticated + guest) in same table
-- Add rank/experience columns, raw IMU + cue event storage

-- ============================================================
-- Part 1: Sessions table — add training label columns + guest support
-- ============================================================

-- Make user_id nullable for guest sessions
SET @col_type = (SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'user_id');
SET @stmt = IF(@col_type IS NOT NULL,
    'ALTER TABLE sessions MODIFY user_id VARCHAR(255) NULL', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- Add kendo_rank column
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'kendo_rank');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN kendo_rank VARCHAR(20)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- Add experience_years column
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'experience_years');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN experience_years INT DEFAULT 0', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- Add experience_months column
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'experience_months');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN experience_months INT DEFAULT 0', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- Add guest_name column (NULL for authenticated users)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'guest_name');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN guest_name VARCHAR(100)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- Add device_id column
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'device_id');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN device_id VARCHAR(100)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- ============================================================
-- Part 2: session_data table — raw IMU samples + cue events
-- ============================================================

CREATE TABLE IF NOT EXISTS session_data (
    session_id VARCHAR(36) PRIMARY KEY,
    imu_json LONGTEXT,
    cue_events_json TEXT,
    sample_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
