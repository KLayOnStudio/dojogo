import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateGuestSession function processed a request.')

    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Invalid JSON body"}),
            status_code=400,
            headers={"Content-Type": "application/json"}
        )

    session_id = body.get("id")
    swing_count = body.get("swingCount")
    duration = body.get("duration")

    if not session_id or swing_count is None or duration is None:
        return func.HttpResponse(
            json.dumps({"error": "Missing required fields: id, swingCount, duration"}),
            status_code=400,
            headers={"Content-Type": "application/json"}
        )

    mode = body.get("mode", "guided")
    kendo_rank = body.get("kendoRank")
    experience_years = body.get("experienceYears", 0)
    experience_months = body.get("experienceMonths", 0)
    guest_name = body.get("guestName")
    device_id = body.get("deviceId")

    try:
        execute_query(
            """INSERT INTO sessions
               (id, user_id, swing_count, duration, mode,
                kendo_rank, experience_years, experience_months,
                guest_name, device_id)
               VALUES (%s, NULL, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (session_id, swing_count, duration, mode,
             kendo_rank, experience_years, experience_months,
             guest_name, device_id)
        )

        return func.HttpResponse(
            json.dumps({"message": "Guest session created", "sessionId": session_id}),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating guest session: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
