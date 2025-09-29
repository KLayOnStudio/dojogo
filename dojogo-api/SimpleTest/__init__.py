import azure.functions as func
import json
import logging

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('SimpleTest function processed a request.')

    return func.HttpResponse(
        json.dumps({"status": "ok", "message": "Simple test working"}),
        status_code=200,
        headers={"Content-Type": "application/json"}
    )