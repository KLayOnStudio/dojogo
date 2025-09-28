import azure.functions as func
import json
import logging
import jwt
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from auth import get_token_from_header

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('TestAuth function processed a request.')

    try:
        # Test authentication without requiring it
        token = get_token_from_header(req)

        result = {
            "has_auth_header": req.headers.get('Authorization') is not None,
            "token_extracted": token is not None
        }

        if token:
            result["token_length"] = len(token)
            result["token_start"] = token[:50] if len(token) > 50 else token

            try:
                # Try to decode without verification
                unverified_payload = jwt.decode(token, options={"verify_signature": False})
                result["jwt_decode_success"] = True
                result["jwt_payload"] = unverified_payload
                result["user_id_from_token"] = unverified_payload.get('sub')
            except Exception as jwt_error:
                result["jwt_decode_success"] = False
                result["jwt_error"] = str(jwt_error)
        else:
            result["auth_header_value"] = req.headers.get('Authorization', 'None')

        return func.HttpResponse(
            json.dumps(result, indent=2, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"TestAuth error: {e}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )