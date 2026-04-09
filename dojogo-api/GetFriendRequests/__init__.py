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
    logging.info('GetFriendRequests function processed a request.')

    try:
        user_id = req.user_id
        req_type = req.params.get('type', 'incoming')

        if req_type not in ('incoming', 'outgoing'):
            return func.HttpResponse(
                json.dumps({"error": "type must be 'incoming' or 'outgoing'"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        if req_type == 'incoming':
            rows = execute_query(
                """SELECT fr.id, fr.from_user_id, u.nickname, u.user_number, u.kendo_rank, fr.created_at
                   FROM friend_requests fr
                   JOIN users u ON u.id = fr.from_user_id
                   WHERE fr.to_user_id = %s AND fr.status = 'pending'
                   ORDER BY fr.created_at DESC""",
                (user_id,),
                fetch=True
            )
            requests = [{
                "requestId": r["id"],
                "userId": r["from_user_id"],
                "nickname": r["nickname"],
                "userNumber": r["user_number"],
                "kendoRank": r["kendo_rank"],
                "createdAt": datetime_to_timestamp(r["created_at"])
            } for r in rows]
        else:
            rows = execute_query(
                """SELECT fr.id, fr.to_user_id, u.nickname, u.user_number, u.kendo_rank, fr.created_at
                   FROM friend_requests fr
                   JOIN users u ON u.id = fr.to_user_id
                   WHERE fr.from_user_id = %s AND fr.status = 'pending'
                   ORDER BY fr.created_at DESC""",
                (user_id,),
                fetch=True
            )
            requests = [{
                "requestId": r["id"],
                "userId": r["to_user_id"],
                "nickname": r["nickname"],
                "userNumber": r["user_number"],
                "kendoRank": r["kendo_rank"],
                "createdAt": datetime_to_timestamp(r["created_at"])
            } for r in rows]

        return func.HttpResponse(
            json.dumps({"type": req_type, "requests": requests}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting friend requests: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
