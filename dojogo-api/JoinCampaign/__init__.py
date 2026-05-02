import azure.functions as func
import json
import logging
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('JoinCampaign function processed a request.')

    try:
        user_id = req.user_id

        try:
            body = req.get_json()
        except Exception:
            body = {}

        campaign_id = body.get('campaignId')
        if not campaign_id:
            return func.HttpResponse(
                json.dumps({"error": "campaignId is required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Verify campaign exists and is joinable
        campaigns = execute_query(
            "SELECT id, start_date, end_date, is_active FROM campaigns WHERE id = %s",
            (campaign_id,),
            fetch=True
        )
        if not campaigns:
            return func.HttpResponse(
                json.dumps({"error": "Campaign not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        campaign = campaigns[0]
        if not campaign['is_active']:
            return func.HttpResponse(
                json.dumps({"error": "Campaign is not active"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check if already joined
        existing = execute_query(
            "SELECT 1 FROM campaign_members WHERE campaign_id = %s AND user_id = %s",
            (campaign_id, user_id),
            fetch=True
        )
        if existing:
            return func.HttpResponse(
                json.dumps({"success": True, "alreadyJoined": True}),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )

        # Insert membership
        execute_query(
            "INSERT INTO campaign_members (campaign_id, user_id) VALUES (%s, %s)",
            (campaign_id, user_id)
        )

        return func.HttpResponse(
            json.dumps({"success": True, "alreadyJoined": False}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error joining campaign: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
