# 🧪 Running Dojogo Tests - Step by Step

## ✅ What I've Done

I've built the app successfully and it's ready to test. Here's what needs to happen:

---

## 🎯 Step-by-Step Testing Process

### Step 1: Launch the App (You need to do this)

Since I can't interact with the iOS simulator GUI, you'll need to:

1. **Open Xcode:**
   ```bash
   open /Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo.xcodeproj
   ```

2. **Select Simulator:**
   - In Xcode, select "iPhone 16" (or any iPhone) from the device dropdown
   - Click the Run button (▶️) or press Cmd+R

3. **Open Console:**
   - In Xcode, press Cmd+Shift+Y to open the console at the bottom
   - This is where you'll see all the debug output

---

### Step 2: Sign In and Get Token

1. **In the app:**
   - Tap "Sign In with Google"
   - Complete the Auth0/Google login flow

2. **In Xcode Console:**
   - Look for this output:
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   🔑 AUTH0 TOKEN FOR SMOKE TESTING:
   eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ik5qRTVNVE...
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   💡 To run smoke tests, copy this token and run:
      export TOKEN='eyJ...'
      cd dojogo-api && ./smoke_test.sh
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

3. **Copy the token:**
   - Select and copy the entire token (the long string starting with `eyJ...`)
   - Keep it handy for the next step

---

### Step 3: Test Mock IMU (Optional but Cool!)

While still in the app:

1. **Play a session:**
   - Tap "Start" on the main screen
   - Wait for 3-2-1 countdown
   - Tap the button rapidly 10-20 times
   - Let it auto-end after 20 seconds (or tap "End Session")

2. **Watch Xcode Console:**
   - You should see:
   ```
   🎯 Mock IMU recording started for simulator
   🥋 Swing #1 started
   🥋 Swing #2 started
   🥋 Swing #3 started
   ...
   🎯 Mock IMU recording stopped. Total samples: 1200
   📊 Sample data preview:
     [0] ax=0.02, ay=9.83, az=-0.01, gx=0.00, gy=0.00, gz=0.00
     [1] ax=0.01, ay=9.79, az=0.02, gx=-0.50, gy=0.01, gz=-0.02
     [2] ax=-2.15, ay=12.45, az=3.21, gx=-5.23, gy=-0.12, gz=0.45
   ```

3. **Verify:**
   - Total samples ≈ 100 × session_duration_in_seconds
   - Swing count ≈ number of taps
   - Acceleration values look realistic (gravity ~9.81, peaks ~25)

---

### Step 4: Run Smoke Tests (I can help with this!)

Once you have the token, paste it here and I'll run the smoke tests for you. Or you can run them yourself:

**Option A: Let me run them (easier)**
- Just paste the token in chat: "Here's my token: eyJ..."
- I'll export it and run the smoke tests

**Option B: Run them yourself**
```bash
# In a new terminal:
export TOKEN='<paste-your-token-here>'

cd /Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api

./smoke_test.sh
```

---

## 📋 What the Smoke Tests Will Do

The script will run 7 tests automatically:

1. ✅ Create IMU Session → Should return 201 Created
2. ✅ Retry with same ID → Should return 200 OK (idempotent)
3. ✅ Upload files to Azure Blob → Should return 201 Created
4. ✅ Finalize manifest → Should return 200 OK
5. ✅ GET session details → Should return session with 3 files
6. ✅ List user sessions → Should return at least 1 session
7. ✅ Backward compatibility → Should work without rate_stats

**Expected Output:**
```
🎉 ALL SMOKE TESTS PASSED!
```

---

## 🐛 Troubleshooting

### "I don't see the token in console"
- Make sure Xcode console is open (Cmd+Shift+Y)
- Try signing in again
- Look for the "🔑 AUTH0 TOKEN" message
- Check you're running the latest build (I just modified Auth0Manager.swift)

### "Token expired"
- Auth0 tokens expire after ~10 hours
- Just sign in again to get a fresh token

### "Smoke tests fail"
- Make sure TOKEN is exported: `echo $TOKEN` should print the token
- Make sure token is the full string (starts with `eyJ`)
- Try copying the token again from console

---

## ✨ What's Ready

✅ App built successfully
✅ MockIMUManager integrated
✅ Auth0 token debug print added
✅ Smoke test script ready
✅ All dependencies installed

---

## 🚀 Next Steps After Testing

Once tests pass, we can:
1. Verify database has correct data
2. Check Azure Blob has uploaded files
3. Start building the trajectory processor
4. Add visualization component

---

**Ready to go!** Just launch the app in Xcode and follow the steps above. Let me know when you have the token or if you need help with anything!
