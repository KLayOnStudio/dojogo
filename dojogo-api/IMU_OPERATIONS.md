# IMU System Operations Guide

## Overview

This guide covers deployment, monitoring, cost estimation, and operational best practices for the DojoGo IMU data capture system.

---

## Deployment

### Prerequisites

1. **Azure Resources:**
   - Azure Functions App (Python 3.9+)
   - Azure Storage Account (General Purpose v2)
   - Azure MySQL Flexible Server (MySQL 8.0+)
   - Application Insights (recommended for monitoring)

2. **Environment Variables:**
   ```bash
   AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;EndpointSuffix=core.windows.net"
   MYSQL_HOST="dojogo-mysql.mysql.database.azure.com"
   MYSQL_PORT="3306"
   MYSQL_USER="dojogo_admin"
   MYSQL_PASSWORD="your_secure_password"
   MYSQL_DATABASE="dojogo_db"
   AUTH0_DOMAIN="your-tenant.us.auth0.com"
   AUTH0_AUDIENCE="https://api.dojogo.app"
   ```

### Database Migration

```bash
# Connect to MySQL
mysql -h dojogo-mysql.mysql.database.azure.com \
  -u dojogo_admin -p \
  -D dojogo_db \
  --ssl-mode=REQUIRED

# Run migration
mysql> source database_migration_imu_phase1.sql;

# Verify tables created
mysql> SHOW TABLES LIKE 'imu_%';
mysql> SHOW TABLES LIKE 'devices';

# Verify foreign keys
mysql> SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'dojogo_db'
  AND REFERENCED_TABLE_NAME IS NOT NULL
  AND TABLE_NAME LIKE 'imu_%' OR TABLE_NAME = 'devices';
```

### Azure Blob Storage Setup

```bash
# Create container via Azure CLI
az storage container create \
  --name imu-alpha \
  --account-name dojogostore \
  --public-access off \
  --auth-mode login

# Verify container exists
az storage container list \
  --account-name dojogostore \
  --auth-mode login \
  --query "[?name=='imu-alpha']"

# Configure lifecycle management (optional - archive after 90 days)
az storage account management-policy create \
  --account-name dojogostore \
  --policy @imu-lifecycle-policy.json
```

**imu-lifecycle-policy.json:**
```json
{
  "rules": [
    {
      "enabled": true,
      "name": "archive-old-imu-data",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": {
              "daysAfterModificationGreaterThan": 30
            },
            "tierToArchive": {
              "daysAfterModificationGreaterThan": 90
            }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["imu-alpha/"]
        }
      }
    }
  ]
}
```

### Deploy Azure Functions

```bash
# Navigate to API directory
cd dojogo-api

# Install Python dependencies
pip install -r requirements.txt

# Deploy to Azure Functions
func azure functionapp publish dojogo-api

# Verify deployment
func azure functionapp list-functions dojogo-api

# Test health endpoint
curl https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api/TestHealth
```

---

## Client Implementation (iOS)

### Background Upload Pattern

**Key Requirements:**
- Upload IMU data in background (app can be suspended)
- Max 1-2 concurrent uploads to avoid throttling
- Retry failed uploads with exponential backoff
- Validate checksums before finalizing manifest

### Swift Implementation Outline

```swift
import Foundation
import BackgroundTasks

class IMUUploadManager {
    static let shared = IMUUploadManager()

    // MARK: - Configuration
    private let maxConcurrentUploads = 2
    private let sessionConfig: URLSessionConfiguration = {
        let config = URLSessionConfiguration.background(withIdentifier: "app.dojogo.imu-upload")
        config.isDiscretionary = false  // Upload even on cellular
        config.sessionSendsLaunchEvents = true
        return config
    }()

    private lazy var uploadSession: URLSession = {
        URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Upload Workflow

    /// Step 1: Create IMU session and get SAS token
    func createSession(clientUploadId: UUID, deviceInfo: DeviceInfo, startTime: Date) async throws -> IMUSessionResponse {
        let endpoint = "\(APIService.baseURL)/v1/imu/sessions"
        let body: [String: Any] = [
            "client_upload_id": clientUploadId.uuidString,
            "device_info": deviceInfo.toDictionary(),
            "start_time_utc": ISO8601DateFormatter().string(from: startTime),
            "nominal_hz": 100.0,
            "coord_frame": "device"
        ]

        // POST request with Auth0 token
        let response = try await APIService.shared.post(endpoint, body: body)
        return try JSONDecoder().decode(IMUSessionResponse.self, from: response)
    }

    /// Step 2: Upload files to blob storage using SAS URL
    func uploadFiles(sessionId: Int, sasURL: URL, files: [IMUFile]) async throws {
        for file in files {
            let blobURL = sasURL.appendingPathComponent(file.filename)

            var request = URLRequest(url: blobURL)
            request.httpMethod = "PUT"
            request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
            request.setValue(file.contentType, forHTTPHeaderField: "Content-Type")

            // Use background upload task
            let uploadTask = uploadSession.uploadTask(with: request, fromFile: file.localURL)
            uploadTask.resume()

            // Track upload progress
            print("📤 Uploading \(file.filename) (\(file.bytesSize) bytes)")
        }
    }

    /// Step 3: Finalize manifest with checksums
    func finalizeManifest(sessionId: Int, endTime: Date, files: [IMUFile]) async throws {
        let endpoint = "\(APIService.baseURL)/v1/imu/sessions/\(sessionId)/manifest"
        let body: [String: Any] = [
            "end_time_utc": ISO8601DateFormatter().string(from: endTime),
            "files": files.map { $0.toManifestEntry() }
        ]

        _ = try await APIService.shared.post(endpoint, body: body)
        print("✅ Manifest finalized for session \(sessionId)")
    }

    // MARK: - Checksum Calculation

    func sha256(fileURL: URL) throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: fileData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URLSessionDelegate

extension IMUUploadManager: URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Upload failed: \(error.localizedDescription)")
            // Implement retry logic with exponential backoff
        } else {
            print("✅ Upload completed: \(task.originalRequest?.url?.lastPathComponent ?? "unknown")")
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("📦 Background uploads finished")
        // Finalize manifest when all uploads complete
    }
}
```

### Usage Example

```swift
let manager = IMUUploadManager.shared
let clientUploadId = UUID()

// Step 1: Create session
let sessionResponse = try await manager.createSession(
    clientUploadId: clientUploadId,
    deviceInfo: DeviceInfo.current(),
    startTime: recordingStartTime
)

// Step 2: Upload files
let files = [
    IMUFile(filename: "raw_\(sessionResponse.imuSessionId).parquet", localURL: rawDataURL),
    IMUFile(filename: "device_\(sessionResponse.imuSessionId).json", localURL: deviceURL),
    IMUFile(filename: "calib_\(sessionResponse.imuSessionId).json", localURL: calibURL),
    IMUFile(filename: "events_\(sessionResponse.imuSessionId).jsonl", localURL: eventsURL),
    IMUFile(filename: "manifest_\(sessionResponse.imuSessionId).json", localURL: manifestURL)
]

try await manager.uploadFiles(
    sessionId: sessionResponse.imuSessionId,
    sasURL: URL(string: sessionResponse.sasToken.sasURL)!,
    files: files
)

// Step 3: Finalize manifest
try await manager.finalizeManifest(
    sessionId: sessionResponse.imuSessionId,
    endTime: recordingEndTime,
    files: files
)
```

---

## Cost Estimation

### Assumptions (Alpha Phase)

- **Users:** 100 alpha testers
- **Sessions per user per week:** 5
- **Session duration:** 2 minutes average
- **Sample rate:** 100Hz
- **Samples per session:** 100 Hz × 120 sec = 12,000 samples
- **Raw Parquet size:** ~200 KB per session (with Snappy compression)
- **Sidecar files:** ~5 KB total (device + calib + events + manifest)
- **Total per session:** ~205 KB

**Monthly Totals:**
- Sessions: 100 users × 5 sessions/week × 4 weeks = 2,000 sessions/month
- Data ingested: 2,000 × 205 KB = 410 MB/month
- Database rows (imu_sessions): 2,000 rows/month
- Database rows (imu_session_files): 2,000 × 5 files = 10,000 rows/month

### Azure Blob Storage Costs (Hot Tier)

| Item | Quantity | Unit Price | Monthly Cost |
|------|----------|------------|--------------|
| Storage (Hot) | 0.41 GB | $0.018/GB | $0.01 |
| Write operations | 10,000 | $0.055 per 10K | $0.06 |
| Read operations | 1,000 | $0.0044 per 10K | $0.00 |
| **Subtotal** | | | **$0.07/month** |

### Azure MySQL Flexible Server Costs

Assuming **Burstable B1ms** (1 vCore, 2 GiB RAM):

| Item | Quantity | Unit Price | Monthly Cost |
|------|----------|------------|--------------|
| Compute (B1ms) | 730 hours | $0.0138/hour | $10.07 |
| Storage (20 GB) | 20 GB | $0.115/GB | $2.30 |
| Backup (7 days) | ~10 GB | $0.095/GB | $0.95 |
| **Subtotal** | | | **$13.32/month** |

**Note:** Storage grows by ~50 MB/month (IMU tables), so this is stable for 12+ months.

### Azure Functions Costs (Consumption Plan)

| Item | Quantity | Unit Price | Monthly Cost |
|------|----------|------------|--------------|
| Executions | 6,000 | $0.20 per 1M | $0.00 |
| Execution time (avg 500ms @ 512MB) | 3,000 GB-sec | $0.000016/GB-sec | $0.05 |
| **Subtotal** | | | **$0.05/month** |

### Total Estimated Cost (Alpha)

| Service | Monthly Cost |
|---------|--------------|
| Blob Storage | $0.07 |
| MySQL | $13.32 |
| Functions | $0.05 |
| **Total** | **$13.44/month** |

### Cost Scaling (GA - 10,000 Users)

| Metric | Alpha | GA (10K users) | Notes |
|--------|-------|----------------|-------|
| Sessions/month | 2,000 | 200,000 | 100x |
| Data ingested | 410 MB | 41 GB | 100x |
| Blob storage cost | $0.07 | $7.00 | Hot tier, 1 month retention |
| MySQL cost | $13.32 | $50.00 | Upgrade to GP D2ds_v4 (2 vCore) |
| Functions cost | $0.05 | $5.00 | Still well within consumption tier |
| **Total/month** | **$13.44** | **~$62/month** | |
| **Per active user** | **$0.13** | **$0.0062** | Economies of scale |

**Optimization Opportunities:**
- Move to **Cool tier** after 30 days → 50% storage cost reduction
- Move to **Archive tier** after 90 days → 90% storage cost reduction
- Implement data retention policy (delete after 1 year) → cap storage growth

---

## Monitoring

### Key Metrics to Track

**Azure Functions (Application Insights):**
- Execution count per function
- Average execution duration
- Error rate (4xx/5xx responses)
- Auth failures (401/403)

**Azure Blob Storage:**
- Total storage used (GB)
- Write operations per day
- Failed uploads (404/409 errors)

**Azure MySQL:**
- Active connections
- Query performance (slow query log)
- Storage growth rate
- Table row counts

### Recommended Alerts

```bash
# High error rate on FinalizeImuManifest (indicates upload failures)
az monitor metrics alert create \
  --name "IMU Finalize Errors" \
  --resource-group dojogo-rg \
  --scopes /subscriptions/.../functionapps/dojogo-api \
  --condition "count customMetrics/FinalizeImuManifest/Errors > 10" \
  --window-size 5m \
  --evaluation-frequency 1m

# MySQL storage exceeding 80%
az monitor metrics alert create \
  --name "MySQL Storage High" \
  --resource-group dojogo-rg \
  --scopes /subscriptions/.../mysqlServers/dojogo-mysql \
  --condition "avg storage_percent > 80" \
  --window-size 5m
```

### Query Performance Monitoring

```sql
-- Slow queries in last 24 hours
SELECT
    query_time,
    lock_time,
    rows_examined,
    sql_text
FROM mysql.slow_log
WHERE start_time > NOW() - INTERVAL 24 HOUR
ORDER BY query_time DESC
LIMIT 20;

-- Most active users (by session count)
SELECT
    user_id,
    COUNT(*) as session_count,
    SUM(TIMESTAMPDIFF(SECOND, start_time_utc, end_time_utc)) as total_duration_sec,
    MAX(start_time_utc) as last_session
FROM imu_sessions
WHERE start_time_utc > NOW() - INTERVAL 30 DAY
GROUP BY user_id
ORDER BY session_count DESC
LIMIT 10;

-- Storage growth over time
SELECT
    DATE(created_at) as date,
    COUNT(*) as sessions,
    SUM(bytes_size) / 1024 / 1024 as total_mb
FROM imu_session_files
WHERE created_at > NOW() - INTERVAL 30 DAY
GROUP BY DATE(created_at)
ORDER BY date;
```

---

## Troubleshooting

### Upload Fails with 403 Forbidden

**Cause:** SAS token expired (2-hour TTL)

**Solution:** Client should create new session if SAS expired:
```swift
if Date() > sasExpiryTime {
    // Re-create session with same client_upload_id (idempotent)
    let sessionResponse = try await createSession(clientUploadId: existingId, ...)
    // Use new SAS URL
}
```

### Finalize Fails with "File size mismatch"

**Cause:** Blob upload incomplete or `bytes_size` incorrect in manifest

**Solution:** Client should verify upload succeeded before finalizing:
```swift
// Check blob exists and matches expected size
let blobClient = BlobClient(url: blobURL)
let properties = try await blobClient.getProperties()
assert(properties.contentLength == localFileSize)
```

### High Database CPU Usage

**Cause:** Missing indexes on frequently queried columns

**Solution:** Add indexes:
```sql
-- Add composite index for user session queries
CREATE INDEX idx_imus_user_start
ON imu_sessions(user_id, start_time_utc DESC);

-- Add index for file lookups
CREATE INDEX idx_imuf_sess_purpose
ON imu_session_files(imu_session_id, purpose);
```

### Parquet File Unreadable

**Cause:** Corrupted upload or incorrect format

**Solution:** Validate Parquet locally before upload:
```python
import pyarrow.parquet as pq

# Validate file integrity
try:
    table = pq.read_table('raw_42.parquet')
    print(f"✅ Valid Parquet: {table.num_rows} rows, {table.num_columns} columns")

    # Verify required metadata
    metadata = table.schema.metadata
    required_keys = ['imu_session_id', 'user_id', 'start_time_utc', 'schema_version']
    for key in required_keys:
        assert key.encode() in metadata, f"Missing metadata: {key}"

except Exception as e:
    print(f"❌ Invalid Parquet: {e}")
```

---

## Security Best Practices

1. **SAS Tokens:**
   - Always set expiry (2 hours max)
   - Grant minimum permissions (write, list, read - no delete)
   - Scope to specific container path: `users/{user_id}/sessions/{session_id}/`

2. **Database:**
   - Use SSL for MySQL connections (`--ssl-mode=REQUIRED`)
   - Rotate MySQL password quarterly
   - Use least-privilege service account (no DROP/ALTER permissions)

3. **Auth0:**
   - Validate JWT signature on every request
   - Check token expiry (`exp` claim)
   - Verify audience matches API (`aud` claim)

4. **Client:**
   - Never log SAS URLs (contains credentials)
   - Delete local IMU files after successful upload
   - Encrypt sensitive device identifiers before upload

---

## Roadmap (Post-Alpha)

### Phase 2: Processing Pipeline
- Azure Function for JSONL → Parquet conversion
- Azure Data Factory for ETL (extract features from raw IMU)
- Azure Synapse Analytics for ML model training

### Phase 3: Real-Time Analytics
- Azure Stream Analytics for live strike detection
- Azure SignalR for real-time leaderboard updates
- Azure Cognitive Services for pose estimation

### Phase 4: Data Science
- Export to Azure ML Workspace
- Train custom strike classification models
- A/B test new models via feature flags

---

## Support

For issues or questions:
- Check Application Insights logs first
- Review MySQL slow query log
- Consult OpenAPI spec: `imu_api_spec.yaml`
- Test with curl examples: `IMU_TEST_EXAMPLES.md`

**Emergency Contacts:**
- Database: Azure MySQL support
- Blob Storage: Azure Storage support
- Functions: Azure Functions support
