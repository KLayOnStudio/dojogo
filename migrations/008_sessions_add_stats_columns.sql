-- Migration 008: Add stats columns to sessions table
-- Persists computed stats (tempo, speed, power, reaction, strike time, stage)
-- so they survive sign-out / reinstall.

-- tempo (swings/min)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'tempo');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN tempo DECIMAL(10,2)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- avg_speed (rad/s)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'avg_speed');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN avg_speed DECIMAL(10,2)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- max_speed (rad/s)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'max_speed');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN max_speed DECIMAL(10,2)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- max_power (m/s^2)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'max_power');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN max_power DECIMAL(10,2)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- avg_reaction_ms (ms)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'avg_reaction_ms');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN avg_reaction_ms DECIMAL(10,2)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- avg_strike_time_ms (ms)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'avg_strike_time_ms');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN avg_strike_time_ms DECIMAL(10,2)', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;

-- stage_id (which stage; NULL for free practice / legacy)
SET @exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sessions' AND COLUMN_NAME = 'stage_id');
SET @stmt = IF(@exists = 0,
    'ALTER TABLE sessions ADD COLUMN stage_id INT', 'SELECT 1');
PREPARE s FROM @stmt; EXECUTE s; DEALLOCATE PREPARE s;
