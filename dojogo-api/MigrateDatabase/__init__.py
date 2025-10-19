import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import get_db_connection

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('MigrateDatabase function processed a request.')

    connection = None
    cursor = None

    try:
        # Get secret key from request (simple protection)
        req_body = req.get_json()
        secret = req_body.get('secret') if req_body else None

        if secret != 'migrate_dojogo_2025':
            return func.HttpResponse(
                json.dumps({"error": "Unauthorized"}),
                status_code=401,
                headers={"Content-Type": "application/json"}
            )

        connection = get_db_connection()
        cursor = connection.cursor()

        # Check which migrations need to be run
        migrations = []

        # Check user_number
        cursor.execute("SHOW COLUMNS FROM users LIKE 'user_number'")
        if not cursor.fetchone():
            migrations.append("ALTER TABLE users ADD COLUMN user_number INT AUTO_INCREMENT UNIQUE AFTER id")

        # Check nickname
        cursor.execute("SHOW COLUMNS FROM users LIKE 'nickname'")
        if not cursor.fetchone():
            migrations.append("ALTER TABLE users ADD COLUMN nickname VARCHAR(50) UNIQUE AFTER name")

        # Check nickname_last_changed
        cursor.execute("SHOW COLUMNS FROM users LIKE 'nickname_last_changed'")
        if not cursor.fetchone():
            migrations.append("ALTER TABLE users ADD COLUMN nickname_last_changed TIMESTAMP NULL AFTER nickname")

        # Check kendo_rank
        cursor.execute("SHOW COLUMNS FROM users LIKE 'kendo_rank'")
        if not cursor.fetchone():
            migrations.append("ALTER TABLE users ADD COLUMN kendo_rank VARCHAR(20) AFTER nickname_last_changed")

        # Check kendo_experience_years
        cursor.execute("SHOW COLUMNS FROM users LIKE 'kendo_experience_years'")
        if not cursor.fetchone():
            migrations.append("ALTER TABLE users ADD COLUMN kendo_experience_years INT DEFAULT 0 AFTER kendo_rank")

        # Check kendo_experience_months
        cursor.execute("SHOW COLUMNS FROM users LIKE 'kendo_experience_months'")
        if not cursor.fetchone():
            migrations.append("ALTER TABLE users ADD COLUMN kendo_experience_months INT DEFAULT 0 AFTER kendo_experience_years")

        # Check index
        cursor.execute("SHOW INDEX FROM users WHERE Key_name = 'idx_users_nickname'")
        if not cursor.fetchone():
            migrations.append("CREATE INDEX idx_users_nickname ON users(nickname)")

        if not migrations:
            return func.HttpResponse(
                json.dumps({"message": "All migrations already applied"}),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )

        for migration in migrations:
            logging.info(f"Executing: {migration}")
            cursor.execute(migration)
            connection.commit()

        return func.HttpResponse(
            json.dumps({"message": "Migration completed successfully"}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Migration error: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Migration failed: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
