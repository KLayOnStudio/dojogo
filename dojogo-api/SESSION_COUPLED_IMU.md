# Session-Coupled IMU Recording

## Overview

IMU sensor recording is synchronized with tap-game sessions. The tap-game session lifecycle controls when IMU recording starts and stops, creating a tight coupling between gameplay and motion data capture.

**Key Principle:** The tap-game session is the **source of truth** for recording lifecycle.

---

## States and Transitions

```
┌──────┐  onGameStart   ┌───────────┐  onGameEnd   ┌────────────┐
│ Idle │ ───────────────▶ Recording │ ─────────────▶ Finalizing │
└──────┘                 └───────────┘              └────────────┘
                              │                           │
                              │ app crash                 │
                              ▼                           ▼
                         ┌──────────┐               ┌────────────┐
                         │  Resume  │◀──────────────│ Uploading  │
                         └──────────┘  on relaunch  └────────────┘
                                                          │
                                                          ▼
                                                      ┌──────┐
                                                      │ Done │
                                                      └──────┘
```

### State Descriptions

| State | Description | Client Actions |
|-------|-------------|----------------|
| **Idle** | No active session | Sensors stopped, no buffers |
| **Recording** | Game running, sensors active | Buffer samples, write Parquet parts |
| **Finalizing** | Game ended, preparing upload | Stop sensors, flush final part |
| **Uploading** | Sending data to blob storage | Upload parts, compute checksums |
| **Done** | Manifest finalized | Delete local files, free memory |
| **Resume** | Crashed during recording | Detect orphaned parts, finalize or discard |

---

## Client Event Flow

### 1. Start (when tap-game session begins)

**Trigger:** User taps "Hajime" to start game

**Client Actions:**
```swift
func onGameSessionStart() {
    // Step 1: Create or fetch tap-game session ID (existing system)
    let gameSessionId = startGameSession() // Returns UUID from sessions table

    // Step 2: Generate unique client_upload_id for idempotency
    let clientUploadId = UUID()

    // Step 3: Call POST /v1/imu/sessions
    let request = CreateImuSessionRequest(
        clientUploadId: clientUploadId,
        deviceInfo: DeviceInfo.current(),
        startTimeUtc: Date(),
        nominalHz: 100.0,
        coordFrame: "device",
        gameSessionId: gameSessionId, // Link to tap-game
        notes: "Alpha tap-game session"
    )

    let response = try await APIService.shared.createImuSession(request)

    // Step 4: Store session info
    self.imuSessionId = response.imuSessionId
    self.sasURL = response.sasToken.sasURL
    self.sasExpiry = response.sasToken.expiresAt

    // Step 5: Start IMU sensors at native rate (100-200Hz)
    startSensors()

    // Step 6: Begin buffering and writing parts
    startPartWriter()
}
```

**API Call:**
```bash
POST /v1/imu/sessions
{
  "client_upload_id": "550e8400-e29b-41d4-a716-446655440000",
  "device_info": {
    "platform": "ios",
    "model": "iPhone 14 Pro",
    "os_version": "17.2.1",
    "app_version": "1.0.0-alpha.3",
    "hw_id": "A1B2C3D4-E5F6-G7H8-I9J0-K1L2M3N4O5P6"
  },
  "start_time_utc": "2025-01-20T10:30:00.123456Z",
  "nominal_hz": 100.0,
  "coord_frame": "device",
  "game_session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "notes": "Alpha tap-game session"
}
```

**Server Response:**
```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "device_id": 7,
  "start_time_utc": "2025-01-20T10:30:00.123456Z",
  "nominal_hz": 100.0,
  "coord_frame": "device",
  "game_session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "sas_token": {
    "container": "imu-alpha",
    "path": "users/auth0|abc123/sessions/42/",
    "sas_url": "https://dojogostore.blob.core.windows.net/imu-alpha/users/auth0%7Cabc123/sessions/42/?se=2025-01-20T12:30:00Z&sp=rwl&...",
    "expires_at": "2025-01-20T12:30:00.000000Z"
  }
}
```

---

### 2. During Recording

**Alpha Policy:** Keep all data on device; do not upload until game ends.

**Part File Management:**

```swift
class IMUPartWriter {
    private var currentPart: Int = 0
    private var buffer: [IMUSample] = []
    private let partSizeThreshold = 100_000 // ~100MB at 100Hz

    func bufferSample(_ sample: IMUSample) {
        buffer.append(sample)

        // Check if part threshold reached
        if buffer.count >= partSizeThreshold {
            writeParquetPart()
        }
    }

    func writeParquetPart() {
        let filename = "raw_\(imuSessionId)_\(String(format: "%04d", currentPart)).parquet"
        let localURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)

        // Write Parquet (or JSONL for alpha, convert server-side later)
        try writeParquet(samples: buffer, to: localURL)

        // Track part for later upload
        pendingParts.append(PartInfo(
            filename: filename,
            localURL: localURL,
            numSamples: buffer.count
        ))

        // Clear buffer and increment part counter
        buffer.removeAll(keepingCapacity: true)
        currentPart += 1

        print("📦 Wrote part \(currentPart): \(filename)")
    }
}
```

**Part Naming Convention:**
- `raw_{imu_session_id}_0000.parquet` (first part)
- `raw_{imu_session_id}_0001.parquet` (second part)
- `raw_{imu_session_id}_0002.parquet` (third part)
- etc.

**Rotation Policy:**
- **Time-based:** Every 60-120 seconds
- **Size-based:** Every ~100MB (uncompressed)
- **Sample-based:** Every 10,000-100,000 samples (at 100Hz = 100-1000 seconds)

---

### 3. Stop (when tap-game session ends)

**Trigger:** Game session completes (timer expires, user quits)

**Client Actions:**
```swift
func onGameSessionEnd() {
    // Step 1: Stop sensors
    stopSensors()

    // Step 2: Flush final part (if buffer not empty)
    if !buffer.isEmpty {
        writeParquetPart()
    }

    // Step 3: Write sidecar files
    writeSidecarFiles()

    // Step 4: Upload all parts to blob storage
    try await uploadAllParts()

    // Step 5: Finalize manifest
    try await finalizeManifest()

    // Step 6: Clean up local files
    deleteLocalParts()
}

func uploadAllParts() async throws {
    for part in pendingParts {
        let blobURL = sasURL.appendingPathComponent(part.filename)

        var request = URLRequest(url: blobURL)
        request.httpMethod = "PUT"
        request.setValue("BlockBlob", forHTTPHeaderField: "x-ms-blob-type")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: part.localURL)

        guard (response as? HTTPURLResponse)?.statusCode == 201 else {
            throw IMUError.uploadFailed
        }

        print("✅ Uploaded \(part.filename)")
    }

    // Also upload sidecar files
    try await uploadSidecarFiles()
}

func finalizeManifest() async throws {
    let files = pendingParts.map { part in
        FileManifestEntry(
            filename: part.filename,
            purpose: "raw",
            contentType: "application/octet-stream",
            bytesSize: part.fileSize,
            sha256Hex: part.checksum,
            numSamples: part.numSamples
        )
    }

    // Add sidecar files to manifest
    files.append(contentsOf: sidecarFiles)

    let request = FinalizeManifestRequest(
        endTimeUtc: Date(),
        files: files
    )

    let response = try await APIService.shared.finalizeManifest(
        imuSessionId: imuSessionId,
        request: request
    )

    print("✅ Manifest finalized: \(response.totalFiles) files, \(response.totalBytes) bytes")
}
```

**API Call:**
```bash
POST /v1/imu/sessions/42/manifest
{
  "end_time_utc": "2025-01-20T10:45:23.987654Z",
  "files": [
    {
      "filename": "raw_42_0000.parquet",
      "purpose": "raw",
      "content_type": "application/octet-stream",
      "bytes_size": 1234567,
      "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
      "num_samples": 50000
    },
    {
      "filename": "raw_42_0001.parquet",
      "purpose": "raw",
      "content_type": "application/octet-stream",
      "bytes_size": 987654,
      "sha256_hex": "b2c3d4e5f67890a1bcdef234567890a1bcdef234567890a1bcdef234567890a1",
      "num_samples": 42345
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
      "filename": "manifest_42.json",
      "purpose": "manifest",
      "content_type": "application/json",
      "bytes_size": 512,
      "sha256_hex": "e5f67890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4"
    }
  ]
}
```

---

### 4. Crash / Abort Handling

**Scenario:** App crashes mid-game or user force-quits

**Detection:** On next app launch

```swift
func detectOrphanedSessions() {
    // Check for local part files
    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let orphanedParts = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "parquet" && $0.lastPathComponent.hasPrefix("raw_") }

    if !orphanedParts.isEmpty {
        print("⚠️ Found \(orphanedParts.count) orphaned IMU parts")

        // Option 1: Resume upload (if network available)
        Task {
            try await resumeOrphanedUploads(parts: orphanedParts)
        }

        // Option 2: Discard (if too old or corrupted)
        // deleteOrphanedParts(parts: orphanedParts)
    }
}

func resumeOrphanedUploads(parts: [URL]) async throws {
    // Extract imu_session_id from filename (e.g., "raw_42_0000.parquet" → 42)
    guard let firstPart = parts.first,
          let imuSessionId = extractSessionId(from: firstPart) else {
        return
    }

    // Re-create session with same client_upload_id (idempotent)
    // This returns existing SAS token if session already exists
    let response = try await APIService.shared.createImuSession(
        clientUploadId: storedClientUploadId,
        // ... other params
    )

    // Upload orphaned parts
    for partURL in parts {
        try await uploadPart(partURL, to: response.sasToken.sasURL)
    }

    // Finalize manifest
    try await finalizeManifest(imuSessionId: imuSessionId)

    // Clean up
    for partURL in parts {
        try FileManager.default.removeItem(at: partURL)
    }
}
```

**Network Offline Handling:**

```swift
func handleOfflineUpload() {
    // Queue uploads for retry
    let queue = UploadQueue.shared
    queue.enqueue(imuSessionId: imuSessionId, parts: pendingParts)

    // Set up network observer
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { path in
        if path.status == .satisfied {
            print("📡 Network online - resuming uploads")
            Task {
                try await queue.processQueue()
            }
        }
    }
    monitor.start(queue: DispatchQueue.global(qos: .background))
}
```

**Exponential Backoff:**
```swift
func retryUpload(attempt: Int = 0) async throws {
    let maxAttempts = 5
    let baseDelay: TimeInterval = 2.0

    do {
        try await uploadPart()
    } catch {
        guard attempt < maxAttempts else {
            throw IMUError.uploadFailedAfterRetries
        }

        let delay = baseDelay * pow(2.0, Double(attempt)) // 2s, 4s, 8s, 16s, 32s
        print("⏳ Retry attempt \(attempt + 1) in \(delay)s")

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        try await retryUpload(attempt: attempt + 1)
    }
}
```

---

## Foreground vs Background

**Alpha Policy:** Record only while app is in **foreground**.

**Reason:** Avoid iOS background execution limits and battery drain.

**Behavior:**
- `applicationWillResignActive`: Pause sensors, flush current part
- `applicationDidBecomeActive`: Resume sensors (if game still active), continue same `imu_session_id`

**Future (GA):** Use iOS Background Modes for continuous recording:
- Background Processing
- Location Updates (if GPS fusion needed)

---

## Database Queries (Server-Side)

### Find IMU data for a specific game session

```sql
SELECT
    ims.imu_session_id,
    ims.start_time_utc,
    ims.end_time_utc,
    ims.nominal_hz,
    COUNT(isf.file_id) as total_files,
    SUM(isf.bytes_size) as total_bytes,
    SUM(isf.num_samples) as total_samples
FROM imu_sessions ims
LEFT JOIN imu_session_files isf ON ims.imu_session_id = isf.imu_session_id
WHERE ims.game_session_id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
GROUP BY ims.imu_session_id;
```

### Find game sessions WITH IMU data

```sql
SELECT
    s.id as game_session_id,
    s.user_id,
    s.start_time,
    s.score,
    ims.imu_session_id,
    ims.start_time_utc as imu_start,
    ims.end_time_utc as imu_end,
    COUNT(isf.file_id) as imu_files
FROM sessions s
INNER JOIN imu_sessions ims ON s.id = ims.game_session_id
LEFT JOIN imu_session_files isf ON ims.imu_session_id = isf.imu_session_id
WHERE s.user_id = 'auth0|abc123'
GROUP BY s.id, ims.imu_session_id
ORDER BY s.start_time DESC;
```

### Find game sessions WITHOUT IMU data

```sql
SELECT
    s.id as game_session_id,
    s.user_id,
    s.start_time,
    s.score
FROM sessions s
LEFT JOIN imu_sessions ims ON s.id = ims.game_session_id
WHERE s.user_id = 'auth0|abc123'
  AND ims.imu_session_id IS NULL
ORDER BY s.start_time DESC;
```

### Find orphaned IMU sessions (no game link)

```sql
SELECT
    ims.imu_session_id,
    ims.user_id,
    ims.start_time_utc,
    ims.end_time_utc,
    COUNT(isf.file_id) as total_files
FROM imu_sessions ims
LEFT JOIN imu_session_files isf ON ims.imu_session_id = isf.imu_session_id
WHERE ims.game_session_id IS NULL
GROUP BY ims.imu_session_id
ORDER BY ims.start_time_utc DESC;
```

---

## Testing Checklist

- [ ] Create IMU session with `game_session_id` link
- [ ] Create IMU session without `game_session_id` (standalone)
- [ ] Upload multi-part Parquet files (3+ parts)
- [ ] Finalize manifest with all parts
- [ ] Query game sessions with linked IMU data
- [ ] Simulate crash: orphaned parts detected and uploaded on relaunch
- [ ] Simulate offline: uploads queued and retried when network returns
- [ ] Verify foreign key constraint: deleting game session sets `imu_sessions.game_session_id` to NULL

---

## API Changes Summary

### POST /v1/imu/sessions

**New Field (Optional):**
- `game_session_id` (string, UUID format)

**Behavior:**
- If provided, links IMU session to tap-game session
- Foreign key enforced: `game_session_id` must exist in `sessions` table (or NULL)
- If game session deleted, IMU session remains but link set to NULL

### POST /v1/imu/sessions/{id}/manifest

**No changes** - already supports multi-part files via `files[]` array

### GET /v1/imu/sessions/{id}

**New Field in Response:**
- `game_session_id` (string, UUID, nullable)

### GET /v1/imu/sessions

**New Field in Response:**
- Each session includes `game_session_id` (string, UUID, nullable)

---

## Migration Steps

1. **Run database migration:**
   ```bash
   mysql -h dojogo-mysql.mysql.database.azure.com \
     -u dojogo_admin -p -D dojogo_db --ssl-mode=REQUIRED \
     < database_migration_session_coupled_imu.sql
   ```

2. **Deploy updated Azure Functions:**
   ```bash
   cd dojogo-api
   func azure functionapp publish dojogo-api
   ```

3. **Test with curl:**
   ```bash
   # Create session with game link
   curl -X POST "$API_BASE/api/v1/imu/sessions" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "client_upload_id": "'$(uuidgen)'",
       "device_info": {"platform": "ios", "model": "iPhone 14 Pro"},
       "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
       "nominal_hz": 100.0,
       "game_session_id": "existing-game-session-uuid"
     }'
   ```

4. **Update iOS client** to pass `game_session_id` when creating IMU sessions

5. **Verify in database:**
   ```sql
   SELECT * FROM imu_sessions WHERE game_session_id IS NOT NULL LIMIT 5;
   ```
