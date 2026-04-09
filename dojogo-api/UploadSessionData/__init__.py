import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query

def main(req: func.HttpRequest) -> func.HttpResponse:
    """Upload raw IMU data and cue events for a session.

    No auth required — both authenticated and guest sessions use this.
    The session must already exist in the sessions table.
    """
    logging.info('UploadSessionData function processed a request.')

    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Invalid JSON body"}),
            status_code=400,
            headers={"Content-Type": "application/json"}
        )

    session_id = body.get("sessionId")
    imu_samples = body.get("imuSamples")
    cue_events = body.get("cueEvents")

    if not session_id:
        return func.HttpResponse(
            json.dumps({"error": "Missing required field: sessionId"}),
            status_code=400,
            headers={"Content-Type": "application/json"}
        )

    try:
        # Serialize to JSON strings for storage
        imu_json = json.dumps(imu_samples, separators=(',', ':')) if imu_samples else None
        cue_json = json.dumps(cue_events, separators=(',', ':')) if cue_events else None
        sample_count = len(imu_samples) if imu_samples else 0

        # Upsert: insert or replace if re-uploaded
        execute_query(
            """INSERT INTO session_data (session_id, imu_json, cue_events_json, sample_count)
               VALUES (%s, %s, %s, %s)
               ON DUPLICATE KEY UPDATE
               imu_json = VALUES(imu_json),
               cue_events_json = VALUES(cue_events_json),
               sample_count = VALUES(sample_count)""",
            (session_id, imu_json, cue_json, sample_count)
        )

        logging.info(f"Stored session data for {session_id}: {sample_count} IMU samples, {len(cue_events) if cue_events else 0} cue events")

        return func.HttpResponse(
            json.dumps({
                "message": "Session data uploaded",
                "sessionId": session_id,
                "sampleCount": sample_count
            }),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error uploading session data: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
