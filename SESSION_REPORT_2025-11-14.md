# Development Session Report - November 14, 2025

## Summary
This session focused on updating the ProfileView UI to allow individual field editing and fixing a critical date parsing bug that was causing incorrect nickname change cooldown calculations.

---

## 1. ProfileView UI Redesign ✅

### **Objective**
Make the profile page more user-friendly by showing current values in non-editable fields with individual Edit/Confirm/Cancel buttons for each field.

### **What Was Changed**
- **Nickname Section** (ProfileView.swift:80-180)
  - Shows current nickname or "Not set" when not editing
  - Individual EDIT button (blue) when field is editable
  - CONFIRM (green) and CANCEL (red) buttons appear when editing
  - Yellow border highlights the editable field
  - Displays 14-day cooldown restriction notice

- **Kendo Rank Section** (ProfileView.swift:182-280)
  - Shows current rank in read-only display
  - Menu picker with yellow border when editing
  - Individual Edit/Confirm/Cancel buttons

- **Kendo Experience Section** (ProfileView.swift:282-397)
  - Shows "X years, Y months" when not editing
  - Side-by-side pickers for years (0-50) and months (0-11)
  - Yellow borders when editing
  - Individual Edit/Confirm/Cancel buttons

### **Individual Save Functions**
Created three separate save functions (ProfileView.swift:462-579):
- `saveNickname()` - Updates only nickname, validates uniqueness and 14-day cooldown
- `saveRank()` - Updates only kendo rank
- `saveExperience()` - Updates years and months together

### **Files Modified**
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo/Views/ProfileView.swift`

---

## 2. Nickname Change Cooldown Adjustment ✅

### **Objective**
Reduce the nickname change cooldown from 30 days to 14 days.

### **What Was Changed**
Updated cooldown period in three locations:
1. **User.swift:91** - Client-side validation: `daysSinceChange >= 14`
2. **ProfileView.swift:170,175** - UI messages now say "14 days"
3. **UpdateProfile/__init__.py:66-67** - Server-side validation: `days_since_change < 14`

### **Files Modified**
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo/Models/User.swift`
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo/Views/ProfileView.swift`
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api/UpdateProfile/__init__.py`

---

## 3. Critical Date Parsing Bug Discovery & Fix 🐛✅

### **The Problem**
User reported seeing "Can change in 11,333 days" for nickname changes, even though the last change was 29 days ago (well past the 14-day cooldown).

### **Investigation Process**

#### **Step 1: Initial Hypothesis**
First thought was that the 14-day cooldown wasn't updated everywhere. After checking the code, cooldown was correctly set to 14 days.

#### **Step 2: Database Investigation**
Connected to MySQL database via Workbench and ran diagnostic query:
```sql
SELECT
    id,
    name,
    nickname,
    nickname_last_changed,
    NOW() as current_datetime,
    DATEDIFF(NOW(), nickname_last_changed) as days_since_change,
    UNIX_TIMESTAMP(nickname_last_changed) as timestamp_seconds
FROM users
WHERE nickname IS NOT NULL;
```

**Results:**
- `nickname_last_changed`: 2025-10-16 02:55:17
- `days_since_change`: 29 days (correct!)
- `timestamp_seconds`: 1760583317

#### **Step 3: Console Debug Logging**
Added debug logging to track the date through the system:
```swift
DEBUG ProfileView: lastChanged=2056-10-16 02:55:17 +0000, daysSinceChange=-11293, daysRemaining=11307, canChange=false
```

**Smoking Gun:** The date was being parsed as **2056** instead of **2025** - exactly 31 years in the future!

#### **Step 4: Root Cause Analysis**
Calculated the offset:
- Database timestamp: `1760583317` (seconds since Unix epoch 1970)
- iOS parsed date: October 16, **2056**
- Apple's reference date: January 1, **2001** (timestamp: 978328800)

**The Bug:**
```python
# What should happen:
1760583317 seconds since 1970 = October 16, 2025

# What was happening:
1760583317 seconds since 2001 = October 16, 2056
```

Swift's default `JSONDecoder` interprets numeric date values as seconds since **Apple's reference date (2001)**, NOT Unix epoch (1970)!

### **The Fix**

#### **Root Cause Location**
`LocalStorageService.swift:99` was decoding cached User data without specifying the date decoding strategy:
```swift
let user = try JSONDecoder().decode(User.self, from: data)
```

#### **Solution Implemented**
Configure JSONEncoder/JSONDecoder to use Unix epoch timestamps:

**LocalStorageService.swift:86-89** (Encoding):
```swift
func saveUser(_ user: User) {
    do {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970  // Fix: Use Unix epoch
        let encoded = try encoder.encode(user)
        userDefaults.set(encoded, forKey: userKey)
    } catch {
        print("Failed to save user: \(error)")
    }
}
```

**LocalStorageService.swift:99-102** (Decoding):
```swift
do {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970  // Fix: Use Unix epoch
    let user = try decoder.decode(User.self, from: data)
    return user
} catch {
    print("Failed to decode user: \(error)")
    return nil
}
```

### **Files Modified**
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo/Services/LocalStorageService.swift`

### **Database Credentials**
For future reference, the actual MySQL credentials are:
- **Hostname:** `dojogo-mysql-us-west2.mysql.database.azure.com`
- **Port:** `3306`
- **Username:** `klayon`
- **Password:** `Zmfodyd4urAI`
- **Database:** `dojogo`

---

## 4. Azure Function Created (Not Fully Deployed)

### **Objective**
Create an admin function to fix future timestamps in the database.

### **What Was Created**
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api/FixNicknameTimestamps/__init__.py`
- `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api/FixNicknameTimestamps/function.json`

**Function Purpose:**
- Identifies users with `nickname_last_changed` timestamps in the future
- Sets them to NULL to allow immediate nickname changes
- Returns a report of affected users

**Note:** Function was deployed but encountered runtime errors. Since the date parsing bug was fixed at the source, this function is no longer critical but could be useful for future admin tasks.

---

## Key Learnings

### **1. Swift Date Handling Gotcha**
Swift's `JSONDecoder` defaults to Apple's reference date (2001) for numeric timestamps, not Unix epoch (1970). Always specify:
```swift
decoder.dateDecodingStrategy = .secondsSince1970
encoder.dateEncodingStrategy = .secondsSince1970
```

### **2. Debugging Dates Across System Boundaries**
When dealing with timestamps across different systems (API → iOS → Database):
- Log the raw timestamp value at each boundary
- Log the converted date immediately after conversion
- Compare with known-good reference dates
- Check for 31-year offsets (2001 vs 1970 reference)

### **3. Client-Side Caching Issues**
The bug wasn't immediately visible in API code because:
- API correctly returned Unix timestamps
- iOS correctly parsed them in APIService.swift
- BUT LocalStorageService cached the data with incorrect encoding
- Cached data persisted across app launches

**Solution:** Always restart the app completely when testing date-related fixes.

---

## Testing Checklist

After these changes, verify:
- [ ] Profile page loads with correct current values
- [ ] Edit buttons appear on each field
- [ ] Confirm/Cancel buttons work correctly
- [ ] Nickname change shows correct cooldown message (14 days)
- [ ] Dates appear as 2025, not 2056
- [ ] Days remaining calculation is correct
- [ ] All three fields (nickname, rank, experience) save independently

---

## Known Issues / Future Work

1. **FixNicknameTimestamps Function** - Has import error (`shared.database` vs `shared.db`), can be fixed if needed for admin tasks
2. **Date Migration** - Existing cached user data in UserDefaults may still have wrong dates until app is reinstalled or cache is cleared
3. **Session Data Dates** - May want to audit `Session` model and other date fields for similar issues

---

## Build Status

✅ **Final Build:** SUCCESS
✅ **All Changes:** Committed and ready to test
✅ **Simulator:** iPhone 16 (iOS 18.6)

---

## Next Session Recommendations

1. **Test the ProfileView changes** thoroughly on simulator
2. **Test on physical device** to verify database updates work correctly
3. **Consider adding unit tests** for date encoding/decoding
4. **Audit other date fields** (createdAt, lastSessionDate, etc.) for similar issues
5. **Update API documentation** to clearly specify that all timestamps are Unix epoch (seconds since 1970)

---

## Database Queries for Reference

**Check nickname change timestamps:**
```sql
SELECT
    id,
    name,
    nickname,
    nickname_last_changed,
    NOW() as current_datetime,
    DATEDIFF(NOW(), nickname_last_changed) as days_since_change,
    UNIX_TIMESTAMP(nickname_last_changed) as timestamp_seconds
FROM users
WHERE nickname IS NOT NULL;
```

**Reset nickname cooldown (allow immediate change):**
```sql
UPDATE users
SET nickname_last_changed = NULL
WHERE nickname_last_changed > NOW();
```

**Or for specific users:**
```sql
UPDATE users
SET nickname_last_changed = NULL
WHERE id IN ('google-oauth2|101631252096982011409', 'google-oauth2|111725496993830615484');
```

---

## Files Summary

### **Modified Files:**
1. `dojogo/Views/ProfileView.swift` - UI redesign with individual edit controls
2. `dojogo/Models/User.swift` - 14-day cooldown update
3. `dojogo/Services/LocalStorageService.swift` - **Critical date encoding/decoding fix**
4. `dojogo/Services/APIService.swift` - Added debug logging for date parsing
5. `dojogo-api/UpdateProfile/__init__.py` - 14-day cooldown update

### **Created Files:**
1. `dojogo-api/FixNicknameTimestamps/__init__.py` - Admin function (needs debugging)
2. `dojogo-api/FixNicknameTimestamps/function.json` - Function configuration

---

**Session Duration:** ~2 hours
**Primary Developer:** Claude Code
**Build Status:** ✅ SUCCESS
**Tests Pending:** Manual testing in simulator/device
