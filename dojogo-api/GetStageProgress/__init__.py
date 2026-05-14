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
    logging.info('GetStageProgress function processed a request.')

    try:
        user_id = req.user_id

        rows = execute_query(
            """SELECT stage_id, SUM(swing_count) AS total_swings
               FROM sessions
               WHERE user_id = %s AND stage_id IS NOT NULL AND mode = 'guided'
               GROUP BY stage_id""",
            (user_id,),
            fetch=True
        )

        stage_progress = {
            str(r['stage_id']): int(r['total_swings'])
            for r in (rows or [])
        }

        return func.HttpResponse(
            json.dumps({"stageProgress": stage_progress}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting stage progress: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
