import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

import json
from database import execute_query, execute_transaction
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('RespondFriendRequest function processed a request.')

    try:
        req_body = req.get_json()
        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id
        request_id = req_body.get('requestId')
        action = req_body.get('action')

        if not request_id or action not in ('accept', 'decline', 'cancel'):
            return func.HttpResponse(
                json.dumps({"error": "requestId and action (accept/decline/cancel) are required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Fetch the request
        rows = execute_query(
            "SELECT id, from_user_id, to_user_id, status FROM friend_requests WHERE id = %s",
            (request_id,),
            fetch=True
        )

        if not rows:
            return func.HttpResponse(
                json.dumps({"error": "Friend request not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        fr = rows[0]

        if fr['status'] != 'pending':
            return func.HttpResponse(
                json.dumps({"error": "Friend request is no longer pending"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Permission check
        if action in ('accept', 'decline') and fr['to_user_id'] != user_id:
            return func.HttpResponse(
                json.dumps({"error": "Only the recipient can accept or decline"}),
                status_code=403,
                headers={"Content-Type": "application/json"}
            )
        if action == 'cancel' and fr['from_user_id'] != user_id:
            return func.HttpResponse(
                json.dumps({"error": "Only the sender can cancel"}),
                status_code=403,
                headers={"Content-Type": "application/json"}
            )

        if action == 'accept':
            # Normalize friendship ordering
            a = min(fr['from_user_id'], fr['to_user_id'])
            b = max(fr['from_user_id'], fr['to_user_id'])

            # Get acceptor's nickname for the notification
            acceptor = execute_query(
                "SELECT nickname FROM users WHERE id = %s", (user_id,), fetch=True
            )
            acceptor_name = acceptor[0]['nickname'] if acceptor and acceptor[0]['nickname'] else "Your nakama request"

            execute_transaction([
                (
                    "UPDATE friend_requests SET status = 'accepted', responded_at = NOW() WHERE id = %s",
                    (request_id,)
                ),
                (
                    "INSERT IGNORE INTO friendships (user_id_a, user_id_b) VALUES (%s, %s)",
                    (a, b)
                ),
                (
                    """INSERT INTO notifications (user_id, type, title, body, data)
                       VALUES (%s, 'friend_accepted', %s, %s, %s)""",
                    (
                        fr['from_user_id'],
                        f"{acceptor_name} accepted!",
                        "You're now nakama",
                        json.dumps({"userId": user_id})
                    )
                )
            ])
        else:
            new_status = 'declined' if action == 'decline' else 'canceled'
            execute_query(
                "UPDATE friend_requests SET status = %s, responded_at = NOW() WHERE id = %s",
                (new_status, request_id)
            )

        messages = {
            'accept': 'Friend request accepted',
            'decline': 'Friend request declined',
            'cancel': 'Friend request canceled'
        }

        return func.HttpResponse(
            json.dumps({"message": messages[action], "action": action}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error responding to friend request: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
