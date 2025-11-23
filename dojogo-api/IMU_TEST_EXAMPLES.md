# IMU API Test Examples

Complete workflow examples for testing the IMU data capture endpoints.

## Prerequisites

```bash
# Set your Auth0 bearer token
export TOKEN="your_jwt_token_here"
export API_BASE="https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net"

# Generate a unique client upload ID for idempotency testing
export CLIENT_UPLOAD_ID=$(uuidgen)
echo "Using client_upload_id: $CLIENT_UPLOAD_ID"
```

## 1. Create IMU Session (First Call)

```bash
curl -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$CLIENT_UPLOAD_ID'",
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
    "notes": "Practice session - men strikes"
  }' | jq .
```

**Expected Response (201 Created):**
```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "device_id": 7,
  "start_time_utc": "2025-01-20T10:30:00.123456Z",
  "nominal_hz": 100.0,
  "coord_frame": "device",
  "sas_token": {
    "container": "imu-alpha",
    "path": "users/auth0|abc123/sessions/42/",
    "sas_url": "https://dojogostore.blob.core.windows.net/imu-alpha/users/auth0%7Cabc123/sessions/42/?se=2025-01-20T12:30:00Z&sp=rwl&...",
    "expires_at": "2025-01-20T12:30:00.000000Z"
  }
}
```

## 2. Create IMU Session (Duplicate Call - Idempotency Test)

```bash
# Same request with same client_upload_id - should return existing session
curl -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$CLIENT_UPLOAD_ID'",
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
    "notes": "Practice session - men strikes"
  }' | jq .
```

**Expected Response (200 OK - same data as above):**
- Status code changes from 201 to 200
- Returns identical `imu_session_id` (42)
- Fresh SAS token generated

## 3. Upload Files to Blob Storage

Save the `sas_url` from the response above and upload your files:

```bash
export SAS_URL="paste_sas_url_here"
export IMU_SESSION_ID=42

# Upload raw Parquet file
curl -X PUT "${SAS_URL}raw_${IMU_SESSION_ID}.parquet" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @raw_${IMU_SESSION_ID}.parquet

# Upload manifest
curl -X PUT "${SAS_URL}manifest_${IMU_SESSION_ID}.json" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @manifest_${IMU_SESSION_ID}.json

# Upload device snapshot
curl -X PUT "${SAS_URL}device_${IMU_SESSION_ID}.json" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @device_${IMU_SESSION_ID}.json

# Upload calibration
curl -X PUT "${SAS_URL}calib_${IMU_SESSION_ID}.json" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @calib_${IMU_SESSION_ID}.json

# Upload events
curl -X PUT "${SAS_URL}events_${IMU_SESSION_ID}.jsonl" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @events_${IMU_SESSION_ID}.jsonl
```

## 4. Finalize Manifest

```bash
curl -X POST "$API_BASE/api/v1/imu/sessions/42/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "2025-01-20T10:45:23.987654Z",
    "files": [
      {
        "purpose": "raw",
        "filename": "raw_42.parquet",
        "content_type": "application/octet-stream",
        "bytes_size": 1234567,
        "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
        "num_samples": 92345
      },
      {
        "purpose": "manifest",
        "filename": "manifest_42.json",
        "content_type": "application/json",
        "bytes_size": 512,
        "sha256_hex": "b2c3d4e5f67890a1bcdef234567890a1bcdef234567890a1bcdef234567890a1"
      },
      {
        "purpose": "device",
        "filename": "device_42.json",
        "content_type": "application/json",
        "bytes_size": 256,
        "sha256_hex": "c3d4e5f67890a1b2cdef34567890a1b2cdef34567890a1b2cdef34567890a1b2"
      },
      {
        "purpose": "calib",
        "filename": "calib_42.json",
        "content_type": "application/json",
        "bytes_size": 384,
        "sha256_hex": "d4e5f67890a1b2c3def4567890a1b2c3def4567890a1b2c3def4567890a1b2c3"
      },
      {
        "purpose": "events",
        "filename": "events_42.jsonl",
        "content_type": "application/x-ndjson",
        "bytes_size": 1024,
        "sha256_hex": "e5f67890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4"
      }
    ]
  }' | jq .
```

**Expected Response (200 OK):**
```json
{
  "message": "Manifest finalized successfully",
  "imu_session_id": 42,
  "total_files": 5,
  "total_bytes": 1236743,
  "total_samples": 92345,
  "end_time_utc": "2025-01-20T10:45:23.987654Z"
}
```

## 5. Finalize Manifest (Duplicate Call - Idempotency Test)

```bash
# Same finalize request - should return success without re-inserting
curl -X POST "$API_BASE/api/v1/imu/sessions/42/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "2025-01-20T10:45:23.987654Z",
    "files": [
      {
        "purpose": "raw",
        "filename": "raw_42.parquet",
        "content_type": "application/octet-stream",
        "bytes_size": 1234567,
        "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
        "num_samples": 92345
      }
    ]
  }' | jq .
```

**Expected Response (200 OK):**
```json
{
  "message": "Manifest already finalized (idempotent)",
  "imu_session_id": 42,
  "total_files": 5,
  "total_bytes": 1236743,
  "total_samples": 92345,
  "end_time_utc": "2025-01-20T10:45:23.987654Z"
}
```

## 6. Get Single Session Details

```bash
curl -X GET "$API_BASE/api/v1/imu/sessions/42" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

**Expected Response (200 OK):**
```json
{
  "imu_session_id": 42,
  "user_id": "auth0|abc123",
  "device_id": 7,
  "start_time_utc": "2025-01-20T10:30:00.123456Z",
  "end_time_utc": "2025-01-20T10:45:23.987654Z",
  "nominal_hz": 100.0,
  "coord_frame": "device",
  "gravity_removed": false,
  "notes": "Practice session - men strikes",
  "created_at": "2025-01-20T10:29:45.000000Z",
  "device": {
    "platform": "ios",
    "model": "iPhone 14 Pro",
    "os_version": "17.2.1"
  },
  "files": [
    {
      "file_id": 101,
      "purpose": "calib",
      "storage_url": "users/auth0|abc123/sessions/42/calib_42.json",
      "content_type": "application/json",
      "bytes_size": 384,
      "sha256_hex": "d4e5f67890a1b2c3def4567890a1b2c3def4567890a1b2c3def4567890a1b2c3",
      "num_samples": null,
      "created_at": "2025-01-20T10:45:25.000000Z"
    },
    {
      "file_id": 102,
      "purpose": "device",
      "storage_url": "users/auth0|abc123/sessions/42/device_42.json",
      "content_type": "application/json",
      "bytes_size": 256,
      "sha256_hex": "c3d4e5f67890a1b2cdef34567890a1b2cdef34567890a1b2cdef34567890a1b2",
      "num_samples": null,
      "created_at": "2025-01-20T10:45:25.000000Z"
    },
    {
      "file_id": 103,
      "purpose": "events",
      "storage_url": "users/auth0|abc123/sessions/42/events_42.jsonl",
      "content_type": "application/x-ndjson",
      "bytes_size": 1024,
      "sha256_hex": "e5f67890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4ef567890a1b2c3d4",
      "num_samples": null,
      "created_at": "2025-01-20T10:45:25.000000Z"
    },
    {
      "file_id": 104,
      "purpose": "manifest",
      "storage_url": "users/auth0|abc123/sessions/42/manifest_42.json",
      "content_type": "application/json",
      "bytes_size": 512,
      "sha256_hex": "b2c3d4e5f67890a1bcdef234567890a1bcdef234567890a1bcdef234567890a1",
      "num_samples": null,
      "created_at": "2025-01-20T10:45:25.000000Z"
    },
    {
      "file_id": 105,
      "purpose": "raw",
      "storage_url": "users/auth0|abc123/sessions/42/raw_42.parquet",
      "content_type": "application/octet-stream",
      "bytes_size": 1234567,
      "sha256_hex": "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
      "num_samples": 92345,
      "created_at": "2025-01-20T10:45:25.000000Z"
    }
  ]
}
```

## 7. List User Sessions

```bash
# List with default pagination
curl -X GET "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" | jq .

# List with custom pagination
curl -X GET "$API_BASE/api/v1/imu/sessions?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

**Expected Response (200 OK):**
```json
{
  "sessions": [
    {
      "imu_session_id": 42,
      "user_id": "auth0|abc123",
      "device_id": 7,
      "start_time_utc": "2025-01-20T10:30:00.123456Z",
      "end_time_utc": "2025-01-20T10:45:23.987654Z",
      "nominal_hz": 100.0,
      "coord_frame": "device",
      "created_at": "2025-01-20T10:29:45.000000Z",
      "device": {
        "platform": "ios",
        "model": "iPhone 14 Pro"
      }
    },
    {
      "imu_session_id": 38,
      "user_id": "auth0|abc123",
      "device_id": 7,
      "start_time_utc": "2025-01-19T15:20:00.000000Z",
      "end_time_utc": "2025-01-19T15:35:10.123456Z",
      "nominal_hz": 100.0,
      "coord_frame": "device",
      "created_at": "2025-01-19T15:19:30.000000Z",
      "device": {
        "platform": "ios",
        "model": "iPhone 14 Pro"
      }
    }
  ],
  "total": 2,
  "limit": 50,
  "offset": 0
}
```

## Error Cases

### Unauthorized (Missing/Invalid Token)
```bash
curl -X GET "$API_BASE/api/v1/imu/sessions/42" | jq .
```
**Response (401):**
```json
{
  "error": "Unauthorized: Missing or invalid token"
}
```

### Session Not Found
```bash
curl -X GET "$API_BASE/api/v1/imu/sessions/99999" \
  -H "Authorization: Bearer $TOKEN" | jq .
```
**Response (404):**
```json
{
  "error": "IMU session not found"
}
```

### File Size Mismatch on Finalize
```bash
# Claimed bytes_size doesn't match actual blob size
curl -X POST "$API_BASE/api/v1/imu/sessions/42/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "2025-01-20T10:45:23.987654Z",
    "files": [
      {
        "purpose": "raw",
        "filename": "raw_42.parquet",
        "bytes_size": 999999999
      }
    ]
  }' | jq .
```
**Response (400):**
```json
{
  "error": "File size mismatch for raw_42.parquet: claimed 999999999, actual 1234567"
}
```

### Missing Files in Blob Storage
```bash
curl -X POST "$API_BASE/api/v1/imu/sessions/42/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "2025-01-20T10:45:23.987654Z",
    "files": [
      {
        "purpose": "raw",
        "filename": "nonexistent.parquet",
        "bytes_size": 1000
      }
    ]
  }' | jq .
```
**Response (400):**
```json
{
  "error": "Some files not found in blob storage",
  "missing_files": ["nonexistent.parquet"]
}
```

## SHA-256 Checksum Generation

Generate checksums for your files before upload:

```bash
# macOS/Linux
shasum -a 256 raw_42.parquet
shasum -a 256 manifest_42.json
shasum -a 256 device_42.json
shasum -a 256 calib_42.json
shasum -a 256 events_42.jsonl

# Or using openssl
openssl dgst -sha256 raw_42.parquet
```
