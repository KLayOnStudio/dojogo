import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime, timedelta
from azure.storage.blob import BlobServiceClient, generate_container_sas, ContainerSasPermissions

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateImuSession function processed a request.')

    try:
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id  # From auth decorator

        # Extract required fields
        client_upload_id = req_body.get('client_upload_id')
        device_info = req_body.get('device_info', {})
        start_time_utc = req_body.get('start_time_utc')
        nominal_hz = req_body.get('nominal_hz')
        coord_frame = req_body.get('coord_frame', 'device')
        notes = req_body.get('notes')
        game_session_id = req_body.get('game_session_id')  # Optional link to tap-game session
        action_type = req_body.get('action_type')  # Optional: type of swing/suburi (men, kote, do, etc.)

        # Validate required fields
        if not client_upload_id:
            return func.HttpResponse(
                json.dumps({"error": "client_upload_id is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        if not device_info or not device_info.get('platform'):
            return func.HttpResponse(
                json.dumps({"error": "device_info.platform is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        if not start_time_utc:
            return func.HttpResponse(
                json.dumps({"error": "start_time_utc is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Validate platform enum
        valid_platforms = ['ios', 'android', 'switch', 'other']
        if device_info['platform'] not in valid_platforms:
            return func.HttpResponse(
                json.dumps({"error": f"Invalid platform. Must be one of: {', '.join(valid_platforms)}"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Validate coord_frame enum
        if coord_frame not in ['device', 'world']:
            return func.HttpResponse(
                json.dumps({"error": "coord_frame must be 'device' or 'world'"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Parse start_time_utc
        try:
            start_dt = datetime.fromisoformat(start_time_utc.replace('Z', '+00:00'))
        except ValueError as e:
            return func.HttpResponse(
                json.dumps({"error": f"Invalid start_time_utc format: {str(e)}"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # ===================================================================
        # Step 1: Upsert device
        # ===================================================================
        platform = device_info['platform']
        model = device_info.get('model')
        os_version = device_info.get('os_version')
        app_version = device_info.get('app_version')
        hw_id = device_info.get('hw_id', 'unknown')

        # Check if device exists
        existing_device = execute_query(
            """
            SELECT device_id FROM devices
            WHERE user_id = %s AND hw_id = %s
            """,
            (user_id, hw_id),
            fetch=True
        )

        if existing_device and existing_device[0]:
            device_id = existing_device[0]['device_id']
            logging.info(f"Using existing device_id: {device_id}")

            # Update device info (in case OS/app version changed)
            execute_query(
                """
                UPDATE devices
                SET platform = %s, model = %s, os_version = %s, app_version = %s
                WHERE device_id = %s
                """,
                (platform, model, os_version, app_version, device_id)
            )
        else:
            # Insert new device
            execute_query(
                """
                INSERT INTO devices (user_id, platform, model, os_version, app_version, hw_id)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (user_id, platform, model, os_version, app_version, hw_id)
            )

            # Get the new device_id
            new_device = execute_query(
                "SELECT device_id FROM devices WHERE user_id = %s AND hw_id = %s",
                (user_id, hw_id),
                fetch=True
            )
            device_id = new_device[0]['device_id']
            logging.info(f"Created new device_id: {device_id}")

        # ===================================================================
        # Step 2: Check for existing session (idempotency)
        # ===================================================================
        existing_session = execute_query(
            """
            SELECT ims.imu_session_id, ims.start_time_utc, ims.nominal_hz, ims.coord_frame, ims.game_session_id, ims.action_type
            FROM imu_sessions ims
            JOIN imu_client_uploads icu ON ims.imu_session_id = icu.imu_session_id
            WHERE ims.user_id = %s AND icu.client_upload_id = %s
            """,
            (user_id, client_upload_id),
            fetch=True
        )

        if existing_session and existing_session[0]:
            # Return existing session (idempotent)
            session = existing_session[0]
            imu_session_id = session['imu_session_id']
            logging.info(f"Returning existing session (idempotent): {imu_session_id}")
            status_code = 200
        else:
            # ===================================================================
            # Step 3: Create new IMU session
            # ===================================================================
            execute_query(
                """
                INSERT INTO imu_sessions
                (user_id, device_id, start_time_utc, nominal_hz, coord_frame, notes, game_session_id, action_type)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (user_id, device_id, start_dt, nominal_hz, coord_frame, notes, game_session_id, action_type)
            )

            # Get the new session ID
            new_session = execute_query(
                """
                SELECT imu_session_id, start_time_utc, nominal_hz, coord_frame, game_session_id, action_type
                FROM imu_sessions
                WHERE user_id = %s AND device_id = %s AND start_time_utc = %s
                ORDER BY imu_session_id DESC LIMIT 1
                """,
                (user_id, device_id, start_dt),
                fetch=True
            )

            session = new_session[0]
            imu_session_id = session['imu_session_id']
            logging.info(f"Created new IMU session: {imu_session_id}")

            # Insert into idempotency ledger
            execute_query(
                """
                INSERT INTO imu_client_uploads (imu_session_id, client_upload_id)
                VALUES (%s, %s)
                """,
                (imu_session_id, client_upload_id)
            )

            status_code = 201

        # ===================================================================
        # Step 4: Generate SAS token for blob upload
        # ===================================================================
        blob_connection_string = os.environ.get('AZURE_STORAGE_CONNECTION_STRING')
        if not blob_connection_string:
            logging.error("AZURE_STORAGE_CONNECTION_STRING not configured")
            return func.HttpResponse(
                json.dumps({"error": "Blob storage not configured"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

        try:
            blob_service_client = BlobServiceClient.from_connection_string(blob_connection_string)
            container_name = "imu-alpha"

            # Ensure container exists
            container_client = blob_service_client.get_container_client(container_name)
            try:
                container_client.get_container_properties()
            except Exception:
                # Container doesn't exist, create it
                container_client.create_container()
                logging.info(f"Created container: {container_name}")

            # Generate SAS token (valid for 2 hours, write + list permissions)
            sas_expiry = datetime.utcnow() + timedelta(hours=2)

            # Get account name and key from connection string
            conn_parts = dict(item.split('=', 1) for item in blob_connection_string.split(';') if '=' in item)
            account_name = conn_parts.get('AccountName')
            account_key = conn_parts.get('AccountKey')

            sas_token = generate_container_sas(
                account_name=account_name,
                container_name=container_name,
                account_key=account_key,
                permission=ContainerSasPermissions(write=True, list=True, read=True),
                expiry=sas_expiry
            )

            session_path = f"users/{user_id}/sessions/{imu_session_id}/"
            # Return base container URL with SAS, client will construct full blob path
            sas_url_base = f"https://{account_name}.blob.core.windows.net/{container_name}/{session_path}"
            sas_url = sas_url_base if not sas_url_base.endswith('?') else sas_url_base
            # Add SAS token as query parameter
            sas_url = f"{sas_url_base}?{sas_token}"

        except Exception as e:
            logging.error(f"Failed to generate SAS token: {e}")
            return func.HttpResponse(
                json.dumps({"error": f"Failed to generate SAS token: {str(e)}"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

        # ===================================================================
        # Step 5: Build response
        # ===================================================================
        response = {
            "imu_session_id": imu_session_id,
            "user_id": user_id,
            "device_id": device_id,
            "start_time_utc": session['start_time_utc'].isoformat() + 'Z',
            "nominal_hz": float(session['nominal_hz']) if session['nominal_hz'] else None,
            "coord_frame": session['coord_frame'],
            "game_session_id": session.get('game_session_id'),  # Optional link
            "action_type": session.get('action_type'),  # Optional: swing/suburi type
            "sas_token": {
                "container": container_name,
                "path": session_path,
                "sas_url": sas_url,
                "expires_at": sas_expiry.isoformat() + 'Z'
            }
        }

        return func.HttpResponse(
            json.dumps(response, default=str),
            status_code=status_code,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating IMU session: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
