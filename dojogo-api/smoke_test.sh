#!/bin/bash
set -e

API_BASE="https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net"

echo "=== DojoGo IMU Smoke Tests ==="
echo "API Base: $API_BASE"
echo ""

# Check if TOKEN is provided
if [ -z "$TOKEN" ]; then
    echo "⚠️  TOKEN environment variable not set"
    echo "Please provide an Auth0 JWT token:"
    echo "  export TOKEN='your_jwt_token_here'"
    echo ""
    echo "You can get a token from your iOS app or Auth0 dashboard."
    exit 1
fi

echo "✅ Using provided Auth0 token"
echo ""

# Test 1: Create IMU Session (First call)
echo "=== Test 1: Create IMU Session (First call) ==="
CLIENT_UPLOAD_ID=$(uuidgen)
echo "Client Upload ID: $CLIENT_UPLOAD_ID"

CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$CLIENT_UPLOAD_ID'",
    "device_info": {
      "platform": "ios",
      "model": "iPhone 14 Pro - Smoke Test",
      "os_version": "17.2.1",
      "app_version": "1.0.0-smoketest",
      "hw_id": "SMOKE-TEST-DEVICE-001"
    },
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0,
    "coord_frame": "device",
    "notes": "Automated smoke test"
  }')

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo "Response:"
echo "$RESPONSE_BODY" | jq .

if [ "$HTTP_CODE" != "201" ]; then
    echo "❌ Test 1 FAILED: Expected 201, got $HTTP_CODE"
    exit 1
fi

IMU_SESSION_ID=$(echo "$RESPONSE_BODY" | jq -r '.imu_session_id')
SAS_URL=$(echo "$RESPONSE_BODY" | jq -r '.sas_token.sas_url')

# Extract base URL and SAS query string
SAS_BASE_URL="${SAS_URL%\?*}"
SAS_QUERY="${SAS_URL#*\?}"

echo "✅ Test 1 PASSED: Session created with ID $IMU_SESSION_ID"
echo ""

# Test 2: Create IMU Session (Idempotent retry)
echo "=== Test 2: Create IMU Session (Idempotent retry) ==="
CREATE_RESPONSE_2=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$CLIENT_UPLOAD_ID'",
    "device_info": {
      "platform": "ios",
      "model": "iPhone 14 Pro - Smoke Test",
      "hw_id": "SMOKE-TEST-DEVICE-001"
    },
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0
  }')

HTTP_CODE_2=$(echo "$CREATE_RESPONSE_2" | tail -1)
RESPONSE_BODY_2=$(echo "$CREATE_RESPONSE_2" | sed '$d')
IMU_SESSION_ID_2=$(echo "$RESPONSE_BODY_2" | jq -r '.imu_session_id')

echo "HTTP Status: $HTTP_CODE_2"
echo "Response:"
echo "$RESPONSE_BODY_2" | jq .

if [ "$HTTP_CODE_2" != "200" ]; then
    echo "❌ Test 2 FAILED: Expected 200 (idempotent), got $HTTP_CODE_2"
    exit 1
fi

if [ "$IMU_SESSION_ID" != "$IMU_SESSION_ID_2" ]; then
    echo "❌ Test 2 FAILED: Session IDs don't match ($IMU_SESSION_ID vs $IMU_SESSION_ID_2)"
    exit 1
fi

echo "✅ Test 2 PASSED: Idempotent call returned same session ID"
echo ""

# Test 3: Upload tiny sample files to blob
echo "=== Test 3: Upload sample files to blob storage ==="

# Create tiny sample files
cat > /tmp/raw_${IMU_SESSION_ID}_0000.jsonl << 'EOF'
{"ts_ns":1737371400000000000,"ax":0.15,"ay":9.81,"az":0.02,"gx":0.001,"gy":-0.001,"gz":0.150}
{"ts_ns":1737371400010000000,"ax":0.18,"ay":9.83,"az":0.01,"gx":0.002,"gy":0.000,"gz":0.148}
{"ts_ns":1737371400020000000,"ax":0.12,"ay":9.80,"az":0.03,"gx":0.000,"gy":0.001,"gz":0.152}
EOF

cat > /tmp/device_${IMU_SESSION_ID}.json << EOF
{
  "imu_session_id": $IMU_SESSION_ID,
  "platform": "ios",
  "model": "iPhone 14 Pro - Smoke Test",
  "captured_at": "$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")"
}
EOF

cat > /tmp/calib_${IMU_SESSION_ID}.json << EOF
{
  "imu_session_id": $IMU_SESSION_ID,
  "captured_at": "$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")",
  "calibration_source": "uncalibrated"
}
EOF

# Upload raw file
RAW_UPLOAD=$(curl -s -w "\n%{http_code}" -X PUT "${SAS_BASE_URL}raw_${IMU_SESSION_ID}_0000.jsonl?${SAS_QUERY}" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/x-ndjson" \
  --data-binary @/tmp/raw_${IMU_SESSION_ID}_0000.jsonl)
RAW_STATUS=$(echo "$RAW_UPLOAD" | tail -1)

# Upload device file
DEVICE_UPLOAD=$(curl -s -w "\n%{http_code}" -X PUT "${SAS_BASE_URL}device_${IMU_SESSION_ID}.json?${SAS_QUERY}" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/device_${IMU_SESSION_ID}.json)
DEVICE_STATUS=$(echo "$DEVICE_UPLOAD" | tail -1)

# Upload calib file
CALIB_UPLOAD=$(curl -s -w "\n%{http_code}" -X PUT "${SAS_BASE_URL}calib_${IMU_SESSION_ID}.json?${SAS_QUERY}" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/calib_${IMU_SESSION_ID}.json)
CALIB_STATUS=$(echo "$CALIB_UPLOAD" | tail -1)

echo "Raw file upload: HTTP $RAW_STATUS"
echo "Device file upload: HTTP $DEVICE_STATUS"
echo "Calib file upload: HTTP $CALIB_STATUS"

if [ "$RAW_STATUS" != "201" ] || [ "$DEVICE_STATUS" != "201" ] || [ "$CALIB_STATUS" != "201" ]; then
    echo "❌ Test 3 FAILED: File uploads failed"
    exit 1
fi

# Compute checksums
RAW_CHECKSUM=$(shasum -a 256 /tmp/raw_${IMU_SESSION_ID}_0000.jsonl | awk '{print $1}')
DEVICE_CHECKSUM=$(shasum -a 256 /tmp/device_${IMU_SESSION_ID}.json | awk '{print $1}')
CALIB_CHECKSUM=$(shasum -a 256 /tmp/calib_${IMU_SESSION_ID}.json | awk '{print $1}')
RAW_SIZE=$(stat -f%z /tmp/raw_${IMU_SESSION_ID}_0000.jsonl 2>/dev/null || stat -c%s /tmp/raw_${IMU_SESSION_ID}_0000.jsonl)
DEVICE_SIZE=$(stat -f%z /tmp/device_${IMU_SESSION_ID}.json 2>/dev/null || stat -c%s /tmp/device_${IMU_SESSION_ID}.json)
CALIB_SIZE=$(stat -f%z /tmp/calib_${IMU_SESSION_ID}.json 2>/dev/null || stat -c%s /tmp/calib_${IMU_SESSION_ID}.json)

echo "✅ Test 3 PASSED: All files uploaded successfully"
echo ""

# Test 4: Finalize manifest WITH rate_stats
echo "=== Test 4: Finalize manifest (WITH rate_stats) ==="
FINALIZE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/api/v1/imu/sessions/$IMU_SESSION_ID/manifest" \
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
  }')

FINALIZE_STATUS=$(echo "$FINALIZE_RESPONSE" | tail -1)
FINALIZE_BODY=$(echo "$FINALIZE_RESPONSE" | sed '$d')

echo "HTTP Status: $FINALIZE_STATUS"
echo "Response:"
echo "$FINALIZE_BODY" | jq .

if [ "$FINALIZE_STATUS" != "200" ]; then
    echo "❌ Test 4 FAILED: Expected 200, got $FINALIZE_STATUS"
    exit 1
fi

echo "✅ Test 4 PASSED: Manifest finalized with rate_stats"
echo ""

# Test 5: GET session details
echo "=== Test 5: GET session details ==="
GET_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_BASE/api/v1/imu/sessions/$IMU_SESSION_ID" \
  -H "Authorization: Bearer $TOKEN")

GET_STATUS=$(echo "$GET_RESPONSE" | tail -1)
GET_BODY=$(echo "$GET_RESPONSE" | sed '$d')

echo "HTTP Status: $GET_STATUS"
echo "Response:"
echo "$GET_BODY" | jq .

if [ "$GET_STATUS" != "200" ]; then
    echo "❌ Test 5 FAILED: Expected 200, got $GET_STATUS"
    exit 1
fi

FILES_COUNT=$(echo "$GET_BODY" | jq '.files | length')
if [ "$FILES_COUNT" != "3" ]; then
    echo "❌ Test 5 FAILED: Expected 3 files, got $FILES_COUNT"
    exit 1
fi

echo "✅ Test 5 PASSED: Session details retrieved with $FILES_COUNT files"
echo ""

# Test 6: List sessions
echo "=== Test 6: List sessions ==="
LIST_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$API_BASE/api/v1/imu/sessions?limit=5" \
  -H "Authorization: Bearer $TOKEN")

LIST_STATUS=$(echo "$LIST_RESPONSE" | tail -1)
LIST_BODY=$(echo "$LIST_RESPONSE" | sed '$d')

echo "HTTP Status: $LIST_STATUS"
echo "Response:"
echo "$LIST_BODY" | jq .

if [ "$LIST_STATUS" != "200" ]; then
    echo "❌ Test 6 FAILED: Expected 200, got $LIST_STATUS"
    exit 1
fi

TOTAL=$(echo "$LIST_BODY" | jq '.total')
if [ "$TOTAL" -lt "1" ]; then
    echo "❌ Test 6 FAILED: Expected at least 1 session, got $TOTAL"
    exit 1
fi

echo "✅ Test 6 PASSED: List endpoint returned $TOTAL total sessions"
echo ""

# Test 7: Backward compatibility (finalize WITHOUT rate_stats)
echo "=== Test 7: Backward compatibility (finalize WITHOUT rate_stats) ==="
CLIENT_UPLOAD_ID_2=$(uuidgen)

CREATE_RESPONSE_3=$(curl -s -X POST "$API_BASE/api/v1/imu/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_upload_id": "'$CLIENT_UPLOAD_ID_2'",
    "device_info": {
      "platform": "ios",
      "model": "iPhone 14 Pro - Backward Compat Test",
      "hw_id": "SMOKE-TEST-DEVICE-001"
    },
    "start_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "nominal_hz": 100.0
  }')

IMU_SESSION_ID_3=$(echo "$CREATE_RESPONSE_3" | jq -r '.imu_session_id')

FINALIZE_RESPONSE_2=$(curl -s -w "\n%{http_code}" -X POST "$API_BASE/api/v1/imu/sessions/$IMU_SESSION_ID_3/manifest" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "end_time_utc": "'$(date -u +"%Y-%m-%dT%H:%M:%S.000000Z")'",
    "files": []
  }')

FINALIZE_STATUS_2=$(echo "$FINALIZE_RESPONSE_2" | tail -1)
FINALIZE_BODY_2=$(echo "$FINALIZE_RESPONSE_2" | sed '$d')

echo "HTTP Status: $FINALIZE_STATUS_2"
echo "Response:"
echo "$FINALIZE_BODY_2" | jq .

if [ "$FINALIZE_STATUS_2" != "200" ]; then
    echo "❌ Test 7 FAILED: Expected 200, got $FINALIZE_STATUS_2"
    exit 1
fi

echo "✅ Test 7 PASSED: Backward compatibility confirmed (no rate_stats)"
echo ""

# Cleanup temp files
rm -f /tmp/raw_${IMU_SESSION_ID}_0000.jsonl /tmp/device_${IMU_SESSION_ID}.json /tmp/calib_${IMU_SESSION_ID}.json

echo "========================================="
echo "🎉 ALL SMOKE TESTS PASSED!"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✅ Create IMU session (201 Created)"
echo "  ✅ Idempotent retry (200 OK, same ID)"
echo "  ✅ Upload files to blob storage"
echo "  ✅ Finalize manifest WITH rate_stats"
echo "  ✅ GET session details"
echo "  ✅ List sessions with pagination"
echo "  ✅ Backward compatibility (no rate_stats)"
echo ""
echo "Staging URL: $API_BASE"
echo "Test Session ID: $IMU_SESSION_ID"
echo ""
