import azure.functions as func
import json
import logging

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('TestJWT function processed a request.')

    try:
        import jwt
        result = {"jwt_import": "success", "jwt_version": jwt.__version__}
    except Exception as e:
        result = {"jwt_import": "failed", "error": str(e)}

    try:
        import sys
        import os
        sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))
        from auth import get_token_from_header
        result["auth_import"] = "success"
    except Exception as e:
        result["auth_import"] = "failed"
        result["auth_error"] = str(e)

    return func.HttpResponse(
        json.dumps(result),
        status_code=200,
        headers={"Content-Type": "application/json"}
    )