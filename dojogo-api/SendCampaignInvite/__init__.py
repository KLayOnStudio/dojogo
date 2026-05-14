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
    logging.info('SendCampaignInvite function processed a request.')

    try:
        user_id = req.user_id
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        campaign_id = req_body.get('campaignId')
        invitee_ids = req_body.get('userIds', [])

        if not campaign_id or not invitee_ids:
            return func.HttpResponse(
                json.dumps({"error": "campaignId and userIds are required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Verify sender is a participant
        is_participant = execute_query(
            "SELECT 1 FROM campaign_members WHERE campaign_id = %s AND user_id = %s",
            (campaign_id, user_id),
            fetch=True
        )
        if not is_participant:
            return func.HttpResponse(
                json.dumps({"error": "Only campaign participants can send invites"}),
                status_code=403,
                headers={"Content-Type": "application/json"}
            )

        # Get sender nickname
        sender = execute_query(
            "SELECT nickname FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )
        sender_name = sender[0]['nickname'] if sender and sender[0]['nickname'] else "A nakama"

        # Get campaign name
        campaign = execute_query(
            "SELECT name FROM campaigns WHERE id = %s",
            (campaign_id,),
            fetch=True
        )
        if not campaign:
            return func.HttpResponse(
                json.dumps({"error": "Campaign not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )
        campaign_name = campaign[0]['name']

        # Verify all invitees are nakama of sender
        placeholders = ','.join(['%s'] * len(invitee_ids))
        friendships = execute_query(
            f"""SELECT CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END AS friend_id
                FROM friendships
                WHERE (user_id_a = %s OR user_id_b = %s)
                  AND CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END IN ({placeholders})""",
            (user_id, user_id, user_id, user_id, *invitee_ids),
            fetch=True
        )
        valid_ids = {r['friend_id'] for r in (friendships or [])}

        # Filter to nakama not already in campaign
        sent = 0
        for uid in invitee_ids:
            if uid not in valid_ids:
                continue
            already_in = execute_query(
                "SELECT 1 FROM campaign_members WHERE campaign_id = %s AND user_id = %s",
                (campaign_id, uid),
                fetch=True
            )
            if already_in:
                continue
            # Avoid duplicate invites
            already_notified = execute_query(
                """SELECT 1 FROM notifications
                   WHERE user_id = %s AND type = 'campaign_invite'
                     AND JSON_EXTRACT(data, '$.campaignId') = %s
                     AND JSON_EXTRACT(data, '$.fromUserId') = %s""",
                (uid, campaign_id, user_id),
                fetch=True
            )
            if already_notified:
                continue

            execute_query(
                """INSERT INTO notifications (user_id, type, title, body, data)
                   VALUES (%s, 'campaign_invite', %s, %s, %s)""",
                (
                    uid,
                    f"{sender_name} invited you!",
                    f"Join the {campaign_name} challenge",
                    json.dumps({"campaignId": campaign_id, "fromUserId": user_id})
                )
            )
            sent += 1

        return func.HttpResponse(
            json.dumps({"message": f"Sent {sent} invite(s)", "sent": sent}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error sending campaign invite: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
