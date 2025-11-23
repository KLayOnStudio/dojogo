# IMU Parquet File Format Specification

## Overview

Raw IMU data is stored in Apache Parquet columnar format for efficient compression and query performance. Each session produces one or more Parquet files named `raw_{imu_session_id}.parquet`.

## Column Schema

### Required Columns (Strict Order)

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `ts_ns` | `int64` | nanoseconds | Timestamp since Unix epoch (1970-01-01 00:00:00 UTC) |
| `ax` | `float32` | m/s² | Acceleration X-axis |
| `ay` | `float32` | m/s² | Acceleration Y-axis |
| `az` | `float32` | m/s² | Acceleration Z-axis |
| `gx` | `float32` | rad/s | Gyroscope X-axis (angular velocity) |
| `gy` | `float32` | rad/s | Gyroscope Y-axis (angular velocity) |
| `gz` | `float32` | rad/s | Gyroscope Y-axis (angular velocity) |

### Optional Columns (Append After Required)

| Column | Type | Unit | Description |
|--------|------|------|-------------|
| `mx` | `float32` | µT | Magnetometer X-axis (microtesla) |
| `my` | `float32` | µT | Magnetometer Y-axis |
| `mz` | `float32` | µT | Magnetometer Z-axis |
| `qw` | `float32` | - | Quaternion W (scalar part) |
| `qx` | `float32` | - | Quaternion X |
| `qy` | `float32` | - | Quaternion Y |
| `qz` | `float32` | - | Quaternion Z |
| `temp` | `float32` | °C | Temperature in Celsius |
| `seq` | `int64` | - | Device-side sequence number for debugging |

**Column Order Rule:** Required columns must appear first in the exact order listed. Optional columns may appear in any order after required columns, but should remain consistent within a session.

## Required Parquet Metadata (Key-Value Pairs)

The following metadata must be embedded in the Parquet file footer:

| Key | Type | Description | Example |
|-----|------|-------------|---------|
| `imu_session_id` | `string` | Session ID from database | `"42"` |
| `user_id` | `string` | Auth0 user ID | `"auth0\|abc123"` |
| `device_id` | `string` | Device ID from database | `"7"` |
| `start_time_utc` | `string` | ISO 8601 session start time | `"2025-01-20T10:30:00.123456Z"` |
| `nominal_hz` | `string` | Expected sample rate | `"100.0"` |
| `coord_frame` | `string` | Coordinate frame | `"device"` or `"world"` |
| `gravity_removed` | `string` | Whether gravity was removed | `"false"` (alpha: always false) |
| `schema_version` | `string` | Schema version for forward compat | `"1.0"` |

**Note:** All metadata values are stored as strings in Parquet KV metadata.

## Data Conventions

### Timestamps
- **Format:** Nanoseconds since Unix epoch (1970-01-01 00:00:00 UTC)
- **Type:** `int64`
- **Example:** `1737371400123456000` = 2025-01-20T10:30:00.123456Z
- **Monotonicity:** Timestamps must be strictly increasing within a file
- **Resolution:** Device-dependent; iOS typically 1ms, Android varies

### Accelerometer (ax, ay, az)
- **Unit:** m/s² (SI standard)
- **Range:** Typical ±16g to ±156.96 m/s²
- **Gravity:** **INCLUDED** in alpha (do not remove gravity)
- **Coordinate Frame:** Device-local by default
  - iOS: X=right, Y=up (screen), Z=out (toward user)
  - Android: X=right, Y=up (screen), Z=out (toward user)
  - Switch: TBD (document when supported)

### Gyroscope (gx, gy, gz)
- **Unit:** rad/s (SI standard)
- **Range:** Typical ±2000°/s ≈ ±34.9 rad/s
- **Coordinate Frame:** Same as accelerometer
- **Drift:** Uncorrected in alpha

### Magnetometer (mx, my, mz) - Optional
- **Unit:** µT (microtesla)
- **Range:** Earth's field ~25-65 µT
- **Calibration:** Hard/soft iron uncorrected in alpha
- **Note:** Not available on all devices

### Quaternion (qw, qx, qy, qz) - Optional
- **Unit:** Dimensionless (normalized)
- **Format:** Hamilton convention (qw is scalar)
- **Normalization:** qw² + qx² + qy² + qz² = 1.0
- **Source:** Device fusion algorithm (e.g., CMAttitude on iOS)
- **Availability:** Only if device provides fused orientation

### Temperature (temp) - Optional
- **Unit:** °C (Celsius)
- **Source:** IMU die temperature
- **Availability:** Device-dependent

### Sequence Number (seq) - Optional
- **Type:** `int64`
- **Purpose:** Client-side monotonic counter for dropped sample detection
- **Reset:** Per session

## Example Parquet File (Python)

```python
import pyarrow as pa
import pyarrow.parquet as pq
import numpy as np

# Sample data (3 samples at 100Hz)
num_samples = 3
data = {
    'ts_ns': np.array([1737371400000000000, 1737371400010000000, 1737371400020000000], dtype=np.int64),
    'ax': np.array([0.15, 0.18, 0.12], dtype=np.float32),
    'ay': np.array([9.81, 9.83, 9.80], dtype=np.float32),  # ~1g on Y (phone flat)
    'az': np.array([0.02, 0.01, 0.03], dtype=np.float32),
    'gx': np.array([0.001, 0.002, 0.000], dtype=np.float32),
    'gy': np.array([-0.001, 0.000, 0.001], dtype=np.float32),
    'gz': np.array([0.150, 0.148, 0.152], dtype=np.float32),  # ~8.6°/s rotation
}

# Create schema (column order matters!)
schema = pa.schema([
    pa.field('ts_ns', pa.int64()),
    pa.field('ax', pa.float32()),
    pa.field('ay', pa.float32()),
    pa.field('az', pa.float32()),
    pa.field('gx', pa.float32()),
    pa.field('gy', pa.float32()),
    pa.field('gz', pa.float32()),
])

# Create table
table = pa.Table.from_pydict(data, schema=schema)

# Add required metadata
metadata = {
    'imu_session_id': '42',
    'user_id': 'auth0|abc123',
    'device_id': '7',
    'start_time_utc': '2025-01-20T10:30:00.000000Z',
    'nominal_hz': '100.0',
    'coord_frame': 'device',
    'gravity_removed': 'false',
    'schema_version': '1.0',
}

# Merge with existing schema metadata
existing_meta = table.schema.metadata or {}
merged_meta = {**existing_meta, **{k.encode(): v.encode() for k, v in metadata.items()}}
table = table.replace_schema_metadata(merged_meta)

# Write Parquet file
pq.write_table(
    table,
    'raw_42.parquet',
    compression='snappy',  # Fast compression for alpha
    use_dictionary=False,  # Time-series data rarely benefits from dictionary encoding
    write_statistics=True,  # Min/max for query pruning
)

print(f"Written {num_samples} samples to raw_42.parquet")
```

## Example Parquet File (Swift/iOS)

iOS does not have native Parquet support. Options:

1. **Write CSV, convert server-side** (simple but inefficient)
2. **Use C++ Parquet library via bridging header** (complex)
3. **Write binary format, convert server-side** (recommended for alpha)

**Recommended Alpha Approach:** Write newline-delimited JSON (JSONL) and convert to Parquet server-side:

```swift
struct IMUSample: Codable {
    let ts_ns: Int64
    let ax: Float
    let ay: Float
    let az: Float
    let gx: Float
    let gy: Float
    let gz: Float
}

func writeIMUData(samples: [IMUSample], to url: URL) throws {
    let encoder = JSONEncoder()
    var lines: [String] = []

    for sample in samples {
        let data = try encoder.encode(sample)
        if let json = String(data: data, encoding: .utf8) {
            lines.append(json)
        }
    }

    let content = lines.joined(separator: "\n")
    try content.write(to: url, atomically: true, encoding: .utf8)
}
```

Then convert JSONL → Parquet in Azure Function or background job.

## File Naming Convention

- **Pattern:** `raw_{imu_session_id}.parquet`
- **Example:** `raw_42.parquet` for session ID 42
- **Multiple Files:** If session spans multiple files (e.g., chunked uploads), use:
  - `raw_{imu_session_id}_001.parquet`
  - `raw_{imu_session_id}_002.parquet`
  - etc.

## Compression

- **Recommended:** Snappy (fast compression/decompression, ~2-3x ratio)
- **Alternative:** GZIP (better ratio ~4-5x, slower)
- **Avoid:** Uncompressed (wastes storage), LZ4 (marginal benefit over Snappy)

## Row Group Size

- **Recommended:** 10,000 - 100,000 rows per row group
- **Rationale:** Balance between compression efficiency and query granularity
- **Example:** At 100Hz, 10,000 rows = 100 seconds of data

## Statistics

- **Enable:** `write_statistics=True`
- **Purpose:** Min/max timestamps for temporal query pruning
- **Cost:** Minimal overhead, significant query speedup

## Validation Checklist

Before finalizing manifest:

- [ ] All required columns present in correct order
- [ ] All metadata KV pairs present
- [ ] Timestamps strictly monotonic increasing
- [ ] Accelerometer values in reasonable range (< ±200 m/s²)
- [ ] Gyroscope values in reasonable range (< ±50 rad/s)
- [ ] File size matches `bytes_size` in manifest
- [ ] SHA-256 checksum matches `sha256_hex` in manifest
- [ ] Compression enabled (file size << raw CSV equivalent)

## Future Enhancements (Post-Alpha)

- Add `gravity_removed` flag and provide both raw + processed files
- Add `world` coordinate frame option (device fusion)
- Add `pressure` column for altitude (barometer)
- Add `latitude`, `longitude`, `altitude` columns (GPS fusion)
- Add `label` column for annotated events (supervised learning)
- Implement server-side JSONL → Parquet conversion pipeline
