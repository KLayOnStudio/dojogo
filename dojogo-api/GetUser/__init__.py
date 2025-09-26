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
    logging.info('GetUser function processed a request.')

    try:
        user_id = req.user_id  # From auth decorator

        # Get user data
        user = execute_query(
            "SELECT id, name, email, streak, total_count, created_at, updated_at FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if not user:
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        return func.HttpResponse(
            json.dumps({
                "user": user[0]
            }, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting user: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )