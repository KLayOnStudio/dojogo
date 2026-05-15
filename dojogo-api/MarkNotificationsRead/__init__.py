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
    logging.info('MarkNotificationsRead function processed a request.')

    try:
        user_id = req.user_id

        body = {}
        try:
            body = req.get_json(silent=True) or {}
        except Exception:
            pass

        notification_ids = body.get("notificationIds")

        if notification_ids and isinstance(notification_ids, list) and len(notification_ids) > 0:
            placeholders = ", ".join(["%s"] * len(notification_ids))
            execute_query(
                f"UPDATE notifications SET is_read = TRUE WHERE user_id = %s AND id IN ({placeholders}) AND is_read = FALSE",
                (user_id, *notification_ids)
            )
        else:
            execute_query(
                "UPDATE notifications SET is_read = TRUE WHERE user_id = %s AND is_read = FALSE",
                (user_id,)
            )

        return func.HttpResponse(
            json.dumps({"message": "Marked as read"}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error marking notifications read: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
