import azure.functions as func
import json
import logging
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query

def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Returns all unique dojo names from the database.
    No auth required - this is public data for autocomplete.
    """
    logging.info('GetDojoNames function processed a request.')

    try:
        # Get all unique non-null dojo names, ordered alphabetically
        result = execute_query(
            "SELECT DISTINCT home_dojo FROM users WHERE home_dojo IS NOT NULL AND home_dojo != '' ORDER BY home_dojo",
            fetch=True
        )

        dojo_names = [row.get("home_dojo") for row in result if row.get("home_dojo")]

        return func.HttpResponse(
            json.dumps({"dojos": dojo_names}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting dojo names: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
