# IMU Sidecar File Examples

Sidecar files provide metadata and context for raw IMU Parquet data. Each session produces 4 sidecar JSON files.

## 1. Device Snapshot (`device_{imu_session_id}.json`)

Time-aware snapshot of device state when the session was captured. This allows historical reconstruction even if device updates later.

### Schema

```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "device_id": 7,
  "captured_at": "2025-01-20T10:30:00.123456Z",
  "device_info": {
    "platform": "ios",
    "model": "iPhone 14 Pro",
    "os_version": "17.2.1",
    "app_version": "1.0.0-alpha.3",
    "hw_id": "A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6"
  },
  "imu_hardware": {
    "manufacturer": "Bosch",
    "model": "BMI160",
    "accel_range_g": 16,
    "gyro_range_dps": 2000,
    "mag_available": false,
    "fusion_available": true
  },
  "user_snapshot": {
    "nickname": "Shinpan",
    "kendo_rank": "2dan",
    "kendo_experience_years": 5,
    "kendo_experience_months": 3,
    "captured_at": "2025-01-20T10:30:00.123456Z"
  }
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `imu_session_id` | `integer` | Yes | Session ID from database |
| `user_id` | `string` | Yes | Auth0 user ID |
| `device_id` | `integer` | Yes | Device ID from database |
| `captured_at` | `string` | Yes | ISO 8601 timestamp when snapshot was taken |
| `device_info.platform` | `string` | Yes | Enum: `ios`, `android`, `switch`, `other` |
| `device_info.model` | `string` | No | Device marketing name |
| `device_info.os_version` | `string` | No | OS version string |
| `device_info.app_version` | `string` | No | DojoGo app version |
| `device_info.hw_id` | `string` | Yes | Stable device identifier (vendor ID or generated UUID) |
| `imu_hardware.*` | `object` | No | IMU chip details (if available from device APIs) |
| `user_snapshot.*` | `object` | No | User profile snapshot at time of capture |

### Example (Full)

```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "device_id": 7,
  "captured_at": "2025-01-20T10:30:00.123456Z",
  "device_info": {
    "platform": "ios",
    "model": "iPhone 14 Pro",
    "os_version": "17.2.1",
    "app_version": "1.0.0-alpha.3",
    "hw_id": "A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6"
  },
  "imu_hardware": {
    "manufacturer": "Bosch",
    "model": "BMI160",
    "accel_range_g": 16,
    "gyro_range_dps": 2000,
    "mag_available": false,
    "fusion_available": true
  },
  "user_snapshot": {
    "nickname": "Shinpan",
    "kendo_rank": "2dan",
    "kendo_experience_years": 5,
    "kendo_experience_months": 3,
    "captured_at": "2025-01-20T10:30:00.123456Z"
  }
}
```

### Example (Minimal - Alpha)

```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "device_id": 7,
  "captured_at": "2025-01-20T10:30:00.123456Z",
  "device_info": {
    "platform": "ios",
    "model": "iPhone 14 Pro",
    "os_version": "17.2.1",
    "app_version": "1.0.0-alpha.3",
    "hw_id": "A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6"
  }
}
```

---

## 2. Calibration Data (`calib_{imu_session_id}.json`)

Calibration parameters for the IMU sensors. In alpha, this is mostly placeholders. In GA, include factory calibration or user-performed calibration.

### Schema

```json
{
  "imu_session_id": 42,
  "captured_at": "2025-01-20T10:30:00.123456Z",
  "accelerometer": {
    "bias_x": 0.0,
    "bias_y": 0.0,
    "bias_z": 0.0,
    "scale_x": 1.0,
    "scale_y": 1.0,
    "scale_z": 1.0,
    "cross_axis_matrix": [[1,0,0], [0,1,0], [0,0,1]],
    "calibration_source": "factory"
  },
  "gyroscope": {
    "bias_x": 0.0,
    "bias_y": 0.0,
    "bias_z": 0.0,
    "scale_x": 1.0,
    "scale_y": 1.0,
    "scale_z": 1.0,
    "cross_axis_matrix": [[1,0,0], [0,1,0], [0,0,1]],
    "calibration_source": "factory"
  },
  "magnetometer": {
    "hard_iron_x": 0.0,
    "hard_iron_y": 0.0,
    "hard_iron_z": 0.0,
    "soft_iron_matrix": [[1,0,0], [0,1,0], [0,0,1]],
    "calibration_source": "uncalibrated"
  }
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `imu_session_id` | `integer` | Yes | Session ID |
| `captured_at` | `string` | Yes | When calibration was performed |
| `accelerometer.bias_*` | `float` | No | Zero-g offset (m/s²) |
| `accelerometer.scale_*` | `float` | No | Axis gain correction |
| `accelerometer.cross_axis_matrix` | `array` | No | 3x3 rotation matrix for misalignment |
| `accelerometer.calibration_source` | `string` | No | Enum: `factory`, `user`, `uncalibrated` |
| `gyroscope.*` | `object` | No | Same structure as accelerometer |
| `magnetometer.hard_iron_*` | `float` | No | Magnetic bias offset (µT) |
| `magnetometer.soft_iron_matrix` | `array` | No | 3x3 matrix for ferrous distortion |

### Example (Alpha - Uncalibrated)

```json
{
  "imu_session_id": 42,
  "captured_at": "2025-01-20T10:30:00.123456Z",
  "accelerometer": {
    "bias_x": 0.0,
    "bias_y": 0.0,
    "bias_z": 0.0,
    "scale_x": 1.0,
    "scale_y": 1.0,
    "scale_z": 1.0,
    "calibration_source": "uncalibrated"
  },
  "gyroscope": {
    "bias_x": 0.0,
    "bias_y": 0.0,
    "bias_z": 0.0,
    "scale_x": 1.0,
    "scale_y": 1.0,
    "scale_z": 1.0,
    "calibration_source": "uncalibrated"
  }
}
```

---

## 3. Events Log (`events_{imu_session_id}.jsonl`)

Newline-delimited JSON (JSONL) file logging discrete events during the session. Each line is a standalone JSON object.

### Schema (Per Line)

```json
{
  "ts_ns": 1737371405123456000,
  "event_type": "user_action",
  "action": "men_strike",
  "metadata": {"confidence": 0.95}
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts_ns` | `integer` | Yes | Timestamp in nanoseconds (matches Parquet `ts_ns`) |
| `event_type` | `string` | Yes | Enum: `user_action`, `app_state`, `device_event`, `network`, `error` |
| `action` | `string` | No | Action name (free-form, but recommend controlled vocab) |
| `metadata` | `object` | No | Event-specific key-value pairs |

### Event Types

| Event Type | Purpose | Example Actions |
|------------|---------|-----------------|
| `user_action` | User-initiated events | `men_strike`, `kote_strike`, `dou_strike`, `tsuki_strike`, `fumikomi` |
| `app_state` | App lifecycle events | `session_start`, `session_pause`, `session_resume`, `session_end` |
| `device_event` | Device state changes | `battery_low`, `storage_warning`, `thermal_throttle` |
| `network` | Network events | `upload_start`, `upload_complete`, `upload_failed` |
| `error` | Errors during capture | `imu_dropout`, `timestamp_gap`, `buffer_overflow` |

### Example (Alpha - Minimal)

```jsonl
{"ts_ns": 1737371400000000000, "event_type": "app_state", "action": "session_start"}
{"ts_ns": 1737371405123456000, "event_type": "user_action", "action": "men_strike", "metadata": {"confidence": 0.95}}
{"ts_ns": 1737371407456789000, "event_type": "user_action", "action": "kote_strike", "metadata": {"confidence": 0.88}}
{"ts_ns": 1737371410987654000, "event_type": "user_action", "action": "men_strike", "metadata": {"confidence": 0.92}}
{"ts_ns": 1737371423987654000, "event_type": "app_state", "action": "session_end"}
```

### Example (GA - Rich)

```jsonl
{"ts_ns": 1737371400000000000, "event_type": "app_state", "action": "session_start", "metadata": {"battery_level": 0.87, "storage_available_gb": 12.4}}
{"ts_ns": 1737371401000000000, "event_type": "network", "action": "sas_token_obtained", "metadata": {"expires_in_seconds": 7200}}
{"ts_ns": 1737371405123456000, "event_type": "user_action", "action": "men_strike", "metadata": {"confidence": 0.95, "acceleration_peak_g": 12.3, "rotation_peak_dps": 450}}
{"ts_ns": 1737371406500000000, "event_type": "device_event", "action": "imu_sample_rate_changed", "metadata": {"old_hz": 100, "new_hz": 50, "reason": "thermal_throttle"}}
{"ts_ns": 1737371423987654000, "event_type": "app_state", "action": "session_end", "metadata": {"total_strikes": 15, "duration_seconds": 23.99}}
```

---

## 4. Manifest (`manifest_{imu_session_id}.json`)

Summary of all files in the session with checksums. This is uploaded by the client and verified by the server during finalization.

### Schema

```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "start_time_utc": "2025-01-20T10:30:00.123456Z",
  "end_time_utc": "2025-01-20T10:45:23.987654Z",
  "nominal_hz": 100.0,
  "coord_frame": "device",
  "gravity_removed": false,
  "num_samples": 92345,
  "files": [
    {
      "filename": "raw_42.parquet",
      "purpose": "raw",
      "content_type": "application/octet-stream",
      "bytes_size": 1234567,
      "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
      "num_samples": 92345
    },
    {
      "filename": "device_42.json",
      "purpose": "device",
      "content_type": "application/json",
      "bytes_size": 256,
      "sha256_hex": "c3d4e5f67890a1b2cdef34567890a1b2cdef34567890a1b2cdef34567890a1b2"
    },
    {
      "filename": "calib_42.json",
      "purpose": "calib",
      "content_type": "application/json",
      "bytes_size": 384,
      "sha256_hex": "d4e5f67890a1b2c3def4567890a1b2c3def4567890a1b2c3def4567890a1b2c3"
    },
    {
      "filename": "events_42.jsonl",
      "purpose": "events",
      "content_type": "application/x-ndjson",
      "bytes_size": 1024,
      "sha256_hex": "e5f67890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4"
    },
    {
      "filename": "manifest_42.json",
      "purpose": "manifest",
      "content_type": "application/json",
      "bytes_size": 512,
      "sha256_hex": "b2c3d4e5f67890a1bcdef234567890a1bcdef234567890a1bcdef234567890a1"
    }
  ],
  "manifest_version": "1.0",
  "client_upload_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `imu_session_id` | `integer` | Yes | Session ID from database |
| `user_id` | `string` | Yes | Auth0 user ID |
| `start_time_utc` | `string` | Yes | Session start time |
| `end_time_utc` | `string` | Yes | Session end time |
| `nominal_hz` | `float` | No | Expected sample rate |
| `coord_frame` | `string` | Yes | Enum: `device`, `world` |
| `gravity_removed` | `boolean` | Yes | Alpha: always `false` |
| `num_samples` | `integer` | Yes | Total samples across all raw files |
| `files[]` | `array` | Yes | Array of file metadata objects |
| `files[].filename` | `string` | Yes | Filename in blob storage |
| `files[].purpose` | `string` | Yes | Enum: `raw`, `device`, `calib`, `events`, `manifest` |
| `files[].content_type` | `string` | Yes | MIME type |
| `files[].bytes_size` | `integer` | Yes | File size in bytes |
| `files[].sha256_hex` | `string` | Yes | SHA-256 checksum (64 hex chars) |
| `files[].num_samples` | `integer` | No | Sample count (only for `raw` files) |
| `manifest_version` | `string` | Yes | Manifest schema version |
| `client_upload_id` | `string` | Yes | UUID for idempotency |

### Example (Full)

```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "start_time_utc": "2025-01-20T10:30:00.123456Z",
  "end_time_utc": "2025-01-20T10:45:23.987654Z",
  "nominal_hz": 100.0,
  "coord_frame": "device",
  "gravity_removed": false,
  "num_samples": 92345,
  "files": [
    {
      "filename": "raw_42.parquet",
      "purpose": "raw",
      "content_type": "application/octet-stream",
      "bytes_size": 1234567,
      "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
      "num_samples": 92345
    },
    {
      "filename": "device_42.json",
      "purpose": "device",
      "content_type": "application/json",
      "bytes_size": 256,
      "sha256_hex": "c3d4e5f67890a1b2cdef34567890a1b2cdef34567890a1b2cdef34567890a1b2"
    },
    {
      "filename": "calib_42.json",
      "purpose": "calib",
      "content_type": "application/json",
      "bytes_size": 384,
      "sha256_hex": "d4e5f67890a1b2c3def4567890a1b2c3def4567890a1b2c3def4567890a1b2c3"
    },
    {
      "filename": "events_42.jsonl",
      "purpose": "events",
      "content_type": "application/x-ndjson",
      "bytes_size": 1024,
      "sha256_hex": "e5f67890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4"
    },
    {
      "filename": "manifest_42.json",
      "purpose": "manifest",
      "content_type": "application/json",
      "bytes_size": 512,
      "sha256_hex": "b2c3d4e5f67890a1bcdef234567890a1bcdef234567890a1bcdef234567890a1"
    }
  ],
  "manifest_version": "1.0",
  "client_upload_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## File Purpose Enum

| Purpose | Required | Description |
|---------|----------|-------------|
| `raw` | Yes | Parquet file with IMU samples |
| `manifest` | Yes | This manifest file itself |
| `device` | Yes | Device snapshot JSON |
| `calib` | Recommended | Calibration data JSON |
| `events` | Optional | Events log JSONL |

---

## Upload Checklist

Before calling `POST /v1/imu/sessions/{id}/manifest`:

- [ ] All files uploaded to blob storage
- [ ] SHA-256 checksums computed and match
- [ ] File sizes match `bytes_size` in manifest
- [ ] `num_samples` in manifest matches total rows in Parquet
- [ ] `end_time_utc` ≥ `start_time_utc`
- [ ] `manifest.json` includes itself in `files[]` array
- [ ] All required sidecar files present (`raw`, `manifest`, `device`)
