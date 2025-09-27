import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime, timedelta

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateSession function processed a request.')

    try:
        # Get session data from request
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id  # From auth decorator
        session_id = req_body.get('id')
        tap_count = req_body.get('tapCount')
        duration = req_body.get('duration')

        if not all([session_id, tap_count is not None, duration is not None]):
            return func.HttpResponse(
                json.dumps({"error": "Missing required fields: id, tapCount, duration"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Create session record
        execute_query(
            "INSERT INTO sessions (id, user_id, tap_count, duration) VALUES (%s, %s, %s, %s)",
            (session_id, user_id, tap_count, duration)
        )

        # Update user's total count and check for streak
        execute_query(
            "UPDATE users SET total_count = total_count + %s WHERE id = %s",
            (tap_count, user_id)
        )

        # Check streak logic based on daily activity
        today = datetime.now().date()
        yesterday = today - timedelta(days=1)

        # Check if user had sessions yesterday
        yesterday_sessions = execute_query(
            "SELECT COUNT(*) as count FROM sessions WHERE user_id = %s AND DATE(created_at) = %s",
            (user_id, yesterday),
            fetch=True
        )

        # Check if user already had sessions today (before this one)
        today_sessions = execute_query(
            "SELECT COUNT(*) as count FROM sessions WHERE user_id = %s AND DATE(created_at) = %s",
            (user_id, today),
            fetch=True
        )

        # Only update streak if this is the first session of the day
        if today_sessions and today_sessions[0]['count'] == 1:  # This is the first session today
            if yesterday_sessions and yesterday_sessions[0]['count'] > 0:
                # User played yesterday, continue streak
                execute_query(
                    "UPDATE users SET streak = streak + 1 WHERE id = %s",
                    (user_id,)
                )
            else:
                # User didn't play yesterday, reset streak to 1
                execute_query(
                    "UPDATE users SET streak = 1 WHERE id = %s",
                    (user_id,)
                )
        # If not first session today, don't change streak

        # Get updated user data
        user = execute_query(
            "SELECT id, name, email, streak, total_count, created_at FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if user and user[0]:
            user_data = user[0]
            user_response = {
                "id": user_data.get("id"),
                "name": user_data.get("name"),
                "email": user_data.get("email"),
                "streak": user_data.get("streak"),
                "totalCount": user_data.get("total_count"),  # Map total_count to totalCount
                "createdAt": int(user_data.get("created_at").timestamp()) if user_data.get("created_at") else None
            }
        else:
            user_response = None

        return func.HttpResponse(
            json.dumps({
                "message": "Session created successfully",
                "session_id": session_id,
                "user": user_response
            }, default=str),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating session: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )