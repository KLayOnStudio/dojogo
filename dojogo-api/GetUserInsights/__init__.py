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
    logging.info('GetUserInsights function processed a request.')

    try:
        user_id = req.user_id
        target_user_id = req.params.get('userId')

        if not target_user_id:
            return func.HttpResponse(
                json.dumps({"error": "userId query parameter is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check friendship exists
        a, b = (min(user_id, target_user_id), max(user_id, target_user_id))
        friendship = execute_query(
            "SELECT 1 FROM friendships WHERE user_id_a = %s AND user_id_b = %s",
            (a, b),
            fetch=True
        )
        if not friendship:
            return func.HttpResponse(
                json.dumps({"error": "You must be friends to view insights"}),
                status_code=403,
                headers={"Content-Type": "application/json"}
            )

        # Get user profile + ranks
        rows = execute_query(
            """SELECT u.id, u.nickname, u.user_number, u.kendo_rank,
                      u.kendo_experience_years, u.kendo_experience_months,
                      u.home_dojo, u.streak, u.total_count,
                      (SELECT MAX(s.created_at) FROM sessions s WHERE s.user_id = u.id) as last_session_date,
                      (SELECT COUNT(*) + 1 FROM users u2 WHERE u2.total_count > u.total_count) as swing_rank,
                      (SELECT COUNT(*) + 1 FROM users u2 WHERE u2.streak > u.streak) as streak_rank
               FROM users u
               WHERE u.id = %s""",
            (target_user_id,),
            fetch=True
        )

        if not rows:
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        r = rows[0]
        user_data = {
            "userId": r["id"],
            "nickname": r["nickname"],
            "userNumber": r["user_number"],
            "kendoRank": r["kendo_rank"],
            "kendoExperienceYears": r["kendo_experience_years"],
            "kendoExperienceMonths": r["kendo_experience_months"],
            "homeDojo": r["home_dojo"],
            "streak": r["streak"],
            "totalCount": r["total_count"],
            "lastSessionDate": datetime_to_timestamp(r["last_session_date"]),
            "swingRank": r["swing_rank"],
            "streakRank": r["streak_rank"]
        }

        return func.HttpResponse(
            json.dumps({"user": user_data}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting user insights: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
