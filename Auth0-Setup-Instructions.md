# Auth0 Setup Instructions for Dojogo

## 1. Add Auth0 SDK Dependency

In Xcode:
1. Go to **File → Add Package Dependencies**
2. Enter this URL: `https://github.com/auth0/Auth0.swift`
3. Click **Add Package**
4. Select the `Auth0` library and click **Add Package**

## 2. Configure Auth0.plist

1. Update the `Auth0.plist` file with your Auth0 credentials:
   ```xml
   <key>ClientId</key>
   <string>YOUR_ACTUAL_AUTH0_CLIENT_ID</string>
   <key>Domain</key>
   <string>YOUR_ACTUAL_AUTH0_DOMAIN</string>
   ```

## 3. Add URL Scheme to Info.plist

Follow the instructions in `Info.plist-additions.md` to add the URL scheme configuration.

## 4. Configure Auth0 Dashboard

In your Auth0 Dashboard:

### Application Settings
- **Application Type**: Native
- **Token Endpoint Authentication Method**: None

### URLs
- **Allowed Callback URLs**: `studio.klayon.dojogo://dev-58wqv7bkizqa368o.us.auth0.com/ios/studio.klayon.dojogo/callback`
- **Allowed Logout URLs**: `studio.klayon.dojogo://dev-58wqv7bkizqa368o.us.auth0.com/ios/studio.klayon.dojogo/callback`

### APIs
Create an API for your backend:
- **Name**: Dojogo API
- **Identifier**: `https://YOUR_AUTH0_DOMAIN/api/v2/`
- **Signing Algorithm**: RS256

## 5. Test Authentication

1. Build and run the app
2. Tap "SIGN UP" or "SIGN IN"
3. You should see the Auth0 login page
4. Complete authentication
5. You should be redirected back to the app

## 6. Backend Integration

Your Azure API should validate Auth0 JWT tokens. The tokens will be sent in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

## Files Created/Modified

✅ **Created:**
- `Auth0.plist` - Auth0 configuration
- `Services/Auth0Manager.swift` - Auth0 integration service
- `Info.plist-additions.md` - URL scheme instructions

✅ **Updated:**
- `ViewModels/AuthViewModel.swift` - Real Auth0 integration
- `Services/APIService.swift` - JWT token authentication

## Troubleshooting

### Common Issues:
1. **"Invalid URL"** - Check that URL scheme matches bundle identifier
2. **"Network Error"** - Verify Auth0 domain and client ID
3. **"Callback not found"** - Ensure callback URL is configured in Auth0 dashboard

### Debug Tips:
- Check Xcode console for Auth0 errors
- Verify Auth0.plist is included in app bundle
- Test with Auth0's web interface first