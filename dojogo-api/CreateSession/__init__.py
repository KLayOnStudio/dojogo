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

        # Check if user maintained their streak (session within last 24 hours)
        yesterday = datetime.now() - timedelta(days=1)
        recent_sessions = execute_query(
            "SELECT COUNT(*) as count FROM sessions WHERE user_id = %s AND created_at >= %s",
            (user_id, yesterday),
            fetch=True
        )

        # Update streak logic
        if recent_sessions and recent_sessions[0]['count'] > 1:
            # User has multiple sessions in last 24 hours, maintain streak
            execute_query(
                "UPDATE users SET streak = streak + 1 WHERE id = %s",
                (user_id,)
            )
        else:
            # Reset streak to 1 (this session)
            execute_query(
                "UPDATE users SET streak = 1 WHERE id = %s",
                (user_id,)
            )

        # Get updated user data
        user = execute_query(
            "SELECT id, name, email, streak, total_count FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        return func.HttpResponse(
            json.dumps({
                "message": "Session created successfully",
                "session_id": session_id,
                "user": user[0] if user else None
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