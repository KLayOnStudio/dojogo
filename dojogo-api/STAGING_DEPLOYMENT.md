# IMU System - Staging Deployment Guide

## ⚠️ IMPORTANT: Manual Steps Required

This deployment requires MySQL credentials that are not accessible via Azure CLI. Follow these steps in order.

---

## Environment Details

- **MySQL Server:** dojogo-mysql-us-west2.mysql.database.azure.com
- **MySQL Database:** dojogo
- **MySQL User:** dojogo_admin (confirm with user)
- **Function App:** dojogo-api
- **Resource Group:** dojogo-rg
- **Region:** West US 2

---

## Step 1: Run MySQL Migrations

### Option A: Using MySQL Client (Recommended)

```bash
cd /Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api

# Connect to MySQL
mysql -h dojogo-mysql-us-west2.mysql.database.azure.com \
  -u dojogo_admin \
  -p \
  -D dojogo \
  --ssl-mode=REQUIRED

# Once connected, run migrations in order:
mysql> source database_migration_imu_phase1.sql;
mysql> source database_migration_session_coupled_imu.sql;
mysql> source database_migration_rate_stats.sql;

# Verify tables created
mysql> SHOW TABLES LIKE '%imu%';
mysql> SHOW TABLES LIKE 'devices';

# Check foreign keys
mysql> SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'dojogo'
  AND REFERENCED_TABLE_NAME IS NOT NULL
  AND (TABLE_NAME LIKE 'imu_%' OR TABLE_NAME = 'devices');
```

### Option B: Using Azure Cloud Shell

```bash
# Upload migration files to Cloud Shell first
# Then run:
mysql -h dojogo-mysql-us-west2.mysql.database.azure.com \
  -u dojogo_admin \
  -p \
  -D dojogo \
  --ssl-mode=REQUIRED \
  < database_migration_imu_phase1.sql

mysql -h dojogo-mysql-us-west2.mysql.database.azure.com \
  -u dojogo_admin \
  -p \
  -D dojogo \
  --ssl-mode=REQUIRED \
  < database_migration_session_coupled_imu.sql

mysql -h dojogo-mysql-us-west2.mysql.database.azure.com \
  -u dojogo_admin \
  -p \
  -D dojogo \
  --ssl-mode=REQUIRED \
  < database_migration_rate_stats.sql
```

### Expected Tables After Migration

- `devices` - Device registry (new)
- `imu_sessions` - IMU capture sessions (new, with game_session_id and actual_mean_hz columns)
- `imu_session_files` - File references (new)
- `imu_client_uploads` - Idempotency ledger (new)
- `imu_session_stats` - Rate statistics (new)

---

## Step 2: Create Azure Blob Container

```bash
# Check if container exists
az storage container list \
  --account-name dojogostore \
  --auth-mode login \
  --query "[?name=='imu-alpha']"

# Create container if missing
az storage container create \
  --name imu-alpha \
  --account-name dojogostore \
  --public-access off \
  --auth-mode login

# Verify creation
az storage container show \
  --name imu-alpha \
  --account-name dojogostore \
  --auth-mode login
```

---

## Step 3: Verify Function App Settings

```bash
# Check existing settings
az functionapp config appsettings list \
  --name dojogo-api \
  --resource-group dojogo-rg \
  --query "[?name=='MYSQL_HOST' || name=='MYSQL_DATABASE' || name=='MYSQL_USER' || name=='AZURE_STORAGE_CONNECTION_STRING'].{name:name,value:value}" \
  --output table

# If any settings are missing, add them:

# MYSQL_HOST
az functionapp config appsettings set \
  --name dojogo-api \
  --resource-group dojogo-rg \
  --settings MYSQL_HOST=dojogo-mysql-us-west2.mysql.database.azure.com

# MYSQL_DATABASE
az functionapp config appsettings set \
  --name dojogo-api \
  --resource-group dojogo-rg \
  --settings MYSQL_DATABASE=dojogo

# MYSQL_USER
az functionapp config appsettings set \
  --name dojogo-api \
  --resource-group dojogo-rg \
  --settings MYSQL_USER=dojogo_admin

# MYSQL_PASSWORD (REQUIRED - get from Azure Key Vault or user)
az functionapp config appsettings set \
  --name dojogo-api \
  --resource-group dojogo-rg \
  --settings MYSQL_PASSWORD="<password_here>"

# AZURE_STORAGE_CONNECTION_STRING (get from storage account)
STORAGE_CONN_STRING=$(az storage account show-connection-string \
  --name dojogostore \
  --resource-group dojogo-rg \
  --query connectionString \
  --output tsv)

az functionapp config appsettings set \
  --name dojogo-api \
  --resource-group dojogo-rg \
  --settings AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONN_STRING"
```

---

## Step 4: Deploy Azure Functions

```bash
cd /Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api

# Verify function directories exist
ls -la CreateImuSession/ FinalizeImuManifest/ GetImuSession/

# Deploy to Azure
func azure functionapp publish dojogo-api

# Verify deployment
func azure functionapp list-functions dojogo-api

# Expected output should include:
# - CreateImuSession
# - FinalizeImuManifest
# - GetImuSession
```

---

## Step 5: Run Smoke Tests

### Setup Test Environment

```bash
# Get Auth0 token (user must provide or generate)
export TOKEN="your_jwt_token_here"
export API_BASE="https://dojogo-api.azurewebsites.net"

# Generate test UUID
export CLIENT_UPLOAD_ID=$(uuidgen)
echo "Using client_upload_id: $CLIENT_UPLOAD_ID"
```

### Test 1: Create IMU Session (Idempotent)

```bash
# First call - should return 201 Created
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
      "hw_id": "TEST-DEVICE-001"
    },
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0,
    "coord_frame": "device",
    "game_session_id": null,
    "notes": "Smoke test session"
  }' | jq .

# Save imu_session_id and sas_url from response
export IMU_SESSION_ID=<from_response>
export SAS_URL="<from_response>"

# Second call - should return 200 OK (idempotent)
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
      "hw_id": "TEST-DEVICE-001"
    },
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0
  }' | jq .
```

### Test 2: Upload Sample Files to Blob

```bash
# Create tiny sample files
cat > /tmp/raw_${IMU_SESSION_ID}_0000.jsonl << 'EOF'
{"ts_ns":1737371400000000000,"ax":0.15,"ay":9.81,"az":0.02,"gx":0.001,"gy":-0.001,"gz":0.150}
{"ts_ns":1737371400010000000,"ax":0.18,"ay":9.83,"az":0.01,"gx":0.002,"gy":0.000,"gz":0.148}
{"ts_ns":1737371400020000000,"ax":0.12,"ay":9.80,"az":0.03,"gx":0.000,"gy":0.001,"gz":0.152}
EOF

cat > /tmp/device_${IMU_SESSION_ID}.json << 'EOF'
{
  "imu_session_id": 0,
  "platform": "ios",
  "model": "iPhone 14 Pro"
}
EOF

cat > /tmp/calib_${IMU_SESSION_ID}.json << 'EOF'
{
  "imu_session_id": 0,
  "calibration_source": "uncalibrated"
}
EOF

# Upload to blob storage
curl -X PUT "${SAS_URL}raw_${IMU_SESSION_ID}_0000.jsonl" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @/tmp/raw_${IMU_SESSION_ID}_0000.jsonl

curl -X PUT "${SAS_URL}device_${IMU_SESSION_ID}.json" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/device_${IMU_SESSION_ID}.json

curl -X PUT "${SAS_URL}calib_${IMU_SESSION_ID}.json" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/calib_${IMU_SESSION_ID}.json

# Compute checksums
export RAW_CHECKSUM=$(shasum -a 256 /tmp/raw_${IMU_SESSION_ID}_0000.jsonl | awk '{print $1}')
export DEVICE_CHECKSUM=$(shasum -a 256 /tmp/device_${IMU_SESSION_ID}.json | awk '{print $1}')
export CALIB_CHECKSUM=$(shasum -a 256 /tmp/calib_${IMU_SESSION_ID}.json | awk '{print $1}')
export RAW_SIZE=$(stat -f%z /tmp/raw_${IMU_SESSION_ID}_0000.jsonl)
export DEVICE_SIZE=$(stat -f%z /tmp/device_${IMU_SESSION_ID}.json)
export CALIB_SIZE=$(stat -f%z /tmp/calib_${IMU_SESSION_ID}.json)
```

### Test 3: Finalize Manifest (WITH rate_stats)

```bash
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
        "bytes_size": '$RAW_SIZE',
        "sha256_hex": "'$RAW_CHECKSUM'",
        "num_samples": 3
      },
      {
        "filename": "device_'$IMU_SESSION_ID'.json",
        "purpose": "device",
        "content_type": "application/json",
        "bytes_size": '$DEVICE_SIZE',
        "sha256_hex": "'$DEVICE_CHECKSUM'"
      },
      {
        "filename": "calib_'$IMU_SESSION_ID'.json",
        "purpose": "calib",
        "content_type": "application/json",
        "bytes_size": '$CALIB_SIZE',
        "sha256_hex": "'$CALIB_CHECKSUM'"
      }
    ],
    "rate_stats": {
      "samples_total": 3,
      "duration_ms": 20.0,
      "mean_hz": 100.0,
      "dt_ms_p50": 10.0,
      "dt_ms_p95": 10.0,
      "dt_ms_max": 10.0
    }
  }' | jq .
```

### Test 4: Finalize Manifest (WITHOUT rate_stats - backward compatibility)

```bash
# Create another session
export CLIENT_UPLOAD_ID_2=$(uuidgen)

curl -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$CLIENT_UPLOAD_ID_2'",
    "device_info": {
      "platform": "ios",
      "model": "iPhone 14 Pro",
      "hw_id": "TEST-DEVICE-001"
    },
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0
  }' | jq -r '.imu_session_id' > /tmp/imu_session_id_2.txt

export IMU_SESSION_ID_2=$(cat /tmp/imu_session_id_2.txt)

# Finalize without rate_stats (older app build simulation)
curl -X POST "$API_BASE/api/v1/imu/sessions/$IMU_SESSION_ID_2/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "files": []
  }' | jq .
```

### Test 5: GET Session Details

```bash
# Get single session
curl -X GET "$API_BASE/api/v1/imu/sessions/$IMU_SESSION_ID" \
  -H "Authorization: Bearer $TOKEN" | jq .

# List all sessions
curl -X GET "$API_BASE/api/v1/imu/sessions?limit=10" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

## Expected Test Results

### ✅ Success Criteria

1. **Create Session:**
   - First call returns `201 Created`
   - Second call (same UUID) returns `200 OK` with same `imu_session_id`
   - Response includes `sas_token` with 2-hour expiry

2. **Upload Files:**
   - All blob uploads return `201 Created`
   - Files visible in Azure Portal under `imu-alpha` container

3. **Finalize WITH rate_stats:**
   - Returns `200 OK`
   - `total_files` = 3
   - Database shows `actual_mean_hz` = 100.0
   - `imu_session_stats` table has row with P50/P95/max metrics

4. **Finalize WITHOUT rate_stats:**
   - Returns `200 OK` (backward compatible)
   - `actual_mean_hz` remains NULL
   - No error thrown

5. **GET Endpoints:**
   - Single session returns full details with `files[]` array
   - List sessions returns paginated results
   - Both include `game_session_id` field (nullable)

### ❌ Failure Indicators

- 401 Unauthorized: Invalid Auth0 token
- 403 Forbidden: SAS token expired or invalid
- 404 Not Found: Session doesn't exist
- 500 Internal Server Error: Database connection issues or missing settings

---

## Verification Queries

After smoke tests, verify database state:

```sql
-- Check sessions created
SELECT
    imu_session_id,
    user_id,
    nominal_hz,
    actual_mean_hz,
    game_session_id,
    start_time_utc,
    end_time_utc
FROM imu_sessions
ORDER BY created_at DESC
LIMIT 5;

-- Check rate stats
SELECT
    ims.imu_session_id,
    ims.actual_mean_hz,
    iss.samples_total,
    iss.mean_hz,
    iss.dt_ms_p50,
    iss.dt_ms_p95
FROM imu_sessions ims
LEFT JOIN imu_session_stats iss ON ims.imu_session_id = iss.imu_session_id
ORDER BY ims.created_at DESC
LIMIT 5;

-- Check files registered
SELECT
    isf.imu_session_id,
    isf.purpose,
    isf.storage_url,
    isf.bytes_size,
    isf.num_samples
FROM imu_session_files isf
ORDER BY isf.created_at DESC
LIMIT 10;

-- Check devices
SELECT * FROM devices ORDER BY created_at DESC LIMIT 5;
```

---

## Rollback Plan

If deployment fails:

```sql
-- Rollback rate_stats
DROP TABLE IF EXISTS imu_session_stats;
ALTER TABLE imu_sessions DROP COLUMN actual_mean_hz;

-- Rollback session coupling
ALTER TABLE imu_sessions DROP FOREIGN KEY fk_imus_game_session;
ALTER TABLE imu_sessions DROP COLUMN game_session_id;

-- Rollback phase 1 (CAUTION: deletes all IMU data)
DROP TABLE IF EXISTS imu_client_uploads;
DROP TABLE IF EXISTS imu_session_files;
DROP TABLE IF EXISTS imu_sessions;
DROP TABLE IF EXISTS devices;
```

---

## Post-Deployment Checklist

- [ ] All 3 migrations ran successfully
- [ ] `imu-alpha` blob container created
- [ ] Function App settings verified (MYSQL_*, AZURE_STORAGE_CONNECTION_STRING)
- [ ] Azure Functions deployed (CreateImuSession, FinalizeImuManifest, GetImuSession)
- [ ] Smoke test 1: Create session (idempotent) ✅
- [ ] Smoke test 2: Upload files to blob ✅
- [ ] Smoke test 3: Finalize WITH rate_stats ✅
- [ ] Smoke test 4: Finalize WITHOUT rate_stats ✅
- [ ] Smoke test 5: GET endpoints ✅
- [ ] Database verification queries run successfully
- [ ] No errors in Application Insights logs

---

## Support

If any step fails:
1. Check Azure Function logs via Application Insights
2. Verify MySQL connection with `mysql` CLI
3. Check blob container permissions
4. Review Function App settings (especially connection strings)
5. Consult `IMU_TEST_EXAMPLES.md` for detailed curl examples
