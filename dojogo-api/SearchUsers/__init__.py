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
    logging.info('SearchUsers function processed a request.')

    try:
        query = req.params.get('query', '').strip()
        limit = min(int(req.params.get('limit', 10)), 20)

        if len(query) < 2:
            return func.HttpResponse(
                json.dumps({"error": "Query must be at least 2 characters"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id

        # Search by player number if query starts with # or is purely numeric
        numeric_query = query.lstrip('#')
        if numeric_query.isdigit():
            results = execute_query(
                "SELECT id, nickname, user_number, kendo_rank FROM users WHERE user_number = %s AND id != %s LIMIT %s",
                (int(numeric_query), user_id, limit),
                fetch=True
            )
        else:
            results = execute_query(
                "SELECT id, nickname, user_number, kendo_rank FROM users WHERE nickname LIKE %s AND id != %s LIMIT %s",
                (f"{query}%", user_id, limit),
                fetch=True
            )

        users = []
        for row in results:
            users.append({
                "userId": row["id"],
                "nickname": row["nickname"],
                "userNumber": row["user_number"],
                "kendoRank": row["kendo_rank"]
            })

        return func.HttpResponse(
            json.dumps({"results": users}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error searching users: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
