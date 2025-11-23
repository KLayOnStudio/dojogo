import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime, timedelta

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query, datetime_to_timestamp
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('UpdateNickname function processed a request.')

    try:
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id  # From auth decorator
        new_nickname = req_body.get('nickname')

        if not new_nickname:
            return func.HttpResponse(
                json.dumps({"error": "Nickname is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Validate nickname (alphanumeric, underscores, 3-50 chars)
        if not (3 <= len(new_nickname) <= 50):
            return func.HttpResponse(
                json.dumps({"error": "Nickname must be 3-50 characters"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check if user exists and get last change time
        user = execute_query(
            "SELECT nickname_last_changed FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if not user or not user[0]:
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        # Check 30-day cooldown
        last_changed = user[0].get('nickname_last_changed')
        if last_changed:
            days_since_change = (datetime.now() - last_changed).days
            if days_since_change < 30:
                days_remaining = 30 - days_since_change
                return func.HttpResponse(
                    json.dumps({
                        "error": f"You can change your nickname again in {days_remaining} days",
                        "daysRemaining": days_remaining
                    }),
                    status_code=429,
                    headers={"Content-Type": "application/json"}
                )

        # Check if nickname is already taken
        existing = execute_query(
            "SELECT id FROM users WHERE nickname = %s AND id != %s",
            (new_nickname, user_id),
            fetch=True
        )

        if existing:
            return func.HttpResponse(
                json.dumps({"error": "Nickname is already taken"}),
                status_code=409,
                headers={"Content-Type": "application/json"}
            )

        # Update nickname
        execute_query(
            "UPDATE users SET nickname = %s, nickname_last_changed = NOW() WHERE id = %s",
            (new_nickname, user_id)
        )

        # Return updated user
        updated_user = execute_query(
            "SELECT id, user_number, name, nickname, nickname_last_changed, email, streak, total_count, created_at FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if updated_user and updated_user[0]:
            user_data = updated_user[0]
            user_response = {
                "id": user_data.get("id"),
                "userNumber": user_data.get("user_number"),
                "name": user_data.get("name"),
                "nickname": user_data.get("nickname"),
                "nicknameLastChanged": datetime_to_timestamp(user_data.get("nickname_last_changed")),
                "email": user_data.get("email"),
                "streak": user_data.get("streak"),
                "totalCount": user_data.get("total_count"),
                "createdAt": datetime_to_timestamp(user_data.get("created_at"))
            }

            return func.HttpResponse(
                json.dumps({
                    "message": "Nickname updated successfully",
                    "user": user_response
                }, default=str),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )
        else:
            return func.HttpResponse(
                json.dumps({"error": "Failed to retrieve updated user"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

    except Exception as e:
        logging.error(f"Error updating nickname: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
