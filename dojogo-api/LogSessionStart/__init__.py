import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('LogSessionStart function processed a request.')

    try:
        user_id = req.user_id  # From auth decorator

        # Log session start
        execute_query(
            "INSERT INTO session_starts (user_id) VALUES (%s)",
            (user_id,)
        )

        return func.HttpResponse(
            json.dumps({
                "message": "Session start logged successfully",
                "user_id": user_id
            }),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error logging session start: {e}")
        logging.error(f"Exception type: {type(e)}")
        logging.error(f"Exception args: {e.args}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )