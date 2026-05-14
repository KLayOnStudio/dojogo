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
    logging.info('GetNotifications function processed a request.')

    try:
        user_id = req.user_id

        rows = execute_query(
            """SELECT n.id, n.type, n.title, n.body, n.data, n.is_read, n.created_at,
                      u.avatar AS sender_avatar
               FROM notifications n
               LEFT JOIN users u ON u.id = JSON_UNQUOTE(JSON_EXTRACT(n.data, '$.fromUserId'))
               WHERE n.user_id = %s
               ORDER BY n.created_at DESC
               LIMIT 50""",
            (user_id,),
            fetch=True
        )

        notifications = [{
            "id": r["id"],
            "type": r["type"],
            "title": r["title"],
            "body": r["body"],
            "data": json.loads(r["data"]) if r["data"] else None,
            "isRead": bool(r["is_read"]),
            "createdAt": int(r["created_at"].timestamp()) if r["created_at"] else None,
            "senderAvatar": r.get("sender_avatar") or "kendoka"
        } for r in (rows or [])]

        unread_count = sum(1 for n in notifications if not n["isRead"])

        return func.HttpResponse(
            json.dumps({"notifications": notifications, "unreadCount": unread_count}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting notifications: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
