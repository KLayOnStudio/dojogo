-- ============================================================================
-- DojoGo IMU Rate Stats Migration
-- ============================================================================
-- Purpose: Track actual achieved sample rates and jitter for non-uniform sampling
-- Strategy: Option B - Dedicated stats table + actual_mean_hz column
-- Backward Compatible: Optional rate_stats in manifest, older builds still work
-- Date: 2025-01-20
-- ============================================================================

USE dojogo;

-- Add actual_mean_hz column to imu_sessions for quick filtering
ALTER TABLE imu_sessions
  ADD COLUMN actual_mean_hz DECIMAL(8,3) NULL COMMENT 'Actual achieved sample rate (Hz)' AFTER nominal_hz;

-- Create stats table for detailed jitter metrics
CREATE TABLE IF NOT EXISTS imu_session_stats (
  imu_session_id  BIGINT PRIMARY KEY COMMENT 'Links to imu_sessions.imu_session_id',
  samples_total   BIGINT NOT NULL COMMENT 'Total samples across all raw files',
  duration_ms     DECIMAL(12,3) NOT NULL COMMENT 'Session duration in milliseconds (last_ts - first_ts)',
  mean_hz         DECIMAL(8,3) NOT NULL COMMENT 'Actual mean sample rate (samples_total / duration_sec)',
  dt_ms_p50       DECIMAL(8,3) NULL COMMENT 'Median inter-sample interval (milliseconds)',
  dt_ms_p95       DECIMAL(8,3) NULL COMMENT '95th percentile inter-sample interval (milliseconds)',
  dt_ms_max       DECIMAL(8,3) NULL COMMENT 'Maximum inter-sample interval (milliseconds)',
  dropped_seq_pct DECIMAL(5,2) NULL COMMENT 'Percentage of dropped samples (if seq tracked)',
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'When stats were computed',
  CONSTRAINT fk_imus_stats FOREIGN KEY (imu_session_id)
    REFERENCES imu_sessions(imu_session_id) ON DELETE CASCADE
) ENGINE=InnoDB
  COMMENT='Actual sampling rate statistics for quality control and resampling';

-- Add index for filtering sessions by quality
CREATE INDEX idx_imus_actual_hz ON imu_sessions(actual_mean_hz);
CREATE INDEX idx_imus_stats_quality ON imu_session_stats(mean_hz, dt_ms_p95);

-- ============================================================================
-- Query Examples
-- ============================================================================

-- Find sessions with good quality (low jitter)
-- SELECT
--   ims.imu_session_id,
--   ims.nominal_hz,
--   ims.actual_mean_hz,
--   iss.dt_ms_p50,
--   iss.dt_ms_p95,
--   iss.dt_ms_max
-- FROM imu_sessions ims
-- JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
-- WHERE ims.user_id = 'auth0|abc123'
--   AND iss.dt_ms_p95 < 15.0  -- P95 < 1.5x target (10ms @ 100Hz)
-- ORDER BY ims.start_time_utc DESC;

-- Find sessions with high jitter or dropped samples
-- SELECT
--   ims.imu_session_id,
--   ims.start_time_utc,
--   ims.nominal_hz,
--   iss.mean_hz,
--   iss.dt_ms_max,
--   iss.dropped_seq_pct
-- FROM imu_sessions ims
-- JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
-- WHERE iss.dt_ms_max > 50.0  -- Gaps > 50ms
--    OR iss.dropped_seq_pct > 1.0  -- >1% dropped
-- ORDER BY iss.dt_ms_max DESC;

-- Compute mean rate deviation across all sessions
-- SELECT
--   AVG(ABS(actual_mean_hz - nominal_hz)) as mean_deviation_hz,
--   STDDEV(actual_mean_hz - nominal_hz) as stddev_deviation_hz,
--   MIN(actual_mean_hz) as min_actual_hz,
--   MAX(actual_mean_hz) as max_actual_hz
-- FROM imu_sessions
-- WHERE actual_mean_hz IS NOT NULL
--   AND nominal_hz IS NOT NULL;

-- Find sessions missing rate_stats (from older app builds)
-- SELECT
--   ims.imu_session_id,
--   ims.start_time_utc,
--   ims.end_time_utc,
--   ims.nominal_hz,
--   ims.actual_mean_hz
-- FROM imu_sessions ims
-- LEFT JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
-- WHERE ims.end_time_utc IS NOT NULL  -- Finalized
--   AND iss.imu_session_id IS NULL    -- No stats
-- ORDER BY ims.start_time_utc DESC;

-- ============================================================================
-- Rollback (if needed)
-- ============================================================================

-- DROP TABLE IF EXISTS imu_session_stats;
-- ALTER TABLE imu_sessions DROP INDEX idx_imus_actual_hz;
-- ALTER TABLE imu_sessions DROP COLUMN actual_mean_hz;

-- ============================================================================
-- Verification
-- ============================================================================

-- Verify table created
SELECT
    TABLE_NAME,
    TABLE_COMMENT,
    TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'dojogo'
  AND TABLE_NAME = 'imu_session_stats';

-- Verify foreign key
SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'dojogo'
  AND CONSTRAINT_NAME = 'fk_imus_stats';

-- Verify column added
SELECT
    COLUMN_NAME,
    COLUMN_TYPE,
    COLUMN_COMMENT
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'dojogo'
  AND TABLE_NAME = 'imu_sessions'
  AND COLUMN_NAME = 'actual_mean_hz';
