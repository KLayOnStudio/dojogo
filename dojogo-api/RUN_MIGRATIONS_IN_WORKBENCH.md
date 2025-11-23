# Running IMU Migrations in MySQL Workbench

## Connection Details

Use these credentials to connect in MySQL Workbench:

- **Hostname:** dojogo-mysql-us-west2.mysql.database.azure.com
- **Port:** 3306
- **Username:** klayon
- **Password:** Zmfodyd4urAI
- **Default Schema:** dojogo
- **SSL:** Required (Use SSL if available option)

---

## Step-by-Step Instructions

### 1. Create New Connection in MySQL Workbench

1. Open MySQL Workbench
2. Click the `+` icon next to "MySQL Connections"
3. Enter connection details:
   - **Connection Name:** DojoGo MySQL (Staging)
   - **Hostname:** dojogo-mysql-us-west2.mysql.database.azure.com
   - **Port:** 3306
   - **Username:** klayon
   - **Password:** Click "Store in Keychain" and enter: Zmfodyd4urAI
   - **Default Schema:** dojogo
4. Go to **SSL** tab:
   - **Use SSL:** If available
   - **SSL Mode:** Required
5. Click **Test Connection** to verify
6. Click **OK** to save

### 2. Connect to Database

1. Double-click your new "DojoGo MySQL (Staging)" connection
2. Verify you're connected to the `dojogo` database (shown in left sidebar)

### 3. Run Migration 1: IMU Phase 1 (Base Tables)

1. In MySQL Workbench, click **File** → **Open SQL Script**
2. Navigate to: `/Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api/`
3. Open: `database_migration_imu_phase1.sql`
4. Click the **Execute** button (lightning bolt icon) or press **Cmd+Shift+Enter**
5. Wait for "Action Output" to show success messages

**Expected Output:**
```
USE dojogo - OK
CREATE TABLE devices - OK
CREATE TABLE imu_sessions - OK
CREATE TABLE imu_session_files - OK
CREATE TABLE imu_client_uploads - OK
SELECT (verification query) - 4 rows returned
```

### 4. Verify Migration 1

Run this query in a new tab:
```sql
SHOW TABLES LIKE '%imu%';
SHOW TABLES LIKE 'devices';
```

**Expected Result:**
- devices
- imu_client_uploads
- imu_session_files
- imu_sessions

### 5. Run Migration 2: Session Coupling

1. Click **File** → **Open SQL Script**
2. Open: `database_migration_session_coupled_imu.sql`
3. Click **Execute**

**Expected Output:**
```
ALTER TABLE imu_sessions ADD COLUMN game_session_id - OK
ALTER TABLE imu_sessions ADD KEY idx_imus_game_session - OK
ALTER TABLE imu_sessions ADD CONSTRAINT fk_imus_game_session - OK
```

### 6. Verify Migration 2

```sql
DESCRIBE imu_sessions;
```

**Expected:** You should see `game_session_id` column (VARCHAR(36), NULL, with foreign key)

### 7. Run Migration 3: Rate Stats

1. Click **File** → **Open SQL Script**
2. Open: `database_migration_rate_stats.sql`
3. Click **Execute**

**Expected Output:**
```
ALTER TABLE imu_sessions ADD COLUMN actual_mean_hz - OK
CREATE TABLE imu_session_stats - OK
CREATE INDEX idx_imus_actual_hz - OK
CREATE INDEX idx_imus_stats_quality - OK
```

### 8. Verify Migration 3

```sql
DESCRIBE imu_sessions;
DESCRIBE imu_session_stats;
```

**Expected:**
- `imu_sessions` has `actual_mean_hz` column
- `imu_session_stats` table exists with columns: imu_session_id, samples_total, duration_ms, mean_hz, dt_ms_p50, dt_ms_p95, dt_ms_max, dropped_seq_pct

### 9. Final Verification

Run this comprehensive check:
```sql
-- Show all IMU tables
SELECT
    TABLE_NAME,
    TABLE_ROWS,
    TABLE_COMMENT
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'dojogo'
  AND (TABLE_NAME LIKE 'imu_%' OR TABLE_NAME = 'devices')
ORDER BY TABLE_NAME;

-- Show all foreign keys
SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE CONSTRAINT_SCHEMA = 'dojogo'
  AND REFERENCED_TABLE_NAME IS NOT NULL
  AND (TABLE_NAME LIKE 'imu_%' OR TABLE_NAME = 'devices')
ORDER BY TABLE_NAME, CONSTRAINT_NAME;
```

**Expected Tables:**
- devices
- imu_client_uploads
- imu_session_files
- imu_sessions
- imu_session_stats

**Expected Foreign Keys:**
- fk_devices_user (devices → users)
- fk_imus_user (imu_sessions → users)
- fk_imus_device (imu_sessions → devices)
- fk_imus_game_session (imu_sessions → sessions)
- fk_imuf_sess (imu_session_files → imu_sessions)
- fk_imuc_sess (imu_client_uploads → imu_sessions)
- fk_imus_stats (imu_session_stats → imu_sessions)

---

## Troubleshooting

### Connection Fails

**Error:** "Can't connect to MySQL server"
- Check VPN/network connection
- Verify SSL is enabled
- Check Azure firewall rules allow your IP

**Error:** "Access denied for user 'klayon'"
- Verify password is correct: Zmfodyd4urAI
- Check user has permissions on `dojogo` database

### Migration Errors

**Error:** "Table already exists"
- Tables were created in previous run
- This is OK - migrations use `CREATE TABLE IF NOT EXISTS`
- Continue with next migration

**Error:** "Column already exists"
- Column was added in previous run
- Safely skip that migration step

**Error:** "Foreign key constraint fails"
- Verify parent table (`users` or `sessions`) exists
- Check the existing schema has those tables

---

## After Migrations Complete

Once all 3 migrations run successfully, report back and I'll proceed with:

1. ✅ MySQL migrations (DONE)
2. Create Azure Blob container `imu-alpha`
3. Verify Function App settings
4. Deploy Azure Functions
5. Run smoke tests

---

## Quick Copy-Paste Credentials

```
Hostname: dojogo-mysql-us-west2.mysql.database.azure.com
Port: 3306
Username: klayon
Password: Zmfodyd4urAI
Database: dojogo
SSL: Required
```
