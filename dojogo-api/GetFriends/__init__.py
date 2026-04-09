import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query, datetime_to_timestamp
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetFriends function processed a request.')

    try:
        user_id = req.user_id

        rows = execute_query(
            """SELECT u.id, u.nickname, u.user_number, u.kendo_rank, u.streak, u.total_count,
                      (SELECT MAX(s.created_at) FROM sessions s WHERE s.user_id = u.id) as last_session_date
               FROM friendships f
               JOIN users u ON u.id = CASE
                   WHEN f.user_id_a = %s THEN f.user_id_b
                   ELSE f.user_id_a
               END
               WHERE f.user_id_a = %s OR f.user_id_b = %s
               ORDER BY u.nickname""",
            (user_id, user_id, user_id),
            fetch=True
        )

        friends = [{
            "userId": r["id"],
            "nickname": r["nickname"],
            "userNumber": r["user_number"],
            "kendoRank": r["kendo_rank"],
            "streak": r["streak"],
            "totalCount": r["total_count"],
            "lastSessionDate": datetime_to_timestamp(r["last_session_date"])
        } for r in rows]

        return func.HttpResponse(
            json.dumps({"friends": friends}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting friends: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
