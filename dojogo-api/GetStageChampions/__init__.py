import azure.functions as func
import json
import logging
import sys
import os
from collections import defaultdict

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query, datetime_to_timestamp
from auth import require_auth


@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetStageChampions function processed a request.')

    try:
        user_id = req.user_id

        sessions = execute_query(
            """SELECT stage_id, user_id, swing_count, created_at
               FROM sessions
               WHERE stage_id IS NOT NULL AND mode = 'guided'
               ORDER BY stage_id, created_at""",
            fetch=True
        ) or []

        by_stage = defaultdict(list)
        for s in sessions:
            by_stage[s['stage_id']].append(s)

        # For each stage, replay sessions chronologically to find running totals
        # AND when the current #1 most recently took the lead.
        stage_totals = {}
        stage_leader_since = {}
        for stage_id, stage_sessions in by_stage.items():
            totals = {}
            current_leader = None
            leader_since = None
            for s in stage_sessions:
                uid = s['user_id']
                totals[uid] = totals.get(uid, 0) + int(s['swing_count'] or 0)
                leader_candidate = max(totals, key=lambda k: totals[k])
                if leader_candidate != current_leader:
                    current_leader = leader_candidate
                    leader_since = s['created_at']
            stage_totals[stage_id] = totals
            stage_leader_since[stage_id] = leader_since

        all_user_ids = {uid for totals in stage_totals.values() for uid in totals}
        users_by_id = {}
        if all_user_ids:
            id_list = list(all_user_ids)
            placeholders = ','.join(['%s'] * len(id_list))
            user_rows = execute_query(
                f"SELECT id, nickname, user_number, is_public FROM users WHERE id IN ({placeholders})",
                tuple(id_list),
                fetch=True
            ) or []
            users_by_id = {u['id']: u for u in user_rows}

        def format_user(uid, total_swings, rank):
            u = users_by_id.get(uid, {})
            is_own = uid == user_id
            is_public = bool(u.get('is_public', True))
            nickname = u.get('nickname') if (is_public or is_own) else "???"
            return {
                "rank": rank,
                "userId": uid,
                "nickname": nickname,
                "userNumber": int(u['user_number']) if u.get('user_number') is not None else None,
                "totalSwings": total_swings
            }

        champions = {}
        for stage_id, totals in stage_totals.items():
            ranked = sorted(totals.items(), key=lambda kv: kv[1], reverse=True)[:3]
            top_swingers = [format_user(uid, total, i + 1) for i, (uid, total) in enumerate(ranked)]
            leader_since = stage_leader_since.get(stage_id)
            champions[str(stage_id)] = {
                "topSwingers": top_swingers,
                "leaderSince": datetime_to_timestamp(leader_since) if leader_since else None
            }

        return func.HttpResponse(
            json.dumps({"champions": champions}),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting stage champions: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
