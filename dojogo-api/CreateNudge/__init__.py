import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

NUDGE_COOLDOWN_HOURS = 24


@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateNudge function processed a request.')

    try:
        req_body = req.get_json()
        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id
        to_user_id = req_body.get('toUserId')

        if not to_user_id:
            return func.HttpResponse(
                json.dumps({"error": "toUserId is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        if to_user_id == user_id:
            return func.HttpResponse(
                json.dumps({"error": "Cannot nudge yourself"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Must be friends
        a, b = (min(user_id, to_user_id), max(user_id, to_user_id))
        friendship = execute_query(
            "SELECT 1 FROM friendships WHERE user_id_a = %s AND user_id_b = %s",
            (a, b),
            fetch=True
        )
        if not friendship:
            return func.HttpResponse(
                json.dumps({"error": "You can only nudge nakama"}),
                status_code=403,
                headers={"Content-Type": "application/json"}
            )

        # Cooldown: one nudge per friend per NUDGE_COOLDOWN_HOURS
        recent = execute_query(
            """SELECT id FROM notifications
               WHERE user_id = %s AND type = 'nudge'
                 AND JSON_UNQUOTE(JSON_EXTRACT(data, '$.fromUserId')) = %s
                 AND created_at > NOW() - INTERVAL %s HOUR""",
            (to_user_id, user_id, NUDGE_COOLDOWN_HOURS),
            fetch=True
        )
        if recent:
            return func.HttpResponse(
                json.dumps({"error": "You already nudged this nakama recently"}),
                status_code=429,
                headers={"Content-Type": "application/json"}
            )

        sender = execute_query(
            "SELECT nickname FROM users WHERE id = %s", (user_id,), fetch=True
        )
        sender_name = sender[0]['nickname'] if sender and sender[0]['nickname'] else "A nakama"

        execute_query(
            """INSERT INTO notifications (user_id, type, title, body, data)
               VALUES (%s, 'nudge', %s, %s, %s)""",
            (
                to_user_id,
                f"{sender_name} nudged you!",
                "Time to pick up the shinai.",
                json.dumps({"fromUserId": user_id})
            )
        )

        return func.HttpResponse(
            json.dumps({"message": "Nudge sent"}),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating nudge: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
