import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import get_db_connection

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('UpdateUserId function processed a request.')

    connection = None
    cursor = None

    try:
        req_body = req.get_json()
        old_id = req_body.get('old_id')
        new_id = req_body.get('new_id')

        if not all([old_id, new_id]):
            return func.HttpResponse(
                json.dumps({"error": "Missing required fields: old_id, new_id"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Get a single connection for all operations
        connection = get_db_connection()
        cursor = connection.cursor()

        # Disable foreign key checks
        cursor.execute("SET FOREIGN_KEY_CHECKS=0")

        try:
            # Update all tables
            cursor.execute("UPDATE users SET id = %s WHERE id = %s", (new_id, old_id))
            cursor.execute("UPDATE sessions SET user_id = %s WHERE user_id = %s", (new_id, old_id))
            cursor.execute("UPDATE session_starts SET user_id = %s WHERE user_id = %s", (new_id, old_id))

            connection.commit()
        finally:
            # Re-enable foreign key checks
            cursor.execute("SET FOREIGN_KEY_CHECKS=1")
            connection.commit()

        return func.HttpResponse(
            json.dumps({"message": "User ID updated successfully"}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error updating user ID: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
