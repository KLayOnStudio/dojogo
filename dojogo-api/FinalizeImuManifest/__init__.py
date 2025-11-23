import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime
from azure.storage.blob import BlobServiceClient

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('FinalizeImuManifest function processed a request.')

    try:
        # Get imu_session_id from route
        imu_session_id = req.route_params.get('imu_session_id')
        if not imu_session_id:
            return func.HttpResponse(
                json.dumps({"error": "imu_session_id path parameter required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        try:
            imu_session_id = int(imu_session_id)
        except ValueError:
            return func.HttpResponse(
                json.dumps({"error": "imu_session_id must be a valid integer"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id  # From auth decorator

        # Extract fields
        end_time_utc = req_body.get('end_time_utc')
        files = req_body.get('files', [])
        rate_stats = req_body.get('rate_stats')  # Optional: actual sampling rate metrics

        # Validate required fields
        if not end_time_utc:
            return func.HttpResponse(
                json.dumps({"error": "end_time_utc is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Files array is optional - empty is allowed for sessions with no data
        if files is None:
            files = []

        # Parse end_time_utc
        try:
            end_dt = datetime.fromisoformat(end_time_utc.replace('Z', '+00:00'))
        except ValueError as e:
            return func.HttpResponse(
                json.dumps({"error": f"Invalid end_time_utc format: {str(e)}"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # ===================================================================
        # Step 1: Verify session exists and belongs to user
        # ===================================================================
        session = execute_query(
            """
            SELECT imu_session_id, user_id, start_time_utc, end_time_utc
            FROM imu_sessions
            WHERE imu_session_id = %s
            """,
            (imu_session_id,),
            fetch=True
        )

        if not session or not session[0]:
            return func.HttpResponse(
                json.dumps({"error": "IMU session not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        session_data = session[0]

        # Verify user owns this session
        if session_data['user_id'] != user_id:
            return func.HttpResponse(
                json.dumps({"error": "Unauthorized: session belongs to different user"}),
                status_code=403,
                headers={"Content-Type": "application/json"}
            )

        # Check if already finalized (idempotency check)
        if session_data['end_time_utc'] is not None:
            # Already finalized - return existing file totals
            existing_files = execute_query(
                """
                SELECT COUNT(*) as total_files,
                       SUM(bytes_size) as total_bytes,
                       SUM(num_samples) as total_samples
                FROM imu_session_files
                WHERE imu_session_id = %s
                """,
                (imu_session_id,),
                fetch=True
            )

            totals = existing_files[0] if existing_files else {}

            logging.info(f"Session {imu_session_id} already finalized (idempotent)")
            return func.HttpResponse(
                json.dumps({
                    "message": "Manifest already finalized (idempotent)",
                    "imu_session_id": imu_session_id,
                    "total_files": totals.get('total_files', 0),
                    "total_bytes": totals.get('total_bytes', 0),
                    "total_samples": totals.get('total_samples', 0),
                    "end_time_utc": session_data['end_time_utc'].isoformat() + 'Z'
                }, default=str),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )

        # ===================================================================
        # Step 2: Verify blobs exist in Azure Storage
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
            container_client = blob_service_client.get_container_client(container_name)

            session_path = f"users/{user_id}/sessions/{imu_session_id}/"

            # Verify each file exists
            missing_files = []
            for file_info in files:
                filename = file_info.get('filename')
                if not filename:
                    return func.HttpResponse(
                        json.dumps({"error": "Each file must have a 'filename' field"}),
                        status_code=400,
                        headers={"Content-Type": "application/json"}
                    )

                blob_path = session_path + filename
                blob_client = container_client.get_blob_client(blob_path)

                try:
                    blob_properties = blob_client.get_blob_properties()

                    # Verify file size matches
                    actual_size = blob_properties.size
                    claimed_size = file_info.get('bytes_size')

                    if claimed_size and actual_size != claimed_size:
                        return func.HttpResponse(
                            json.dumps({
                                "error": f"File size mismatch for {filename}: claimed {claimed_size}, actual {actual_size}"
                            }),
                            status_code=400,
                            headers={"Content-Type": "application/json"}
                        )

                except Exception as e:
                    missing_files.append(filename)
                    logging.warning(f"Blob not found: {blob_path} - {e}")

            if missing_files:
                return func.HttpResponse(
                    json.dumps({
                        "error": "Some files not found in blob storage",
                        "missing_files": missing_files
                    }),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )

        except Exception as e:
            logging.error(f"Failed to verify blobs: {e}")
            return func.HttpResponse(
                json.dumps({"error": f"Failed to verify blobs: {str(e)}"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

        # ===================================================================
        # Step 3: Register files in database (idempotent upsert)
        # ===================================================================
        total_bytes = 0
        total_samples = 0

        for file_info in files:
            purpose = file_info.get('purpose')
            filename = file_info.get('filename')
            sha256_hex = file_info.get('sha256_hex')
            bytes_size = file_info.get('bytes_size', 0)
            num_samples = file_info.get('num_samples')
            content_type = file_info.get('content_type')

            # Validate purpose enum
            if purpose not in ['raw', 'manifest', 'device', 'calib', 'events']:
                return func.HttpResponse(
                    json.dumps({"error": f"Invalid purpose '{purpose}' for file {filename}"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )

            # Validate sha256_hex format
            if sha256_hex and len(sha256_hex) != 64:
                return func.HttpResponse(
                    json.dumps({"error": f"Invalid SHA-256 checksum for {filename}: must be 64 hex characters"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )

            storage_url = session_path + filename

            # Check if file already registered (idempotency)
            existing_file = execute_query(
                """
                SELECT file_id FROM imu_session_files
                WHERE imu_session_id = %s AND purpose = %s AND storage_url = %s
                """,
                (imu_session_id, purpose, storage_url),
                fetch=True
            )

            if not existing_file or not existing_file[0]:
                # Insert new file record
                execute_query(
                    """
                    INSERT INTO imu_session_files
                    (imu_session_id, purpose, storage_url, content_type, bytes_size, sha256_hex, num_samples)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """,
                    (imu_session_id, purpose, storage_url, content_type, bytes_size, sha256_hex, num_samples)
                )
                logging.info(f"Registered file: {filename} ({purpose})")

            total_bytes += bytes_size
            if num_samples:
                total_samples += num_samples

        # ===================================================================
        # Step 4: Update session end_time_utc and actual_mean_hz
        # ===================================================================
        actual_mean_hz = None
        if rate_stats:
            actual_mean_hz = rate_stats.get('mean_hz')

        execute_query(
            """
            UPDATE imu_sessions
            SET end_time_utc = %s, actual_mean_hz = %s
            WHERE imu_session_id = %s
            """,
            (end_dt, actual_mean_hz, imu_session_id)
        )

        # ===================================================================
        # Step 5: Store rate_stats (if provided)
        # ===================================================================
        if rate_stats:
            # Validate rate_stats structure
            samples_total = rate_stats.get('samples_total')
            duration_ms = rate_stats.get('duration_ms')
            mean_hz = rate_stats.get('mean_hz')

            if not all([samples_total, duration_ms, mean_hz]):
                logging.warning(f"Incomplete rate_stats for session {imu_session_id}, skipping stats insert")
            else:
                # Check if stats already exist (idempotency)
                existing_stats = execute_query(
                    "SELECT imu_session_id FROM imu_session_stats WHERE imu_session_id = %s",
                    (imu_session_id,),
                    fetch=True
                )

                if not existing_stats or not existing_stats[0]:
                    # Insert new stats
                    execute_query(
                        """
                        INSERT INTO imu_session_stats
                        (imu_session_id, samples_total, duration_ms, mean_hz, dt_ms_p50, dt_ms_p95, dt_ms_max, dropped_seq_pct)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                        """,
                        (
                            imu_session_id,
                            samples_total,
                            duration_ms,
                            mean_hz,
                            rate_stats.get('dt_ms_p50'),
                            rate_stats.get('dt_ms_p95'),
                            rate_stats.get('dt_ms_max'),
                            rate_stats.get('dropped_seq_pct')
                        )
                    )
                    logging.info(f"Stored rate_stats for session {imu_session_id}: {mean_hz:.2f} Hz actual")
                else:
                    logging.info(f"Rate_stats already exist for session {imu_session_id} (idempotent)")

        logging.info(f"Finalized IMU session {imu_session_id}: {len(files)} files, {total_bytes} bytes, {total_samples} samples")

        # ===================================================================
        # Step 6: Build response
        # ===================================================================
        response = {
            "message": "Manifest finalized successfully",
            "imu_session_id": imu_session_id,
            "total_files": len(files),
            "total_bytes": total_bytes,
            "total_samples": total_samples,
            "end_time_utc": end_dt.isoformat() + 'Z'
        }

        return func.HttpResponse(
            json.dumps(response, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error finalizing manifest: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
