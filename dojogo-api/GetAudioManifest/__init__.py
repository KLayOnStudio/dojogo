import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetAudioManifest function processed a request.')

    try:
        rows = execute_query(
            "SELECT name, type, url, version FROM audio_assets WHERE is_active = TRUE ORDER BY type, name",
            fetch=True
        )

        assets = [
            {
                "name": r["name"],
                "type": r["type"],
                "url": r["url"],
                "version": r["version"]
            }
            for r in (rows or [])
        ]

        return func.HttpResponse(
            json.dumps({"assets": assets}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error fetching audio manifest: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
