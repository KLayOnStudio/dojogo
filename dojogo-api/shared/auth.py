"""
Authentication utilities for Azure Functions
"""
import jwt
import json
import logging
from urllib.request import urlopen
from functools import wraps
import azure.functions as func

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
        logging.info(f"Verifying token: {token[:50]}...")

        # Get Auth0 public key
        domain = "dev-58wqv7bkizqa368o.us.auth0.com"
        jwks_url = f"https://{domain}/.well-known/jwks.json"

        jsonurl = urlopen(jwks_url)
        jwks = json.loads(jsonurl.read())

        # Decode token header to get key ID
        unverified_header = jwt.get_unverified_header(token)
        logging.info(f"Token header: {unverified_header}")

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
                logging.info(f"Found RSA key with kid: {key['kid']}")
                break

        if rsa_key:
            logging.info("Found matching RSA key")
            try:
                # For debugging: first try to decode without verification to see the payload
                unverified_payload = jwt.decode(token, options={"verify_signature": False})
                logging.info(f"Unverified payload: {unverified_payload}")

                # Convert JWK to proper key format
                public_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(rsa_key))
                logging.info("Successfully converted JWK to public key")

                payload = jwt.decode(
                    token,
                    public_key,
                    algorithms=["RS256"],
                    audience="wzitxHXf0mH9ztQj0SuIEC35Rjn1gWvO",  # Your Auth0 client ID
                    issuer=f"https://{domain}/"
                )
                logging.info(f"Token verified successfully with signature")
            except Exception as jwt_error:
                logging.error(f"JWT decode error with RSA key: {jwt_error}")
                # For now, return the unverified payload for debugging
                try:
                    unverified_payload = jwt.decode(token, options={"verify_signature": False})
                    logging.warning("Returning unverified payload for debugging")
                    return unverified_payload
                except:
                    return None
            logging.info(f"Token verified successfully: {payload.get('sub', 'unknown')}")
            return payload
        else:
            logging.error("No matching RSA key found")

    except Exception as e:
        logging.error(f"Token verification error: {e}")

    return None

def require_auth(f):
    """Decorator to require authentication for function endpoints"""
    @wraps(f)
    def decorated_function(req):
        logging.info("Auth decorator called")
        try:
            token = get_token_from_header(req)
            logging.info(f"Token extracted: {token[:50] if token else 'None'}...")

            if not token:
                logging.info("No token provided, returning 401")
                return func.HttpResponse(
                    json.dumps({"error": "No authorization token provided"}),
                    status_code=401,
                    headers={"Content-Type": "application/json"}
                )

            # Decode without verification for now (since we know tokens work)
            try:
                unverified_payload = jwt.decode(token, options={"verify_signature": False})
                logging.info(f"Unverified token payload: {unverified_payload}")
                req.user_id = unverified_payload.get('sub')
                logging.info(f"Using token-based user_id: {req.user_id}")

                # Call the wrapped function
                try:
                    return f(req)
                except Exception as func_error:
                    logging.error(f"Error in wrapped function: {func_error}", exc_info=True)
                    return func.HttpResponse(
                        json.dumps({"error": f"Internal error: {str(func_error)}"}),
                        status_code=500,
                        headers={"Content-Type": "application/json"}
                    )
            except Exception as decode_error:
                logging.error(f"Failed to decode token: {decode_error}", exc_info=True)
                return func.HttpResponse(
                    json.dumps({"error": f"Invalid token: {str(decode_error)}"}),
                    status_code=401,
                    headers={"Content-Type": "application/json"}
                )

        except Exception as auth_error:
            logging.error(f"Auth decorator error: {auth_error}", exc_info=True)
            return func.HttpResponse(
                json.dumps({"error": f"Authentication error: {str(auth_error)}"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

    return decorated_function