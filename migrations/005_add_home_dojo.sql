-- Migration 005: Add home_dojo column to users table

SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'home_dojo' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN home_dojo VARCHAR(100) DEFAULT NULL AFTER kendo_experience_months',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
