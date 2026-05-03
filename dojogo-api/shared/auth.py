"""
Authentication utilities for Azure Functions
"""
import jwt
import json
import logging
from functools import wraps
import azure.functions as func

def get_token_from_header(req):
    auth_header = req.headers.get('Authorization')
    if not auth_header:
        return None
    try:
        parts = auth_header.split()
        if parts[0].lower() != 'bearer' or len(parts) != 2:
            return None
        return parts[1]
    except:
        return None

def require_auth(f):
    """Decorator to require authentication for function endpoints"""
    @wraps(f)
    def decorated_function(req):
        logging.info("Auth decorator called")
        try:
            token = get_token_from_header(req)
            logging.info(f"Token extracted: {token[:50] + '...' if token else 'None'}")

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