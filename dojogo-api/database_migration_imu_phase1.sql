-- ============================================================================
-- DojoGo IMU Phase 1 Migration
-- ============================================================================
-- Purpose: Create foundation tables for IMU data capture
-- Date: 2025-01-20
-- ============================================================================

USE dojogo;

-- ============================================================================
-- Table 1: devices
-- ============================================================================
CREATE TABLE IF NOT EXISTS devices (
  device_id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id          VARCHAR(255) NOT NULL COMMENT 'Auth0 user ID',
  platform         ENUM('ios','android','switch','other') NOT NULL COMMENT 'Device platform',
  model            VARCHAR(128) NULL COMMENT 'Device model name',
  os_version       VARCHAR(64) NULL COMMENT 'Operating system version',
  app_version      VARCHAR(32) NULL COMMENT 'DojoGo app version',
  hw_id            VARCHAR(128) NULL COMMENT 'Hardware identifier (vendor ID)',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Device first seen',
  updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last updated',

  UNIQUE KEY uk_user_hw (user_id, hw_id),
  KEY idx_devices_user (user_id),
  CONSTRAINT fk_devices_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB
  COMMENT='Device registry per user for IMU capture';

-- ============================================================================
-- Table 2: imu_sessions
-- ============================================================================
CREATE TABLE IF NOT EXISTS imu_sessions (
  imu_session_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id          VARCHAR(255) NOT NULL COMMENT 'Auth0 user ID',
  device_id        BIGINT NOT NULL COMMENT 'Device that captured this session',
  start_time_utc   DATETIME(6) NOT NULL COMMENT 'Session start time (UTC, microsecond precision)',
  end_time_utc     DATETIME(6) NULL COMMENT 'Session end time (NULL until finalized)',
  nominal_hz       DECIMAL(6,2) NULL COMMENT 'Requested sample rate (Hz)',
  coord_frame      ENUM('device','world') DEFAULT 'device' COMMENT 'Coordinate reference frame',
  gravity_removed  TINYINT(1) DEFAULT 0 COMMENT 'Whether gravity was removed (0=raw with gravity)',
  notes            TEXT NULL COMMENT 'Optional session notes',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Session record created',

  KEY idx_imus_user (user_id),
  KEY idx_imus_device (device_id),
  KEY idx_imus_start (start_time_utc),
  CONSTRAINT fk_imus_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_imus_device FOREIGN KEY (device_id)
    REFERENCES devices(device_id) ON DELETE RESTRICT
) ENGINE=InnoDB
  COMMENT='IMU capture sessions (one session = one continuous recording)';

-- ============================================================================
-- Table 3: imu_session_files
-- ============================================================================
CREATE TABLE IF NOT EXISTS imu_session_files (
  file_id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  imu_session_id  BIGINT NOT NULL COMMENT 'Parent session',
  purpose         ENUM('raw','manifest','device','calib','events') NOT NULL COMMENT 'File type/purpose',
  storage_url     VARCHAR(512) NOT NULL COMMENT 'Blob storage path (relative to container)',
  content_type    VARCHAR(128) NULL COMMENT 'MIME type',
  bytes_size      BIGINT NULL COMMENT 'File size in bytes',
  sha256_hex      CHAR(64) NULL COMMENT 'SHA-256 checksum (hex)',
  num_samples     BIGINT NULL COMMENT 'Number of IMU samples (for raw files)',
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'File registered',

  KEY idx_imuf_session (imu_session_id),
  KEY idx_imuf_purpose (purpose),
  CONSTRAINT fk_imuf_sess FOREIGN KEY (imu_session_id)
    REFERENCES imu_sessions(imu_session_id) ON DELETE CASCADE
) ENGINE=InnoDB
  COMMENT='Files associated with IMU sessions (stored in Azure Blob)';

-- ============================================================================
-- Table 4: imu_client_uploads
-- ============================================================================
CREATE TABLE IF NOT EXISTS imu_client_uploads (
  imu_session_id   BIGINT NOT NULL COMMENT 'Session ID',
  client_upload_id CHAR(36) NOT NULL COMMENT 'Client-generated UUID for idempotency',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Upload registered',

  UNIQUE KEY uk_imu_client (imu_session_id, client_upload_id),
  KEY idx_imuc_upload_id (client_upload_id),
  CONSTRAINT fk_imuc_sess FOREIGN KEY (imu_session_id)
    REFERENCES imu_sessions(imu_session_id) ON DELETE CASCADE
) ENGINE=InnoDB
  COMMENT='Idempotency ledger for IMU session creation';

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Show all IMU tables
SELECT
    TABLE_NAME,
    TABLE_ROWS,
    ROUND(DATA_LENGTH/1024/1024, 2) as size_mb,
    TABLE_COMMENT
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'dojogo'
  AND (TABLE_NAME LIKE 'imu_%' OR TABLE_NAME = 'devices')
ORDER BY TABLE_NAME;

-- Show foreign keys
SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'dojogo'
  AND REFERENCED_TABLE_NAME IS NOT NULL
  AND (TABLE_NAME LIKE 'imu_%' OR TABLE_NAME = 'devices')
ORDER BY TABLE_NAME, CONSTRAINT_NAME;
