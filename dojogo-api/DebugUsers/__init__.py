import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('DebugUsers function processed a request.')

    try:
        # Get all users with their details
        users = execute_query(
            "SELECT id, name, email, streak, total_count, created_at FROM users ORDER BY created_at DESC",
            fetch=True
        )

        # Get all sessions
        sessions = execute_query(
            "SELECT id, user_id, tap_count, duration, created_at FROM sessions ORDER BY created_at DESC LIMIT 20",
            fetch=True
        )

        # Get session count by user
        session_counts = execute_query(
            "SELECT user_id, COUNT(*) as session_count FROM sessions GROUP BY user_id ORDER BY session_count DESC",
            fetch=True
        )

        # Get daily session counts for streak debugging
        daily_sessions = execute_query(
            """SELECT user_id, DATE(created_at) as session_date, COUNT(*) as daily_count
               FROM sessions
               GROUP BY user_id, DATE(created_at)
               ORDER BY user_id, session_date DESC""",
            fetch=True
        )

        return func.HttpResponse(
            json.dumps({
                "users": users,
                "recent_sessions": sessions,
                "session_counts_by_user": session_counts,
                "daily_sessions": daily_sessions
            }, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error in DebugUsers: {e}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )