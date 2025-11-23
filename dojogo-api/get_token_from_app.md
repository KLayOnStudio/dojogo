# How to Get Auth0 Token from iOS App for Testing

## Option 1: Add Debug Print in App (Recommended for Testing)

Add this temporary code to `AuthViewModel.swift` after successful login:

```swift
// In signIn() function, after successful authentication:
if let idToken = credentials.idToken {
    print("🔑 AUTH0 TOKEN FOR TESTING:")
    print(idToken)
    print("🔑 Copy this token and run: export TOKEN='\(idToken)'")
}
```

Then:
1. Run app in Xcode
2. Sign in with Google
3. Check Xcode console for the token
4. Copy and export: `export TOKEN='your_token_here'`
5. Run smoke tests: `cd dojogo-api && ./smoke_test.sh`

## Option 2: Use Auth0 API Directly

If you have a test user with username/password (not just Google):

```bash
cd dojogo-api
chmod +x get_auth0_token.sh
./get_auth0_token.sh
# Follow prompts for email/password
```

## Option 3: Get from Keychain (if app already authenticated)

The token is stored in iOS Keychain. You can access it via:

```swift
// Add to a debug button in the app
if let credentials = try? Auth0Manager.shared.getStoredCredentials() {
    print("Token: \(credentials.idToken)")
    UIPasteboard.general.string = credentials.idToken
    print("Token copied to clipboard!")
}
```

## Testing Flow

Once you have the token:

1. **Export token:**
   ```bash
   export TOKEN='eyJ0eXAiOiJKV1QiLCJhbGc...'
   ```

2. **Run smoke tests:**
   ```bash
   cd dojogo-api
   ./smoke_test.sh
   ```

3. **Or test individual endpoints:**
   ```bash
   # Test CreateUser
   curl -X POST "https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api/CreateUser" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"name":"Test User","email":"test@example.com","nickname":"TestNick"}'

   # Test GetUser
   curl -X GET "https://dojogo-api-h9cxf7h0cve2grc5.centralus-01.azurewebsites.net/api/GetUser" \
     -H "Authorization: Bearer $TOKEN"
   ```

## Token Lifespan

Auth0 ID tokens typically expire after:
- **Default:** 36,000 seconds (10 hours)
- **Check expiration:** Decode token at https://jwt.io

If expired, just sign in again to get a fresh token.
