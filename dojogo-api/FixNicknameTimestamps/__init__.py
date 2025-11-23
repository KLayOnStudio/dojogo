import logging
import json
import azure.functions as func
from datetime import datetime
from shared.database import get_db_connection

def main(req: func.HttpRequest) -> func.HttpResponse:
    """Fix nickname_last_changed timestamps that are in the future"""
    logging.info('FixNicknameTimestamps function triggered')

    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # First, check how many users have future timestamps
        cursor.execute(
            "SELECT COUNT(*) as count FROM users WHERE nickname_last_changed > NOW()"
        )
        before_count = cursor.fetchone()['count']
        logging.info(f"Found {before_count} users with future timestamps")

        # Get details of affected users
        cursor.execute(
            "SELECT id, name, nickname, nickname_last_changed, NOW() as server_time FROM users WHERE nickname_last_changed > NOW()"
        )
        affected_users = cursor.fetchall()

        # Fix the timestamps by setting them to NULL
        cursor.execute(
            "UPDATE users SET nickname_last_changed = NULL WHERE nickname_last_changed > NOW()"
        )
        conn.commit()

        # Verify the fix
        cursor.execute(
            "SELECT COUNT(*) as count FROM users WHERE nickname_last_changed > NOW()"
        )
        after_count = cursor.fetchone()['count']

        cursor.close()
        conn.close()

        return func.HttpResponse(
            json.dumps({
                "message": "Successfully fixed nickname timestamps",
                "usersFixed": before_count,
                "remainingIssues": after_count,
                "affectedUsers": [
                    {
                        "id": user['id'],
                        "name": user['name'],
                        "nickname": user['nickname'],
                        "oldTimestamp": str(user['nickname_last_changed']),
                        "currentTime": str(user['server_time'])
                    }
                    for user in affected_users
                ]
            }),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error fixing timestamps: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
