# Dojogo Testing Guide

## ✅ What's Ready to Test

Everything is set up and working! Here's what you can test now:

### 1. iOS App with Mock IMU Data (Simulator)
### 2. API Smoke Tests (IMU Endpoints)
### 3. Core App Functionality (Auth, Game Sessions, Leaderboards)

---

## 📱 Test 1: iOS App on Simulator with Mock IMU

### What Was Added

**MockIMUManager** - Simulates realistic kendo swing motion:
- Kamae (ready position) → Strike → Zashin (stillness) → Return → Kamae
- Realistic acceleration patterns (~25 m/s² peak during strike)
- Realistic gyroscope patterns (~15 rad/s peak rotation)
- Automatic swing trigger on each tap
- Runs at 100 Hz sample rate

### How to Test

1. **Build and Run:**
   ```bash
   # Open Xcode
   open dojogo.xcodeproj

   # Or build from command line:
   xcodebuild -project dojogo.xcodeproj -scheme dojogo \
     -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
     clean build
   ```

2. **Run on Simulator:**
   - Select iPhone 16 (or any iPhone) simulator
   - Press Run (Cmd+R)

3. **Sign In:**
   - Tap "Sign In with Google"
   - Use your Google account
   - **Watch the Xcode console!** You'll see:
     ```
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     🔑 AUTH0 TOKEN FOR SMOKE TESTING:
     eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI...
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     💡 To run smoke tests, copy this token and run:
        export TOKEN='eyJ...'
        cd dojogo-api && ./smoke_test.sh
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     ```
   - **Copy this token!** You'll need it for smoke tests

4. **Play a Session:**
   - Tap "Start" on the main screen
   - Wait for 3-2-1 countdown
   - Tap the button rapidly (10-20 times)
   - Watch the Xcode console for mock IMU logs:
     ```
     🎯 Mock IMU recording started for simulator
     🥋 Swing #1 started
     🥋 Swing #2 started
     ...
     🎯 Mock IMU recording stopped. Total samples: 1200
     📊 Sample data preview:
       [0] ax=0.02, ay=9.83, az=-0.01, gx=0.00, gy=0.00, gz=0.00
       [1] ax=0.01, ay=9.79, az=0.02, gx=-0.50, gy=0.01, gz=-0.02
       [2] ax=-2.15, ay=12.45, az=3.21, gx=-5.23, gy=-0.12, gz=0.45
     ```

5. **Check Results:**
   - Session ends automatically after 20s or tap "End Session"
   - View results (tap count, streak)
   - Check leaderboard
   - View your profile

### What to Verify

- ✅ Auth0 login works
- ✅ User created in database
- ✅ Tap game session records properly
- ✅ Mock IMU captures realistic motion data
- ✅ Each tap triggers a simulated swing
- ✅ Sample count matches session duration (~100 samples per second)
- ✅ Acceleration values look realistic (gravity ~9.81 m/s² when idle, peaks ~25 m/s² during swings)

---

## 🧪 Test 2: IMU Smoke Tests

### Prerequisites

- Auth0 token from iOS app (see Test 1, step 3)

### How to Run

```bash
# 1. Copy the token from Xcode console
export TOKEN='eyJ0eXAiOiJKV1QiLCJhbGci...'  # Paste your actual token

# 2. Navigate to API directory
cd dojogo-api

# 3. Run smoke tests
./smoke_test.sh
```

### What It Tests

The smoke test runs 7 comprehensive tests:

1. **Create IMU Session** - Initialize session, get SAS token for blob upload
2. **Idempotent Retry** - Same client_upload_id returns same session
3. **Upload Files** - Upload raw data + device metadata + calibration to Azure Blob
4. **Finalize Manifest** - Complete upload with checksums and rate stats
5. **GET Session** - Retrieve session metadata and file list
6. **List Sessions** - Fetch user's IMU sessions with pagination
7. **Backward Compatibility** - Finalize without rate_stats (older app versions)

### Expected Output

```
=== DojoGo IMU Smoke Tests ===
API Base: https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net
✅ Using provided Auth0 token

=== Test 1: Create IMU Session (First call) ===
HTTP Status: 201
✅ Test 1 PASSED: Session created with ID 42

=== Test 2: Create IMU Session (Idempotent retry) ===
HTTP Status: 200
✅ Test 2 PASSED: Idempotent call returned same session ID

=== Test 3: Upload sample files to blob storage ===
Raw file upload: HTTP 201
Device file upload: HTTP 201
Calib file upload: HTTP 201
✅ Test 3 PASSED: All files uploaded successfully

=== Test 4: Finalize manifest (WITH rate_stats) ===
HTTP Status: 200
✅ Test 4 PASSED: Manifest finalized with rate_stats

=== Test 5: GET session details ===
HTTP Status: 200
✅ Test 5 PASSED: Session details retrieved with 3 files

=== Test 6: List sessions ===
HTTP Status: 200
✅ Test 6 PASSED: List endpoint returned 2 total sessions

=== Test 7: Backward compatibility (finalize WITHOUT rate_stats) ===
HTTP Status: 200
✅ Test 7 PASSED: Backward compatibility confirmed (no rate_stats)

=========================================
🎉 ALL SMOKE TESTS PASSED!
=========================================
```

---

## 🔍 Test 3: Database Verification

### Check What's in the Database

```bash
# Health check
curl https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api/TestHealth | python3 -m json.tool
```

**Expected:**
```json
{
  "status": "ok",
  "tables": [
    "users",
    "sessions",
    "session_starts",
    "devices",
    "imu_sessions",
    "imu_session_files",
    "imu_session_stats",
    "imu_client_uploads"
  ],
  "db_connection": "success"
}
```

---

## 🎮 Test 4: Full App Flow

### Complete User Journey

1. **Sign Up / Sign In**
   - Launch app
   - Sign in with Google (Auth0)
   - Verify user created in database

2. **Set Profile**
   - Tap profile icon
   - Set nickname (optional)
   - Set kendo rank and experience
   - Save

3. **Play Session**
   - Tap "Start"
   - Wait for countdown
   - Tap rapidly for 10-20 seconds
   - Let session auto-end or tap "End"

4. **View Results**
   - Check tap count
   - Check streak (should increment for daily play)
   - View total taps

5. **Check Leaderboard**
   - View top players by total taps
   - View top players by current streak
   - Verify your entry appears

6. **Mock IMU Verification (Console)**
   - Check Xcode console for IMU logs
   - Verify ~100 samples per second
   - Verify swing count matches tap count

---

## 🐛 Troubleshooting

### Issue: No Auth0 token in console

**Solution:** Make sure you're watching the Xcode console when signing in. The token is printed immediately after successful authentication.

### Issue: Smoke tests fail with "No authorization token provided"

**Solution:**
```bash
# Make sure you exported the token:
export TOKEN='your_token_here'

# Verify it's set:
echo $TOKEN  # Should print the token
```

### Issue: "Token expired" error

**Solution:** Auth0 tokens expire after ~10 hours. Just sign in again on the app to get a fresh token.

### Issue: Mock IMU not generating data

**Solution:**
- Make sure you're running on simulator (not device)
- Check Xcode console for "🎯 Mock IMU recording started"
- Verify taps are triggering swings ("🥋 Swing #X started")

### Issue: Build errors with MockIMUManager

**Solution:**
```bash
# Clean build folder
xcodebuild clean -project dojogo.xcodeproj -scheme dojogo

# Rebuild
xcodebuild -project dojogo.xcodeproj -scheme dojogo \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build
```

---

## 📊 Expected Mock IMU Data Patterns

When you play a session, the mock IMU should generate realistic data:

### Idle (Kamae)
```
ax ≈ 0.0 m/s²
ay ≈ 9.81 m/s² (gravity)
az ≈ 0.0 m/s²
gx ≈ 0.0 rad/s
gy ≈ 0.0 rad/s
gz ≈ 0.0 rad/s
```

### Strike Phase
```
ax ≈ 0.0 to ±3.0 m/s²
ay ≈ -15.0 to 35.0 m/s² (gravity ± large acceleration)
az ≈ 0.0 to 8.0 m/s² (forward motion)
gx ≈ -15.0 to 15.0 rad/s (fast rotation ~860°/s)
gy ≈ -2.0 to 2.0 rad/s
gz ≈ -2.0 to 2.0 rad/s
```

### Zashin (Stillness)
```
ax ≈ ±0.3 m/s² (small oscillations)
ay ≈ 9.5 to 10.1 m/s² (gravity ± damped oscillation)
az ≈ ±0.2 m/s²
gx ≈ ±0.1 rad/s (damping to zero)
gy ≈ 0.0 rad/s
gz ≈ 0.0 rad/s
```

---

## ✅ Success Criteria

You know everything is working if:

1. ✅ App builds and runs on simulator
2. ✅ Auth0 login succeeds and prints token
3. ✅ User appears in database (check via API or TestHealth)
4. ✅ Tap game session creates entry in database
5. ✅ Leaderboard shows your user
6. ✅ Mock IMU generates ~100 samples/second during play
7. ✅ Mock IMU shows realistic kendo swing patterns
8. ✅ Smoke tests pass all 7 tests
9. ✅ IMU session data uploads to Azure Blob
10. ✅ Database has IMU session metadata

---

## 🚀 Next Steps After Testing

Once everything is verified working:

1. **Integrate Real IMU on Device** - Replace MockIMUManager with real CoreMotion data
2. **Build Trajectory Processor** - Implement zashin-based drift correction algorithm
3. **Add Visualization** - Create SwingTrajectoryView to display 3D swing path
4. **Deploy to TestFlight** - Share with beta testers
5. **Collect Real Data** - Gather actual kendo swing data for ML training

---

## 📞 Need Help?

If you encounter issues:
1. Check this guide's troubleshooting section
2. Review Xcode console logs
3. Check Azure Function logs in Azure Portal
4. Verify database connection via TestHealth endpoint
