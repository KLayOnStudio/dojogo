import azure.functions as func
import json
import logging
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from azure.storage.blob import BlobServiceClient

CONTAINER_NAME = "session-imu"


def get_blob_client():
    conn_str = os.environ.get("AZURE_STORAGE_CONNECTION_STRING") or os.environ.get("AzureWebJobsStorage")
    if not conn_str:
        raise RuntimeError("No Azure Storage connection string found")
    return BlobServiceClient.from_connection_string(conn_str)


def upload_to_blob(session_id: str, payload: dict) -> str:
    """Upload session JSON to blob storage. Returns the blob URL."""
    client = get_blob_client()

    # Ensure container exists
    container = client.get_container_client(CONTAINER_NAME)
    try:
        container.get_container_properties()
    except Exception:
        container.create_container()

    blob_name = f"{session_id}.json"
    blob_client = container.get_blob_client(blob_name)

    json_bytes = json.dumps(payload, separators=(',', ':')).encode('utf-8')
    blob_client.upload_blob(json_bytes, overwrite=True)

    return blob_client.url


def main(req: func.HttpRequest) -> func.HttpResponse:
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
    device_model = body.get("deviceModel")
    sensor_mode = body.get("sensorMode")

    if not session_id:
        return func.HttpResponse(
            json.dumps({"error": "Missing required field: sessionId"}),
            status_code=400,
            headers={"Content-Type": "application/json"}
        )

    sample_count = len(imu_samples) if imu_samples else 0
    blob_url = None
    blob_error = None

    # Primary: upload to Azure Blob Storage
    try:
        payload = {
            "sessionId": session_id,
            "sensorMode": sensor_mode,
            "deviceModel": device_model,
            "imuSamples": imu_samples,
            "cueEvents": cue_events
        }
        blob_url = upload_to_blob(session_id, payload)
        logging.info(f"Blob upload succeeded for {session_id}: {blob_url}")
    except Exception as e:
        blob_error = str(e)
        logging.error(f"Blob upload failed for {session_id}: {e}")

    # Fallback: store JSON in DB (campaign backup, drop after migration)
    imu_json = json.dumps(imu_samples, separators=(',', ':')) if imu_samples else None
    cue_json = json.dumps(cue_events, separators=(',', ':')) if cue_events else None

    try:
        execute_query(
            """INSERT INTO session_data (session_id, blob_url, imu_json, cue_events_json, sample_count)
               VALUES (%s, %s, %s, %s, %s)
               ON DUPLICATE KEY UPDATE
                   blob_url = COALESCE(VALUES(blob_url), blob_url),
                   imu_json = VALUES(imu_json),
                   cue_events_json = VALUES(cue_events_json),
                   sample_count = VALUES(sample_count)""",
            (session_id, blob_url, imu_json, cue_json, sample_count)
        )
    except Exception as e:
        logging.error(f"DB insert failed for {session_id}: {e}")
        # If both blob and DB failed, return error
        if blob_url is None:
            return func.HttpResponse(
                json.dumps({"error": "Failed to store session data"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

    logging.info(f"Session data stored for {session_id}: {sample_count} samples, blob={'ok' if blob_url else 'failed'}")

    return func.HttpResponse(
        json.dumps({
            "message": "Session data uploaded",
            "sessionId": session_id,
            "sampleCount": sample_count,
            "blobUrl": blob_url,
            "blobError": blob_error
        }),
        status_code=201,
        headers={"Content-Type": "application/json"}
    )
