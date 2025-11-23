-- ============================================================================
-- DojoGo IMU Session-Coupled Migration
-- ============================================================================
-- Purpose: Link IMU captures to tap-game sessions for synchronized recording
-- Safe: Does NOT modify existing sessions table, only adds soft link
-- Date: 2025-01-20
-- ============================================================================

USE dojogo;

-- Add soft link from IMU sessions to game sessions
ALTER TABLE imu_sessions
  ADD COLUMN game_session_id VARCHAR(36) NULL COMMENT 'Optional link to tap-game session (sessions.id)',
  ADD KEY idx_imus_game_session (game_session_id),
  ADD CONSTRAINT fk_imus_game_session
    FOREIGN KEY (game_session_id) REFERENCES sessions(id)
    ON DELETE SET NULL;

-- Verify foreign key created
SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'dojogo'
  AND CONSTRAINT_NAME = 'fk_imus_game_session';

-- ============================================================================
-- Query Examples
-- ============================================================================

-- Find all IMU captures linked to a specific game session
-- SELECT * FROM imu_sessions WHERE game_session_id = 'uuid-here';

-- Find game sessions with IMU data
-- SELECT s.*, ims.imu_session_id, ims.start_time_utc, ims.end_time_utc
-- FROM sessions s
-- JOIN imu_sessions ims ON s.id = ims.game_session_id
-- WHERE s.user_id = 'auth0|abc123';

-- Find orphaned IMU sessions (no game session link)
-- SELECT * FROM imu_sessions WHERE game_session_id IS NULL;

-- ============================================================================
-- Rollback (if needed)
-- ============================================================================

-- DROP CONSTRAINT (uncomment if rollback needed)
-- ALTER TABLE imu_sessions DROP FOREIGN KEY fk_imus_game_session;
-- ALTER TABLE imu_sessions DROP KEY idx_imus_game_session;
-- ALTER TABLE imu_sessions DROP COLUMN game_session_id;
