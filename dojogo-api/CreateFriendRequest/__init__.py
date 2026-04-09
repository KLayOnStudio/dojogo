import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateFriendRequest function processed a request.')

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

        # Cannot friend yourself
        if to_user_id == user_id:
            return func.HttpResponse(
                json.dumps({"error": "Cannot send friend request to yourself"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check target exists
        target = execute_query(
            "SELECT id FROM users WHERE id = %s",
            (to_user_id,),
            fetch=True
        )
        if not target:
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        # Check not already friends
        a, b = (min(user_id, to_user_id), max(user_id, to_user_id))
        friendship = execute_query(
            "SELECT 1 FROM friendships WHERE user_id_a = %s AND user_id_b = %s",
            (a, b),
            fetch=True
        )
        if friendship:
            return func.HttpResponse(
                json.dumps({"error": "Already friends"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check no pending request in either direction
        pending = execute_query(
            "SELECT id FROM friend_requests WHERE status = 'pending' AND ((from_user_id = %s AND to_user_id = %s) OR (from_user_id = %s AND to_user_id = %s))",
            (user_id, to_user_id, to_user_id, user_id),
            fetch=True
        )
        if pending:
            return func.HttpResponse(
                json.dumps({"error": "A pending friend request already exists"}),
                status_code=409,
                headers={"Content-Type": "application/json"}
            )

        # Create the request
        execute_query(
            "INSERT INTO friend_requests (from_user_id, to_user_id) VALUES (%s, %s)",
            (user_id, to_user_id)
        )

        # Get the inserted ID
        result = execute_query(
            "SELECT LAST_INSERT_ID() as id",
            fetch=True
        )
        request_id = result[0]['id'] if result else 0

        return func.HttpResponse(
            json.dumps({"message": "Friend request sent", "requestId": request_id}),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating friend request: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
