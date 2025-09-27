import azure.functions as func
import json
import logging
import os

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('TestHealth function processed a request.')

    try:
        # Test 1: Basic function works
        result = {"status": "ok", "message": "Function is running"}

        # Test 2: Environment variables
        result["env_vars"] = {
            "DB_HOST": os.environ.get('DB_HOST', 'NOT_SET'),
            "DB_USER": os.environ.get('DB_USER', 'NOT_SET'),
            "DB_NAME": os.environ.get('DB_NAME', 'NOT_SET'),
            "DB_PORT": os.environ.get('DB_PORT', 'NOT_SET')
        }

        # Test 3: Try importing mysql connector
        try:
            import mysql.connector
            result["mysql_import"] = "success"
        except Exception as e:
            result["mysql_import"] = f"failed: {str(e)}"

        # Test 4: Try database connection and show tables
        try:
            import mysql.connector
            connection = mysql.connector.connect(
                host=os.environ.get('DB_HOST'),
                user=os.environ.get('DB_USER'),
                password=os.environ.get('DB_PASSWORD'),
                database=os.environ.get('DB_NAME'),
                port=int(os.environ.get('DB_PORT', 3306)),
                ssl_disabled=False,
                connect_timeout=10
            )

            cursor = connection.cursor()
            cursor.execute("SHOW TABLES")
            tables = [table[0] for table in cursor.fetchall()]
            cursor.close()
            connection.close()

            result["db_connection"] = "success"
            result["tables"] = tables
        except Exception as e:
            result["db_connection"] = f"failed: {str(e)}"

        return func.HttpResponse(
            json.dumps(result, indent=2),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"TestHealth error: {e}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )