# Dojogo - Build Documentation

## Project Overview
**Dojogo** is an iOS gamification app focused on tap-based training sessions with real-time leaderboards and streak tracking. Users authenticate via Auth0 (Google OAuth), complete timed tap sessions, and compete on global leaderboards.

---

## Infrastructure & Services

### Azure Cloud Services

#### Azure Functions API
- **URL**: `https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api`
- **Region**: Central US
- **Service**: Azure Functions (Serverless)
- **Runtime**: Python

**API Endpoints:**
- `POST /CreateUser` - Create new user account
- `GET /GetUser` - Get user profile and stats
- `POST /LogSessionStart` - Log app session start
- `POST /CreateSession` - Submit completed tap session
- `GET /GetLeaderboard?type={total|streak}&limit={number}` - Get leaderboard data

#### Azure Database
- **Type**: MySQL Database on Azure
- **Connection**: Managed through Azure Functions
- **Tables**:
  - `users` - User profiles with Auth0 IDs
  - `sessions` - Completed tap session records
  - `session_starts` - App launch tracking

### Authentication - Auth0

**Configuration File**: `Auth0.plist` (not in repo, must be created)

**Required Auth0 Settings:**
- **Domain**: Your Auth0 domain (e.g., `your-tenant.auth0.com`)
- **Client ID**: Your Auth0 application client ID
- **Callback URL**: `studio.klayon.dojogo://dev-dojogo.us.auth0.com/ios/studio.klayon.dojogo/callback`
- **Allowed Web Origins**: Configured in Auth0 dashboard
- **Connections**: Google OAuth (enabled)

**Auth0.plist Structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Domain</key>
    <string>YOUR_AUTH0_DOMAIN</string>
    <key>ClientId</key>
    <string>YOUR_CLIENT_ID</string>
</dict>
</plist>
```

**Bundle URL Scheme**: `studio.klayon.dojogo` (configured in Info.plist)

---

## Database Schema

### Users Table
```sql
CREATE TABLE users (
    id VARCHAR(255) PRIMARY KEY,        -- Auth0 user ID
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    streak INT DEFAULT 0,               -- Current daily streak
    total_count INT DEFAULT 0,          -- Total taps across all sessions
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_session_date DATE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Sessions Table
```sql
CREATE TABLE sessions (
    id VARCHAR(36) PRIMARY KEY,         -- UUID
    user_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    tap_count INT NOT NULL,
    duration DECIMAL(10,2) NOT NULL,    -- Duration in seconds
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Session Starts Table
```sql
CREATE TABLE session_starts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
```

---

## App Architecture

### Technology Stack
- **Platform**: iOS (SwiftUI)
- **Language**: Swift
- **Minimum iOS Version**: iOS 15.0+
- **Authentication**: Auth0 SDK
- **Networking**: URLSession (async/await)
- **Data Persistence**: UserDefaults (local fallback)
- **Audio**: AVFoundation

### Key Features

#### 1. Authentication Flow
- Auth0 Web Authentication with Google OAuth
- Automatic session persistence
- Token-based API authentication
- Credential refresh handling

#### 2. Game Mechanics
- **Session Start**: User taps "HAJIME!" to begin
- **Tap Tracking**: Random button repositioning on each tap
- **Time-based Backgrounds**: Visual changes based on local time (Dawn, Day, Sunset, Night)
- **Sound Effects**: Custom swoosh sound (SFXswoosh.mp3) with mute toggle
- **Inactivity Timeout**: Auto-end session after 20 seconds of no taps
- **Session End**: User taps "YAME!" or timeout triggers

#### 3. Streak System
- Daily streak tracking
- Streak breaks if user doesn't complete a session on consecutive days
- Displayed on report screen after each session

#### 4. Leaderboards
- **Total Taps**: Global ranking by all-time tap count
- **Streaks**: Global ranking by current daily streak
- Real-time updates from Azure database
- Top 50 users displayed

### App Screens

#### AuthView (Sign In)
- Background: MainLogo image with light blue-to-white gradient
- Buttons: "SIGN UP" and "SIGN IN"
- Auth0 integration for Google OAuth

#### MainMapView (Home)
- Background: MapVer0.png image
- Start button: "HAJIME!" (Japanese for "Begin")
- Navigation bar: Home (dojoIcon.png) and Leaderboard (badgeLeague.png)
- User info display with sign out option

#### ActionView (Game Session)
- Dynamic time-based gradient backgrounds
- Tap button: shinaiPixel.png image with "TAP" overlay
- HUD: Tap counter, Sound toggle, "YAME!" (Stop) button
- Random button repositioning on each tap

#### ReportView (Session Results)
- Displays: Total taps, Duration (MM:SS), Current streak
- Auto-submits session data to Azure
- "CONTINUE" button returns to home

#### LeaderboardView (Rankings)
- Toggle between Total Taps and Streaks leaderboards
- Top 3 ranks highlighted with special styling
- Scrollable list of top 50 users

### Visual Design
- **Font**: Pixelify Sans (retro pixel aesthetic)
- **Color Scheme**: Retro game-inspired (black, yellow, green, red, cyan)
- **Layout**: Responsive with GeometryReader for all device sizes
- **Safe Area Handling**: Proper padding for notched devices

---

## Assets

### Images
- `MainLogo` - App logo (authentication screen background)
- `MapVer0.png` - Main map background
- `shinaiPixel.png` - Tap button image
- `dojoIcon.png` - Home navigation icon
- `badgeLeague.png` - Leaderboard navigation icon

### Fonts
- `PixelifySans-Regular.ttf` - Primary app font

### Audio
- `SFXswoosh.mp3` - Tap sound effect

---

## Local Storage (Fallback)

When API calls fail, the app uses local UserDefaults:
- User profiles
- Session data
- Streak calculations (manual date-based logic)

**UserDefaults Keys:**
- `dojogo_users` - Array of User objects
- `dojogo_sessions` - Array of Session objects

---

## Build Configuration

### Required Files (Not in Repository)
1. **Auth0.plist** - Auth0 credentials
2. **SFXswoosh.mp3** - Sound effect file

### Bundle Identifier
`studio.klayon.dojogo`

### URL Scheme
`studio.klayon.dojogo://`

### Capabilities Required
- Networking (for API calls)
- Keychain Sharing (for Auth0 credential storage)

---

## Development Notes

### Testing Checklist
- [ ] Auth0 authentication flow (sign up, sign in, sign out)
- [ ] Google account switching
- [ ] Session creation and submission
- [ ] Streak calculation accuracy
- [ ] Leaderboard data loading
- [ ] Sound effects and mute toggle
- [ ] Responsive layouts on different device sizes
- [ ] Safe area handling on notched devices

### Known Dependencies
- Auth0 Swift SDK
- JWTDecode (for token parsing)
- AVFoundation (for audio playback)

### API Authentication
All API requests include:
```
Authorization: Bearer {ID_TOKEN}
```
Token is automatically retrieved from Auth0 CredentialsManager.

---

## Deployment

### Azure Functions
- Function app is deployed and running at Central US region
- Python runtime with HTTP triggers
- Connected to Azure MySQL database

### App Store (Future)
- Bundle ID: `studio.klayon.dojogo`
- Will require App Store Connect setup
- Privacy policy needed for Auth0/Google OAuth

---

## Version History
- **Current Build**: v1.0 (Development)
- **Last Updated**: 2025-09-30

---

## Contact & Support
For issues or questions about this build, refer to the codebase or contact the development team.

**Repository Structure:**
```
dojogo/
├── dojogo/
│   ├── Views/           # SwiftUI views
│   ├── ViewModels/      # Business logic
│   ├── Models/          # Data models
│   ├── Services/        # API & Auth services
│   ├── Extensions/      # Swift extensions
│   ├── Assets.xcassets/ # Images
│   ├── Fonts/           # Font files
│   └── Info.plist       # App configuration
├── database_schema.sql  # Database schema
└── BUILD_DOCUMENTATION.md (this file)
```
