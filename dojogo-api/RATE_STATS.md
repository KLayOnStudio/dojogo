# Non-Uniform Sampling Rate Handling

## Overview

iOS CoreMotion does not guarantee perfectly uniform sampling rates. Even when requesting 100Hz (`deviceMotionUpdateInterval = 0.01`), actual delivery varies due to:

- System load and thermal throttling
- Background processes and interrupts
- Device hardware characteristics
- Battery state and power management

**Solution:** Store true timestamps in raw data, compute actual rate statistics, and enable downstream resampling for ML pipelines.

---

## Design Principles

1. **Client records truth** - Store per-sample nanosecond timestamps, do not pre-filter
2. **Request target rate** - Set `nominal_hz` (e.g., 100.0) but accept what device delivers
3. **Compute stats at finalize** - Calculate actual mean rate and jitter metrics before upload
4. **Server stores for QC** - Enable filtering low-quality sessions in training pipeline
5. **Backward compatible** - Older app builds without `rate_stats` still finalize successfully

---

## Client Implementation

### 1. Request Target Rate

```swift
let sampleRate = 100.0  // Target Hz
motionManager.deviceMotionUpdateInterval = 1.0 / sampleRate
```

**Note:** This is a _request_, not a guarantee. Actual rate computed from timestamps.

### 2. Store True Timestamps

```swift
let sample = IMUSample(
    ts_ns: Int64(Date().timeIntervalSince1970 * 1_000_000_000),  // Nanoseconds since epoch
    ax: Float(motion.userAcceleration.x * 9.80665),
    ay: Float(motion.userAcceleration.y * 9.80665),
    az: Float(motion.userAcceleration.z * 9.80665),
    gx: Float(motion.rotationRate.x),
    gy: Float(motion.rotationRate.y),
    gz: Float(motion.rotationRate.z)
)
```

**Do NOT:**
- Downsample or filter on device
- Assume uniform spacing
- Drop samples to match target rate

### 3. Compute Rate Stats Before Finalize

```swift
func computeRateStats() -> RateStats? {
    // 1. Collect all timestamps from all parts
    var allTimestamps: [Int64] = []
    for part in pendingParts {
        let samples = readSamplesFromPart(part)
        allTimestamps.append(contentsOf: samples.map { $0.ts_ns })
    }

    guard !allTimestamps.isEmpty else { return nil }

    // 2. Sort timestamps
    allTimestamps.sort()

    let samplesTotal = allTimestamps.count
    let firstTs = allTimestamps.first!
    let lastTs = allTimestamps.last!

    // 3. Duration (milliseconds)
    let durationMs = Double(lastTs - firstTs) / 1_000_000.0

    guard durationMs > 0 else { return nil }

    // 4. Mean Hz
    let meanHz = Double(samplesTotal) / (durationMs / 1000.0)

    // 5. Compute inter-sample intervals (dt)
    var deltas: [Double] = []
    for i in 1..<allTimestamps.count {
        let dt_ns = allTimestamps[i] - allTimestamps[i - 1]
        let dt_ms = Double(dt_ns) / 1_000_000.0
        deltas.append(dt_ms)
    }

    deltas.sort()

    // 6. Percentiles
    let p50Index = Int(Double(deltas.count) * 0.50)
    let p95Index = Int(Double(deltas.count) * 0.95)

    let dtMsP50 = deltas[p50Index]
    let dtMsP95 = deltas[p95Index]
    let dtMsMax = deltas.last!

    return RateStats(
        samplesTotal: samplesTotal,
        durationMs: durationMs,
        meanHz: meanHz,
        dtMsP50: dtMsP50,
        dtMsP95: dtMsP95,
        dtMsMax: dtMsMax,
        droppedSeqPct: nil  // Optional: track sequence numbers
    )
}
```

### 4. Include in Manifest Payload

```swift
let request = FinalizeManifestRequest(
    endTimeUtc: ISO8601DateFormatter().string(from: Date()),
    files: files,
    rateStats: computeRateStats()  // Optional, can be nil
)
```

**Example Payload:**
```json
{
  "end_time_utc": "2025-01-20T10:45:23.987654Z",
  "files": [ /* ... */ ],
  "rate_stats": {
    "samples_total": 842113,
    "duration_ms": 156664.2,
    "mean_hz": 99.8,
    "dt_ms_p50": 10.0,
    "dt_ms_p95": 10.6,
    "dt_ms_max": 24.7,
    "dropped_seq_pct": 0.0
  }
}
```

---

## Server Implementation

### Database Schema

```sql
-- Add actual_mean_hz to imu_sessions for quick filtering
ALTER TABLE imu_sessions
  ADD COLUMN actual_mean_hz DECIMAL(8,3) NULL AFTER nominal_hz;

-- Create dedicated stats table
CREATE TABLE imu_session_stats (
  imu_session_id  BIGINT PRIMARY KEY,
  samples_total   BIGINT NOT NULL,
  duration_ms     DECIMAL(12,3) NOT NULL,
  mean_hz         DECIMAL(8,3) NOT NULL,
  dt_ms_p50       DECIMAL(8,3) NULL,
  dt_ms_p95       DECIMAL(8,3) NULL,
  dt_ms_max       DECIMAL(8,3) NULL,
  dropped_seq_pct DECIMAL(5,2) NULL,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_imus_stats FOREIGN KEY (imu_session_id)
    REFERENCES imu_sessions(imu_session_id) ON DELETE CASCADE
);
```

### API Handler (FinalizeImuManifest)

```python
# Extract rate_stats from request (optional)
rate_stats = req_body.get('rate_stats')

# Update session with actual_mean_hz
actual_mean_hz = None
if rate_stats:
    actual_mean_hz = rate_stats.get('mean_hz')

execute_query(
    """
    UPDATE imu_sessions
    SET end_time_utc = %s, actual_mean_hz = %s
    WHERE imu_session_id = %s
    """,
    (end_dt, actual_mean_hz, imu_session_id)
)

# Store detailed stats (if provided)
if rate_stats:
    samples_total = rate_stats.get('samples_total')
    duration_ms = rate_stats.get('duration_ms')
    mean_hz = rate_stats.get('mean_hz')

    if all([samples_total, duration_ms, mean_hz]):
        # Check idempotency
        existing = execute_query(
            "SELECT imu_session_id FROM imu_session_stats WHERE imu_session_id = %s",
            (imu_session_id,), fetch=True
        )

        if not existing:
            execute_query(
                """
                INSERT INTO imu_session_stats
                (imu_session_id, samples_total, duration_ms, mean_hz, dt_ms_p50, dt_ms_p95, dt_ms_max, dropped_seq_pct)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    imu_session_id,
                    samples_total,
                    duration_ms,
                    mean_hz,
                    rate_stats.get('dt_ms_p50'),
                    rate_stats.get('dt_ms_p95'),
                    rate_stats.get('dt_ms_max'),
                    rate_stats.get('dropped_seq_pct')
                )
            )
```

**Backward Compatibility:**
- If `rate_stats` missing (older app), finalize succeeds normally
- `actual_mean_hz` remains NULL
- No row inserted into `imu_session_stats`

---

## Metrics Definitions

### samples_total
- **Type:** `integer`
- **Description:** Total samples across all raw files
- **Computation:** Count of all rows in Parquet/JSONL files
- **Example:** `842113`

### duration_ms
- **Type:** `float`
- **Description:** Session duration in milliseconds
- **Computation:** `(last_ts_ns - first_ts_ns) / 1_000_000.0`
- **Example:** `156664.2` (≈ 156.7 seconds)

### mean_hz
- **Type:** `float`
- **Description:** Actual mean sample rate
- **Computation:** `samples_total / (duration_ms / 1000.0)`
- **Example:** `99.8` Hz (target was 100.0 Hz)
- **Interpretation:**
  - 95-105 Hz: Good quality
  - 90-95 or 105-110 Hz: Acceptable
  - <90 or >110 Hz: Investigate device issues

### dt_ms_p50 (Median Interval)
- **Type:** `float`
- **Description:** 50th percentile inter-sample interval
- **Computation:** Median of `[ts[i] - ts[i-1] for i in 1..N]` in milliseconds
- **Example:** `10.0` ms (1/100 Hz = 10ms)
- **Interpretation:**
  - Close to `1000/nominal_hz`: Good uniformity
  - >1.5x target: High jitter

### dt_ms_p95 (95th Percentile Interval)
- **Type:** `float`
- **Description:** 95th percentile inter-sample interval
- **Computation:** 95th percentile of inter-sample deltas
- **Example:** `10.6` ms
- **Use Case:** QC filter for training pipeline
- **Threshold:** `dt_ms_p95 < 1.5 * (1000/nominal_hz)` → Keep session
- **Example Filter:** At 100Hz, keep if `dt_ms_p95 < 15.0` ms

### dt_ms_max (Max Gap)
- **Type:** `float`
- **Description:** Maximum inter-sample interval
- **Computation:** Max of all inter-sample deltas
- **Example:** `24.7` ms
- **Interpretation:**
  - <20ms at 100Hz: No major gaps
  - 20-50ms: Minor dropout (app backgrounded?)
  - >50ms: Significant gap, investigate

### dropped_seq_pct (Optional)
- **Type:** `float`
- **Description:** Percentage of dropped samples (if sequence tracking enabled)
- **Computation:** `100 * (expected_samples - actual_samples) / expected_samples`
- **Example:** `0.0` (no drops), `2.5` (2.5% dropped)
- **Alpha:** Not tracked, set to `NULL`
- **Future:** Add `seq` column to Parquet, detect non-consecutive values

---

## Quality Control Queries

### Find High-Quality Sessions

```sql
SELECT
    ims.imu_session_id,
    ims.user_id,
    ims.nominal_hz,
    ims.actual_mean_hz,
    iss.dt_ms_p50,
    iss.dt_ms_p95,
    iss.dt_ms_max
FROM imu_sessions ims
JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
WHERE ims.nominal_hz = 100.0
  AND iss.mean_hz BETWEEN 95.0 AND 105.0  -- Within 5% of target
  AND iss.dt_ms_p95 < 15.0                 -- P95 < 1.5x target interval
  AND iss.dt_ms_max < 50.0                 -- No major gaps
ORDER BY iss.dt_ms_p95 ASC;
```

### Detect Problematic Sessions

```sql
SELECT
    ims.imu_session_id,
    ims.start_time_utc,
    ims.nominal_hz,
    iss.mean_hz,
    iss.dt_ms_p95,
    iss.dt_ms_max,
    CASE
        WHEN iss.mean_hz < 90.0 OR iss.mean_hz > 110.0 THEN 'Rate deviation'
        WHEN iss.dt_ms_p95 > 20.0 THEN 'High jitter'
        WHEN iss.dt_ms_max > 100.0 THEN 'Major gap'
        ELSE 'Unknown issue'
    END as issue_type
FROM imu_sessions ims
JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
WHERE ims.nominal_hz = 100.0
  AND (
    iss.mean_hz < 90.0 OR iss.mean_hz > 110.0
    OR iss.dt_ms_p95 > 20.0
    OR iss.dt_ms_max > 100.0
  )
ORDER BY iss.dt_ms_max DESC;
```

### Compute Platform Statistics

```sql
SELECT
    d.platform,
    COUNT(*) as session_count,
    AVG(iss.mean_hz) as avg_actual_hz,
    STDDEV(iss.mean_hz) as stddev_hz,
    AVG(iss.dt_ms_p95) as avg_p95_jitter,
    MAX(iss.dt_ms_max) as max_gap
FROM imu_sessions ims
JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
JOIN devices d ON ims.device_id = d.device_id
WHERE ims.nominal_hz = 100.0
GROUP BY d.platform
ORDER BY avg_actual_hz DESC;
```

**Example Output:**
| platform | session_count | avg_actual_hz | stddev_hz | avg_p95_jitter | max_gap |
|----------|---------------|---------------|-----------|----------------|---------|
| ios      | 1523          | 99.8          | 1.2       | 10.4           | 38.2    |
| android  | 876           | 97.3          | 3.8       | 12.7           | 124.6   |

---

## Downstream Resampling

Training pipelines will resample to uniform 100Hz using true timestamps:

```python
import pandas as pd
import numpy as np

# Load Parquet with true timestamps
df = pd.read_parquet('raw_42_0000.parquet')

# Convert ns to seconds
df['ts_s'] = df['ts_ns'] / 1e9

# Resample to uniform 100Hz grid
target_hz = 100.0
target_dt = 1.0 / target_hz

# Create uniform time grid
t_start = df['ts_s'].min()
t_end = df['ts_s'].max()
t_uniform = np.arange(t_start, t_end, target_dt)

# Interpolate all channels onto uniform grid
df_resampled = pd.DataFrame({'ts_s': t_uniform})

for col in ['ax', 'ay', 'az', 'gx', 'gy', 'gz']:
    df_resampled[col] = np.interp(t_uniform, df['ts_s'], df[col])

# Now df_resampled has uniform 100Hz spacing
print(f"Original: {len(df)} samples, Resampled: {len(df_resampled)} samples")
```

**QC Filter Before Training:**
```python
# Load session metadata
session_stats = load_session_stats(imu_session_id)

# Filter criteria
target_hz = 100.0
target_dt_ms = 1000.0 / target_hz  # 10ms

if session_stats['dt_ms_p95'] > 1.5 * target_dt_ms:
    print(f"⚠️ Session {imu_session_id} excluded: high jitter (P95={session_stats['dt_ms_p95']:.1f}ms)")
    return None

if abs(session_stats['mean_hz'] - target_hz) > 10.0:
    print(f"⚠️ Session {imu_session_id} excluded: rate deviation (actual={session_stats['mean_hz']:.1f}Hz)")
    return None

# Session passes QC, proceed with resampling
df_resampled = resample_to_uniform(df, target_hz)
```

---

## Example: Good vs Bad Sessions

### Good Session (Low Jitter)

```json
{
  "imu_session_id": 42,
  "nominal_hz": 100.0,
  "actual_mean_hz": 99.8,
  "rate_stats": {
    "samples_total": 120000,
    "duration_ms": 1202.4,
    "mean_hz": 99.8,
    "dt_ms_p50": 10.0,
    "dt_ms_p95": 10.2,
    "dt_ms_max": 12.1
  }
}
```

**Analysis:**
- Mean rate 99.8 Hz (0.2% from target)
- P50 = 10.0ms (exactly 1/100 Hz)
- P95 = 10.2ms (2% jitter)
- Max gap 12.1ms (minimal dropout)
- **Verdict:** ✅ Excellent quality, use for training

### Bad Session (High Jitter)

```json
{
  "imu_session_id": 87,
  "nominal_hz": 100.0,
  "actual_mean_hz": 94.3,
  "rate_stats": {
    "samples_total": 113160,
    "duration_ms": 1200.0,
    "mean_hz": 94.3,
    "dt_ms_p50": 10.1,
    "dt_ms_p95": 18.7,
    "dt_ms_max": 87.3
  }
}
```

**Analysis:**
- Mean rate 94.3 Hz (5.7% from target)
- P50 = 10.1ms (acceptable)
- P95 = 18.7ms (87% higher than target 10ms)
- Max gap 87.3ms (app backgrounded or thermal throttle)
- **Verdict:** ❌ Exclude from training, investigate device issues

---

## Migration Checklist

- [x] Run `database_migration_rate_stats.sql`
- [x] Verify `actual_mean_hz` column added to `imu_sessions`
- [x] Verify `imu_session_stats` table created with foreign key
- [x] Deploy updated `FinalizeImuManifest` Azure Function
- [x] Update OpenAPI spec with `rate_stats` schema
- [x] Update Swift `IMUCaptureManager` to compute and send `rate_stats`
- [ ] Test with real device: verify stats logged to console
- [ ] Test backward compatibility: older app builds still finalize
- [ ] Query `imu_session_stats` to verify data stored correctly
- [ ] Create QC dashboard showing mean_hz and jitter distributions

---

## Testing

### Manual Test (Device)

1. Start IMU recording
2. Record for 60 seconds
3. Check console output:
   ```
   📊 Rate stats: 99.8 Hz actual (target: 100.0 Hz)
      Duration: 60123.4ms, Samples: 6012
      dt P50: 10.0ms, P95: 10.5ms, Max: 18.2ms
   ```
4. Verify manifest includes `rate_stats`

### Automated Test (API)

```bash
# Create session
SESSION_RESPONSE=$(curl -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$(uuidgen)'",
    "device_info": {"platform": "ios"},
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0
  }')

IMU_SESSION_ID=$(echo $SESSION_RESPONSE | jq -r '.imu_session_id')

# Finalize with rate_stats
curl -X POST "$API_BASE/api/v1/imu/sessions/$IMU_SESSION_ID/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "files": [
      {
        "filename": "raw_'$IMU_SESSION_ID'_0000.jsonl",
        "purpose": "raw",
        "content_type": "application/x-ndjson",
        "bytes_size": 12345,
        "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
        "num_samples": 1000
      }
    ],
    "rate_stats": {
      "samples_total": 1000,
      "duration_ms": 10012.3,
      "mean_hz": 99.88,
      "dt_ms_p50": 10.0,
      "dt_ms_p95": 10.3,
      "dt_ms_max": 15.2
    }
  }'

# Verify stats stored
mysql -h dojogo-mysql.mysql.database.azure.com -u dojogo_admin -p -D dojogo_db \
  -e "SELECT * FROM imu_session_stats WHERE imu_session_id = $IMU_SESSION_ID;"
```

---

## Future Enhancements

1. **Sequence Number Tracking:**
   - Add `seq` column to Parquet schema
   - Client maintains rolling counter
   - Compute `dropped_seq_pct` from gaps in sequence

2. **Real-Time Rate Monitoring:**
   - Display current rate in UI during recording
   - Warn user if rate drops below threshold
   - Suggest "close background apps" if jitter high

3. **Adaptive Sampling:**
   - If dt_ms_p95 > threshold, increase buffer size
   - If device thermal throttles, reduce target rate

4. **Platform Benchmarking:**
   - Collect stats per device model
   - Recommend optimal `nominal_hz` per platform
   - Document known issues (e.g., "iPhone SE 2020: max 80Hz stable")
