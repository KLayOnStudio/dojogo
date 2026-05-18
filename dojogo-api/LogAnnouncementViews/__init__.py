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
    logging.info('LogAnnouncementViews function processed a request.')

    try:
        user_id = req.user_id
        body = req.get_json(silent=True) or {}
        announcement_ids = body.get("announcementIds", [])

        if not announcement_ids or not isinstance(announcement_ids, list):
            return func.HttpResponse(
                json.dumps({"error": "announcementIds array required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        for aid in announcement_ids:
            execute_query(
                """INSERT IGNORE INTO announcement_views (user_id, announcement_id)
                   VALUES (%s, %s)""",
                (user_id, aid)
            )

        return func.HttpResponse(
            json.dumps({"message": "Logged"}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error logging announcement views: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
