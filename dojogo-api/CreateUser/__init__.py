import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query, datetime_to_timestamp
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateUser function processed a request.')

    try:
        # Get user data from request
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id  # From auth decorator
        name = req_body.get('name')
        email = req_body.get('email')
        nickname = req_body.get('nickname')  # Optional

        logging.info(f"CreateUser called with user_id: {user_id}, name: {name}, email: {email}, nickname: {nickname}")

        if not all([user_id, name, email]):
            return func.HttpResponse(
                json.dumps({"error": "Missing required fields: user_id, name, email"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check if user already exists
        existing_user = execute_query(
            "SELECT id FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if existing_user:
            # User exists - return full user data
            user = execute_query(
                "SELECT id, user_number, name, nickname, nickname_last_changed, kendo_rank, kendo_experience_years, kendo_experience_months, email, streak, total_count, created_at FROM users WHERE id = %s",
                (user_id,),
                fetch=True
            )

            if user and user[0]:
                user_data = user[0]
                user_response = {
                    "id": user_data.get("id"),
                    "userNumber": user_data.get("user_number"),
                    "name": user_data.get("name"),
                    "nickname": user_data.get("nickname"),
                    "nicknameLastChanged": datetime_to_timestamp(user_data.get("nickname_last_changed")),
                    "kendoRank": user_data.get("kendo_rank"),
                    "kendoExperienceYears": user_data.get("kendo_experience_years"),
                    "kendoExperienceMonths": user_data.get("kendo_experience_months"),
                    "email": user_data.get("email"),
                    "streak": user_data.get("streak"),
                    "totalCount": user_data.get("total_count"),
                    "createdAt": datetime_to_timestamp(user_data.get("created_at"))
                }
            else:
                user_response = None

            return func.HttpResponse(
                json.dumps({
                    "message": "User already exists",
                    "user": user_response
                }, default=str),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )

        # Create new user (with optional nickname)
        if nickname:
            execute_query(
                "INSERT INTO users (id, name, nickname, nickname_last_changed, email, streak, total_count) VALUES (%s, %s, %s, NOW(), %s, 0, 0)",
                (user_id, name, nickname, email)
            )
        else:
            execute_query(
                "INSERT INTO users (id, name, email, streak, total_count) VALUES (%s, %s, %s, 0, 0)",
                (user_id, name, email)
            )

        # Return created user
        user = execute_query(
            "SELECT id, user_number, name, nickname, nickname_last_changed, kendo_rank, kendo_experience_years, kendo_experience_months, email, streak, total_count, created_at FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if user and user[0]:
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
                "createdAt": int(user_data.get("created_at").timestamp()) if user_data.get("created_at") else None
            }
        else:
            user_response = None

        return func.HttpResponse(
            json.dumps({
                "message": "User created successfully",
                "user": user_response
            }, default=str),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating user: {e}")
        logging.error(f"Exception type: {type(e)}")
        logging.error(f"Exception args: {e.args}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )