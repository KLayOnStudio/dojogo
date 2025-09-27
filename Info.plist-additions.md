# Info.plist Additions for Auth0

Add the following to your Info.plist file:

## URL Schemes

Add this to the `<dict>` section of your Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>auth0</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        </array>
    </dict>
</array>
```

## Example Complete Addition

If your bundle identifier is `studio.klayon.dojogo`, the URL scheme will be:
- `studio.klayon.dojogo://dev-58wqv7bkizqa368o.us.auth0.com/ios/studio.klayon.dojogo/callback`

## Steps to Add:

1. Open your project in Xcode
2. Select the `dojogo` target
3. Go to the `Info` tab
4. Under `URL Types`, click the `+` button
5. Set:
   - **Identifier**: `auth0`
   - **URL Schemes**: `studio.klayon.dojogo` (or your bundle identifier)
   - **Role**: `Editor`

## Auth0 Dashboard Configuration

In your Auth0 Dashboard, add these URLs to your application settings:

**Allowed Callback URLs:**
```
studio.klayon.dojogo://dev-58wqv7bkizqa368o.us.auth0.com/ios/studio.klayon.dojogo/callback
```

**Allowed Logout URLs:**
```
studio.klayon.dojogo://dev-58wqv7bkizqa368o.us.auth0.com/ios/studio.klayon.dojogo/callback
```