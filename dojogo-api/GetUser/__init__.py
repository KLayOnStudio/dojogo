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
        logging.info(f'Getting user with ID: {user_id}')

        # Get user data
        user = execute_query(
            "SELECT id, user_number, name, nickname, nickname_last_changed, kendo_rank, kendo_experience_years, kendo_experience_months, email, streak, total_count, created_at, last_session_date FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        logging.info(f'Query result: {user}')

        if not user:
            logging.error(f'User not found for ID: {user_id}')
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        user_data = user[0]
        user_response = {
            "id": user_data.get("id"),
            "userNumber": user_data.get("user_number"),
            "name": user_data.get("name"),
            "nickname": user_data.get("nickname"),
            "nicknameLastChanged": int(user_data.get("nickname_last_changed").timestamp()) if user_data.get("nickname_last_changed") else None,
            "kendoRank": user_data.get("kendo_rank"),
            "kendoExperienceYears": user_data.get("kendo_experience_years"),
            "kendoExperienceMonths": user_data.get("kendo_experience_months"),
            "email": user_data.get("email"),
            "streak": user_data.get("streak"),
            "totalCount": user_data.get("total_count"),
            "createdAt": int(user_data.get("created_at").timestamp()) if user_data.get("created_at") else None,
            "lastSessionDate": int(user_data.get("last_session_date").timestamp()) if user_data.get("last_session_date") else None
        }

        return func.HttpResponse(
            json.dumps({
                "user": user_response
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