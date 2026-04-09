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
        # Accept both swingCount (new) and tapCount (legacy) for backwards compat
        swing_count = req_body.get('swingCount') or req_body.get('tapCount')
        duration = req_body.get('duration')
        # Session mode: "guided" (default) or "free"
        mode = req_body.get('mode', 'guided')

        # Optional stats fields (populated by newer clients)
        tempo = req_body.get('tempo')
        avg_speed = req_body.get('avgSpeed')
        max_speed = req_body.get('maxSpeed')
        max_power = req_body.get('maxPower')
        avg_reaction_ms = req_body.get('avgReactionMs')
        avg_strike_time_ms = req_body.get('avgStrikeTimeMs')
        stage_id = req_body.get('stageId')

        if not all([session_id, swing_count is not None, duration is not None]):
            return func.HttpResponse(
                json.dumps({"error": "Missing required fields: id, swingCount, duration"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Fetch user's current rank/experience to store with session
        user_profile = execute_query(
            "SELECT kendo_rank, kendo_experience_years, kendo_experience_months FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )
        kendo_rank = None
        experience_years = 0
        experience_months = 0
        if user_profile and user_profile[0]:
            kendo_rank = user_profile[0].get("kendo_rank")
            experience_years = user_profile[0].get("kendo_experience_years", 0)
            experience_months = user_profile[0].get("kendo_experience_months", 0)

        # Create session record with rank/experience snapshot + stats
        try:
            execute_query(
                """INSERT INTO sessions (id, user_id, swing_count, duration, mode,
                   kendo_rank, experience_years, experience_months,
                   tempo, avg_speed, max_speed, max_power,
                   avg_reaction_ms, avg_strike_time_ms, stage_id)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (session_id, user_id, swing_count, duration, mode,
                 kendo_rank, experience_years, experience_months,
                 tempo, avg_speed, max_speed, max_power,
                 avg_reaction_ms, avg_strike_time_ms, stage_id)
            )
        except Exception:
            # Fallback if stats columns don't exist yet (pre-migration 008)
            try:
                execute_query(
                    """INSERT INTO sessions (id, user_id, swing_count, duration, mode, kendo_rank, experience_years, experience_months)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                    (session_id, user_id, swing_count, duration, mode, kendo_rank, experience_years, experience_months)
                )
            except Exception:
                execute_query(
                    "INSERT INTO sessions (id, user_id, swing_count, duration, mode) VALUES (%s, %s, %s, %s, %s)",
                    (session_id, user_id, swing_count, duration, mode)
                )

        # Update user's total count and check for streak
        execute_query(
            "UPDATE users SET total_count = total_count + %s WHERE id = %s",
            (swing_count, user_id)
        )

        # Check streak logic based on daily activity
        today = datetime.now().date()
        yesterday = today - timedelta(days=1)

        # Check if user already had sessions today (before this one)
        # We need to exclude the session we just created by using a timestamp check
        today_sessions_before = execute_query(
            "SELECT COUNT(*) as count FROM sessions WHERE user_id = %s AND DATE(created_at) = %s AND id != %s",
            (user_id, today, session_id),
            fetch=True
        )

        logging.info(f"STREAK DEBUG - User: {user_id}, Today: {today}, Sessions today before this one: {today_sessions_before}")

        # Only update streak if this is the first session of the day
        if today_sessions_before and today_sessions_before[0]['count'] == 0:  # This is the first session today
            # Check if user had sessions yesterday
            yesterday_sessions = execute_query(
                "SELECT COUNT(*) as count FROM sessions WHERE user_id = %s AND DATE(created_at) = %s",
                (user_id, yesterday),
                fetch=True
            )

            logging.info(f"STREAK DEBUG - Yesterday sessions: {yesterday_sessions}")

            if yesterday_sessions and yesterday_sessions[0]['count'] > 0:
                # User played yesterday, continue streak
                logging.info(f"STREAK DEBUG - Incrementing streak for user {user_id}")
                execute_query(
                    "UPDATE users SET streak = streak + 1 WHERE id = %s",
                    (user_id,)
                )
            else:
                # User didn't play yesterday, reset streak to 1
                logging.info(f"STREAK DEBUG - Resetting streak to 1 for user {user_id}")
                execute_query(
                    "UPDATE users SET streak = 1 WHERE id = %s",
                    (user_id,)
                )
        else:
            logging.info(f"STREAK DEBUG - Not first session today for user {user_id}, not updating streak")
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
                "createdAt": datetime_to_timestamp(user_data.get("created_at"))
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