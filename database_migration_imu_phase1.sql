-- ============================================================================
-- DojoGo IMU Data Capture - Phase 1 Migration
-- ============================================================================
-- Target: MySQL 8.0 on Azure
-- Date: 2025-10-16
-- Phase: Alpha → GA Foundation
--
-- This migration creates tables for lossless IMU sensor capture with:
-- - Device registration and tracking
-- - IMU session management (continuous captures)
-- - Blob storage pointers (Azure Blob)
-- - Idempotency for client uploads
--
-- SAFETY: Does NOT modify existing tables (users, sessions, session_starts)
-- ============================================================================

USE dojogo;

-- ----------------------------------------------------------------------------
-- Table: devices
-- Purpose: Track hardware devices per user (one row per user×hardware combo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
  device_id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id          VARCHAR(255) NOT NULL,
  platform         ENUM('ios','android','switch','other') NOT NULL,
  model            VARCHAR(128) COMMENT 'Device model (e.g., iPhone 15 Pro, Pixel 8)',
  os_version       VARCHAR(64) COMMENT 'OS version (e.g., iOS 17.1, Android 14)',
  app_version      VARCHAR(64) COMMENT 'DojoGo app version',
  hw_id            VARCHAR(128) COMMENT 'Hardware identifier (vendor ID or secure UUID)',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uk_user_hw (user_id, hw_id),
  CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,

  INDEX idx_devices_user (user_id),
  INDEX idx_devices_platform (platform)
) ENGINE=InnoDB
  COMMENT='Device registry: one row per user×hardware combination';

-- ----------------------------------------------------------------------------
-- Table: imu_sessions
-- Purpose: One continuous IMU capture session (start→stop)
-- Notes:
--   - start_time_utc: Session start (microsecond precision)
--   - end_time_utc: NULL until finalized
--   - nominal_hz: Expected sample rate (e.g., 100.0 Hz)
--   - coord_frame: 'device' (sensor axes) or 'world' (gravity-aligned)
--   - gravity_removed: 0 in alpha (keep raw), 1 if processed
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS imu_sessions (
  imu_session_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id          VARCHAR(255) NOT NULL,
  device_id        BIGINT NOT NULL,
  start_time_utc   DATETIME(6) NOT NULL COMMENT 'Session start (UTC, microsecond precision)',
  end_time_utc     DATETIME(6) NULL COMMENT 'Session end (NULL until finalized)',
  nominal_hz       DECIMAL(6,2) NULL COMMENT 'Expected sample rate (e.g., 100.00 Hz)',
  coord_frame      ENUM('device','world') DEFAULT 'device' COMMENT 'Coordinate frame',
  gravity_removed  TINYINT(1) DEFAULT 0 COMMENT '0=raw, 1=gravity removed (alpha: always 0)',
  notes            TEXT COMMENT 'Optional session notes or metadata',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_imus_user   FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_imus_device FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE SET NULL,

  KEY idx_imus_user_time (user_id, start_time_utc),
  KEY idx_imus_dev_time  (device_id, start_time_utc),
  KEY idx_imus_created   (created_at)
) ENGINE=InnoDB
  COMMENT='IMU capture sessions: one continuous recording per row';

-- ----------------------------------------------------------------------------
-- Table: imu_session_files
-- Purpose: Pointers to Azure Blob storage files for each IMU session
-- File Types (purpose):
--   - 'raw': Parquet data files (main sensor data)
--   - 'manifest': JSON manifest listing all parts
--   - 'device': Device metadata snapshot
--   - 'calib': Calibration data (if available)
--   - 'events': Event log (JSONL format)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS imu_session_files (
  file_id         BIGINT PRIMARY KEY AUTO_INCREMENT,
  imu_session_id  BIGINT NOT NULL,
  purpose         ENUM('raw','manifest','device','calib','events') NOT NULL,
  storage_url     VARCHAR(512) NOT NULL COMMENT 'Full Azure Blob URL or relative path',
  content_type    VARCHAR(64) COMMENT 'MIME type (e.g., application/parquet)',
  bytes_size      BIGINT COMMENT 'File size in bytes',
  sha256_hex      CHAR(64) COMMENT 'SHA-256 checksum (hex string)',
  num_samples     BIGINT COMMENT 'Number of samples (for raw Parquet files)',
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_imuf_sess FOREIGN KEY (imu_session_id) REFERENCES imu_sessions(imu_session_id) ON DELETE CASCADE,

  KEY idx_imuf_sess_purpose (imu_session_id, purpose),
  KEY idx_imuf_created (created_at)
) ENGINE=InnoDB
  COMMENT='Blob storage pointers for IMU session files';

-- ----------------------------------------------------------------------------
-- Table: imu_client_uploads
-- Purpose: Idempotency ledger for client upload retries
-- Pattern: Client generates UUID per upload attempt; server deduplicates
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS imu_client_uploads (
  upload_id        BIGINT PRIMARY KEY AUTO_INCREMENT,
  imu_session_id   BIGINT NOT NULL,
  client_upload_id CHAR(36) NOT NULL COMMENT 'Client-generated UUID for idempotency',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uk_imu_client (imu_session_id, client_upload_id),
  CONSTRAINT fk_imucu_sess FOREIGN KEY (imu_session_id) REFERENCES imu_sessions(imu_session_id) ON DELETE CASCADE,

  KEY idx_imucu_sess (imu_session_id)
) ENGINE=InnoDB
  COMMENT='Idempotency tracking for client uploads (retry-safe)';

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- Tables created: devices, imu_sessions, imu_session_files, imu_client_uploads
-- Existing tables preserved: users, sessions, session_starts
-- ============================================================================
