import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    """Debug endpoint to check nickname timestamp issues"""
    logging.info('DebugNicknameTimestamp function processed a request.')

    try:
        user_id = req.user_id  # From auth decorator

        # Get user's nickname data with timezone info
        result = execute_query(
            """SELECT
                id,
                nickname,
                nickname_last_changed,
                NOW() as current_time,
                UNIX_TIMESTAMP(nickname_last_changed) as timestamp_unix,
                UNIX_TIMESTAMP(NOW()) as now_unix,
                @@session.time_zone as session_tz,
                @@global.time_zone as global_tz
            FROM users
            WHERE id = %s""",
            (user_id,),
            fetch=True
        )

        if not result or not result[0]:
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        user_data = result[0]

        # Calculate the difference
        days_diff = None
        if user_data.get('nickname_last_changed'):
            last_changed = user_data.get('nickname_last_changed')
            current_time = user_data.get('current_time')
            if last_changed and current_time:
                time_diff = current_time - last_changed
                days_diff = time_diff.total_seconds() / 86400  # Convert to days

        response_data = {
            "userId": user_data.get("id"),
            "nickname": user_data.get("nickname"),
            "nicknameLastChanged": str(user_data.get("nickname_last_changed")),
            "currentTime": str(user_data.get("current_time")),
            "timestampUnix": user_data.get("timestamp_unix"),
            "nowUnix": user_data.get("now_unix"),
            "daysSinceChange": days_diff,
            "sessionTimezone": user_data.get("session_tz"),
            "globalTimezone": user_data.get("global_tz"),
            "pythonTimestamp": int(user_data.get("nickname_last_changed").timestamp()) if user_data.get("nickname_last_changed") else None
        }

        return func.HttpResponse(
            json.dumps(response_data, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error in DebugNicknameTimestamp: {e}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
