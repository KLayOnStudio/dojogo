import azure.functions as func
import json
import logging
import sys
import os
from datetime import date

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth


def calculate_max_streak(session_dates):
    """Given a list of date objects, return the longest consecutive-day streak."""
    if not session_dates:
        return 0
    unique = sorted(set(session_dates))
    max_s = cur = 1
    for i in range(1, len(unique)):
        if (unique[i] - unique[i - 1]).days == 1:
            cur += 1
            max_s = max(max_s, cur)
        else:
            cur = 1
    return max_s


def mask_nickname(nickname):
    """Show first and last letter, mask the rest: 'Klayon' → 'K****n'."""
    if not nickname:
        return "???"
    if len(nickname) <= 2:
        return nickname
    return nickname[0] + "*" * (len(nickname) - 2) + nickname[-1]


@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetCampaignLeaderboard function processed a request.')

    try:
        user_id = req.user_id
        campaign_id = req.params.get('campaignId')

        # Fetch campaign (by ID or most recent active/upcoming)
        if campaign_id:
            campaign_rows = execute_query(
                "SELECT id, name, description, rules, prize, prize_url, start_date, end_date, is_active "
                "FROM campaigns WHERE id = %s",
                (campaign_id,),
                fetch=True
            )
        else:
            campaign_rows = execute_query(
                "SELECT id, name, description, rules, prize, prize_url, start_date, end_date, is_active "
                "FROM campaigns WHERE is_active = TRUE ORDER BY start_date DESC LIMIT 1",
                fetch=True
            )

        if not campaign_rows:
            return func.HttpResponse(
                json.dumps({"error": "No campaign found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        c = campaign_rows[0]
        start = c['start_date']   # date object
        end = c['end_date']

        # Is requesting user a participant?
        is_participant_rows = execute_query(
            "SELECT 1 FROM campaign_members WHERE campaign_id = %s AND user_id = %s",
            (c['id'], user_id),
            fetch=True
        )
        is_participant = bool(is_participant_rows)

        # Requesting user's friendship state for nakama buttons
        friendships = execute_query(
            """SELECT CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END AS other_id
               FROM friendships WHERE user_id_a = %s OR user_id_b = %s""",
            (user_id, user_id, user_id),
            fetch=True
        )
        friend_ids = {r['other_id'] for r in (friendships or [])}

        sent_requests = execute_query(
            """SELECT to_user_id FROM friend_requests
               WHERE from_user_id = %s AND status = 'pending'""",
            (user_id,),
            fetch=True
        )
        pending_ids = {r['to_user_id'] for r in (sent_requests or [])}

        # Get all participants with user info
        participants = execute_query(
            """SELECT cm.user_id, u.nickname, u.user_number, u.kendo_rank, u.is_public
               FROM campaign_members cm
               JOIN users u ON u.id = cm.user_id
               WHERE cm.campaign_id = %s""",
            (c['id'],),
            fetch=True
        )

        def format_participant(p, rank=None, total_swings=0, max_streak=0, score=0):
            uid = p['user_id']
            is_own = uid == user_id
            is_public = bool(p.get('is_public', True))
            display_name = p['nickname'] if (is_public or is_own) else mask_nickname(p['nickname'])
            return {
                "rank": rank,
                "userId": uid,
                "nickname": display_name,
                "userNumber": int(p['user_number']) if p['user_number'] is not None else None,
                "kendoRank": p['kendo_rank'],
                "totalSwings": total_swings,
                "maxStreak": max_streak,
                "score": score,
                "isMe": is_own,
                "isFriend": uid in friend_ids,
                "isPending": uid in pending_ids,
            }

        entries = []

        if participants:
            today = date.today()
            campaign_started = today >= start

            if campaign_started:
                # Fetch sessions within campaign window for all participants
                participant_ids = [p['user_id'] for p in participants]
                placeholders = ','.join(['%s'] * len(participant_ids))
                sessions = execute_query(
                    f"""SELECT user_id, swing_count, DATE(created_at) AS session_date
                        FROM sessions
                        WHERE user_id IN ({placeholders})
                          AND DATE(created_at) >= %s
                          AND DATE(created_at) <= %s""",
                    tuple(participant_ids) + (start, end),
                    fetch=True
                )

                from collections import defaultdict
                swings_map = defaultdict(int)
                dates_map = defaultdict(list)
                for s in sessions:
                    uid = s['user_id']
                    swings_map[uid] += int(s['swing_count'] or 0)
                    dates_map[uid].append(s['session_date'])

                scored = []
                for p in participants:
                    uid = p['user_id']
                    total_swings = swings_map[uid]
                    max_streak = calculate_max_streak(dates_map[uid])
                    score = total_swings + (max_streak * 50)
                    scored.append((p, total_swings, max_streak, score))

                # Sort by score desc, then swings desc
                scored.sort(key=lambda x: (x[3], x[1]), reverse=True)

                for i, (p, total_swings, max_streak, score) in enumerate(scored):
                    entries.append(format_participant(p, rank=i + 1,
                                                     total_swings=total_swings,
                                                     max_streak=max_streak,
                                                     score=score))
            else:
                # Campaign not started yet — return participants without scores (rank=None)
                for p in participants:
                    entries.append(format_participant(p))

        campaign_data = {
            "id": int(c['id']),
            "name": c['name'],
            "description": c['description'],
            "rules": c['rules'],
            "prize": c['prize'],
            "prizeUrl": c['prize_url'],
            "startDate": start.isoformat() if hasattr(start, 'isoformat') else str(start),
            "endDate": end.isoformat() if hasattr(end, 'isoformat') else str(end),
            "isActive": bool(c['is_active']),
        }

        return func.HttpResponse(
            json.dumps({
                "campaign": campaign_data,
                "isParticipant": is_participant,
                "participantCount": len(participants),
                "entries": entries,
            }, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting campaign leaderboard: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
