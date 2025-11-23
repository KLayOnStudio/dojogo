#!/bin/bash

# Auth0 Configuration
DOMAIN="dev-58wqv7bkizqa368o.us.auth0.com"
CLIENT_ID="wzitxHXf0mH9ztQj0SuIEC35Rjn1gWvO"
AUDIENCE="wzitxHXf0mH9ztQj0SuIEC35Rjn1gWvO"

echo "=== Get Auth0 Token ==="
echo "Domain: $DOMAIN"
echo ""
echo "You need test user credentials (email + password)"
echo ""
read -p "Email: " EMAIL
read -sp "Password: " PASSWORD
echo ""
echo ""
echo "Getting token..."

RESPONSE=$(curl -s --request POST \
  --url "https://$DOMAIN/oauth/token" \
  --header 'content-type: application/json' \
  --data "{
    \"grant_type\": \"password\",
    \"username\": \"$EMAIL\",
    \"password\": \"$PASSWORD\",
    \"audience\": \"$AUDIENCE\",
    \"client_id\": \"$CLIENT_ID\",
    \"scope\": \"openid profile email\"
  }")

# Check if we got an error
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')

if [ ! -z "$ERROR" ]; then
    echo "❌ Error getting token:"
    echo "$RESPONSE" | jq .
    exit 1
fi

# Extract token
TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "❌ No token in response:"
    echo "$RESPONSE" | jq .
    exit 1
fi

echo "✅ Token obtained successfully!"
echo ""
echo "To use this token, run:"
echo "  export TOKEN='$TOKEN'"
echo ""
echo "Then run smoke tests:"
echo "  ./smoke_test.sh"
echo ""
echo "Token expires in: $(echo "$RESPONSE" | jq -r '.expires_in') seconds"
