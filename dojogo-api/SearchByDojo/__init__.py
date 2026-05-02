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
    logging.info('SearchByDojo function processed a request.')

    try:
        dojo = req.params.get('dojo', '').strip()

        if not dojo:
            return func.HttpResponse(
                json.dumps({"error": "dojo parameter is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id

        results = execute_query(
            """SELECT id, nickname, user_number, kendo_rank
               FROM users
               WHERE home_dojo = %s
                 AND is_public = TRUE
                 AND id != %s
               ORDER BY nickname""",
            (dojo, user_id),
            fetch=True
        )

        users = [{
            "userId": row["id"],
            "nickname": row["nickname"],
            "userNumber": row["user_number"],
            "kendoRank": row["kendo_rank"]
        } for row in results]

        return func.HttpResponse(
            json.dumps({"dojo": dojo, "results": users}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error searching by dojo: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
