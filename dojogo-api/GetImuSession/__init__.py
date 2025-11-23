import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetImuSession function processed a request.')

    try:
        # Get imu_session_id from route
        imu_session_id = req.route_params.get('imu_session_id')

        if imu_session_id:
            # Get single session
            return get_single_session(req, int(imu_session_id))
        else:
            # List sessions
            return list_sessions(req)

    except Exception as e:
        logging.error(f"Error getting IMU session: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )


def get_single_session(req: func.HttpRequest, imu_session_id: int) -> func.HttpResponse:
    """Get details for a specific IMU session including files"""
    user_id = req.user_id

    # Get session details
    session = execute_query(
        """
        SELECT
            ims.imu_session_id,
            ims.user_id,
            ims.device_id,
            ims.start_time_utc,
            ims.end_time_utc,
            ims.nominal_hz,
            ims.coord_frame,
            ims.gravity_removed,
            ims.notes,
            ims.action_type,
            ims.created_at,
            d.platform,
            d.model,
            d.os_version
        FROM imu_sessions ims
        LEFT JOIN devices d ON ims.device_id = d.device_id
        WHERE ims.imu_session_id = %s
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

    # Get associated files
    files = execute_query(
        """
        SELECT
            file_id,
            purpose,
            storage_url,
            content_type,
            bytes_size,
            sha256_hex,
            num_samples,
            created_at
        FROM imu_session_files
        WHERE imu_session_id = %s
        ORDER BY purpose, created_at
        """,
        (imu_session_id,),
        fetch=True
    )

    # Build response
    response = {
        "imu_session_id": session_data['imu_session_id'],
        "user_id": session_data['user_id'],
        "device_id": session_data['device_id'],
        "start_time_utc": session_data['start_time_utc'].isoformat() + 'Z',
        "end_time_utc": session_data['end_time_utc'].isoformat() + 'Z' if session_data['end_time_utc'] else None,
        "nominal_hz": float(session_data['nominal_hz']) if session_data['nominal_hz'] else None,
        "coord_frame": session_data['coord_frame'],
        "gravity_removed": bool(session_data['gravity_removed']),
        "notes": session_data['notes'],
        "action_type": session_data.get('action_type'),
        "created_at": session_data['created_at'].isoformat() + 'Z',
        "device": {
            "platform": session_data['platform'],
            "model": session_data['model'],
            "os_version": session_data['os_version']
        },
        "files": [
            {
                "file_id": f['file_id'],
                "purpose": f['purpose'],
                "storage_url": f['storage_url'],
                "content_type": f['content_type'],
                "bytes_size": f['bytes_size'],
                "sha256_hex": f['sha256_hex'],
                "num_samples": f['num_samples'],
                "created_at": f['created_at'].isoformat() + 'Z'
            }
            for f in (files or [])
        ]
    }

    return func.HttpResponse(
        json.dumps(response, default=str),
        status_code=200,
        headers={"Content-Type": "application/json"}
    )


def list_sessions(req: func.HttpRequest) -> func.HttpResponse:
    """List all IMU sessions for the authenticated user"""
    user_id = req.user_id

    # Get query parameters
    limit = int(req.params.get('limit', 50))
    offset = int(req.params.get('offset', 0))

    # Validate limits
    if limit > 100:
        limit = 100
    if limit < 1:
        limit = 1
    if offset < 0:
        offset = 0

    # Get total count
    count_result = execute_query(
        "SELECT COUNT(*) as total FROM imu_sessions WHERE user_id = %s",
        (user_id,),
        fetch=True
    )
    total = count_result[0]['total'] if count_result else 0

    # Get sessions
    sessions = execute_query(
        """
        SELECT
            ims.imu_session_id,
            ims.user_id,
            ims.device_id,
            ims.start_time_utc,
            ims.end_time_utc,
            ims.nominal_hz,
            ims.coord_frame,
            ims.action_type,
            ims.created_at,
            d.platform,
            d.model
        FROM imu_sessions ims
        LEFT JOIN devices d ON ims.device_id = d.device_id
        WHERE ims.user_id = %s
        ORDER BY ims.start_time_utc DESC
        LIMIT %s OFFSET %s
        """,
        (user_id, limit, offset),
        fetch=True
    )

    # Build response
    response = {
        "sessions": [
            {
                "imu_session_id": s['imu_session_id'],
                "user_id": s['user_id'],
                "device_id": s['device_id'],
                "start_time_utc": s['start_time_utc'].isoformat() + 'Z',
                "end_time_utc": s['end_time_utc'].isoformat() + 'Z' if s['end_time_utc'] else None,
                "nominal_hz": float(s['nominal_hz']) if s['nominal_hz'] else None,
                "coord_frame": s['coord_frame'],
                "action_type": s.get('action_type'),
                "created_at": s['created_at'].isoformat() + 'Z',
                "device": {
                    "platform": s['platform'],
                    "model": s['model']
                }
            }
            for s in (sessions or [])
        ],
        "total": total,
        "limit": limit,
        "offset": offset
    }

    return func.HttpResponse(
        json.dumps(response, default=str),
        status_code=200,
        headers={"Content-Type": "application/json"}
    )
