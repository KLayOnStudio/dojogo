import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query

def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Returns active announcements (not expired), newest first.
    No auth required — public data.
    """
    logging.info('GetAnnouncements function processed a request.')

    try:
        now = datetime.utcnow()

        rows = execute_query(
            """SELECT id, title, body, image_url, created_at
               FROM announcements
               WHERE expires_at IS NULL OR expires_at > %s
               ORDER BY created_at DESC""",
            (now,),
            fetch=True
        )

        announcements = [{
            "id": row["id"],
            "title": row["title"],
            "body": row["body"],
            "imageUrl": row["image_url"],
            "createdAt": int(row["created_at"].timestamp()) if row["created_at"] else None
        } for row in rows]

        return func.HttpResponse(
            json.dumps({"announcements": announcements}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting announcements: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
