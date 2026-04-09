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
    logging.info('GetSessions function processed a request.')

    try:
        user_id = req.user_id

        rows = execute_query(
            """SELECT id, swing_count, duration, mode, created_at,
                      tempo, avg_speed, max_speed, max_power,
                      avg_reaction_ms, avg_strike_time_ms, stage_id
               FROM sessions
               WHERE user_id = %s
               ORDER BY created_at DESC""",
            (user_id,),
            fetch=True
        )

        sessions = []
        for row in (rows or []):
            sessions.append({
                "id": row.get("id"),
                "swingCount": row.get("swing_count"),
                "duration": row.get("duration"),
                "mode": row.get("mode"),
                "createdAt": datetime_to_timestamp(row.get("created_at")),
                "tempo": float(row["tempo"]) if row.get("tempo") is not None else None,
                "avgSpeed": float(row["avg_speed"]) if row.get("avg_speed") is not None else None,
                "maxSpeed": float(row["max_speed"]) if row.get("max_speed") is not None else None,
                "maxPower": float(row["max_power"]) if row.get("max_power") is not None else None,
                "avgReactionMs": float(row["avg_reaction_ms"]) if row.get("avg_reaction_ms") is not None else None,
                "avgStrikeTimeMs": float(row["avg_strike_time_ms"]) if row.get("avg_strike_time_ms") is not None else None,
                "stageId": row.get("stage_id"),
            })

        return func.HttpResponse(
            json.dumps({"sessions": sessions}, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error fetching sessions: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
