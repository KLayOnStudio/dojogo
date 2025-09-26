"""
Authentication utilities for Azure Functions
"""
import jwt
import json
import logging
from urllib.request import urlopen
from functools import wraps

def get_token_from_header(req):
    """Extract JWT token from Authorization header"""
    auth_header = req.headers.get('Authorization')
    if not auth_header:
        return None

    try:
        # Expected format: "Bearer <token>"
        parts = auth_header.split()
        if parts[0].lower() != 'bearer' or len(parts) != 2:
            return None
        return parts[1]
    except:
        return None

def verify_token(token):
    """
    Verify Auth0 JWT token

    Returns:
        dict: Decoded token payload if valid, None if invalid
    """
    try:
        # Get Auth0 public key
        domain = "dev-58wqv7bkizqa368o.us.auth0.com"
        jwks_url = f"https://{domain}/.well-known/jwks.json"

        jsonurl = urlopen(jwks_url)
        jwks = json.loads(jsonurl.read())

        # Decode token header to get key ID
        unverified_header = jwt.get_unverified_header(token)
        rsa_key = {}

        for key in jwks["keys"]:
            if key["kid"] == unverified_header["kid"]:
                rsa_key = {
                    "kty": key["kty"],
                    "kid": key["kid"],
                    "use": key["use"],
                    "n": key["n"],
                    "e": key["e"]
                }

        if rsa_key:
            payload = jwt.decode(
                token,
                rsa_key,
                algorithms=["RS256"],
                audience="wzitxHXf0mH9ztQj0SuIEC35Rjn1gWvO",  # Your Auth0 client ID
                issuer=f"https://{domain}/"
            )
            return payload

    except Exception as e:
        logging.error(f"Token verification error: {e}")

    return None

def require_auth(f):
    """Decorator to require authentication for function endpoints"""
    @wraps(f)
    def decorated_function(req):
        token = get_token_from_header(req)
        if not token:
            return {
                "statusCode": 401,
                "body": json.dumps({"error": "No authorization token provided"})
            }

        payload = verify_token(token)
        if not payload:
            return {
                "statusCode": 401,
                "body": json.dumps({"error": "Invalid token"})
            }

        # Add user info to request
        req.user_id = payload.get('sub')
        return f(req)

    return decorated_function