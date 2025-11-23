-- ============================================================================
-- Migration: Add action_type to imu_sessions
-- Purpose: Label IMU sessions by suburi/swing type for ML training
-- ============================================================================

USE dojogo;

-- Add action_type column to imu_sessions
ALTER TABLE imu_sessions
  ADD COLUMN action_type VARCHAR(50) NULL COMMENT 'Type of swing/suburi (men, kote, do, tsuki, suburi_1, etc.)' AFTER game_session_id,
  ADD KEY idx_imus_action_type (action_type);

-- Verification query
SELECT
    COLUMN_NAME,
    COLUMN_TYPE,
    IS_NULLABLE,
    COLUMN_KEY,
    COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'dojogo'
  AND TABLE_NAME = 'imu_sessions'
  AND COLUMN_NAME = 'action_type';
