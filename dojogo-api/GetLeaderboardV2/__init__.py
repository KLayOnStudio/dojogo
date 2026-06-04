import azure.functions as func
import json
import logging
import math
import sys
import os
from collections import defaultdict
from datetime import date

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

STREAK_START_DATE = '2026-06-01'


def calculate_current_streak(session_dates):
    """Return the current consecutive-day streak ending today or yesterday."""
    if not session_dates:
        return 0
    today = date.today()
    unique = sorted(set(session_dates), reverse=True)
    if (today - unique[0]).days > 1:
        return 0
    streak = 1
    for i in range(1, len(unique)):
        if (unique[i - 1] - unique[i]).days == 1:
            streak += 1
        else:
            break
    return streak


def mask_nickname(nickname):
    if not nickname:
        return "???"
    if len(nickname) <= 2:
        return nickname
    return nickname[0] + "*" * (len(nickname) - 2) + nickname[-1]


def build_streak_leaderboard(user_rows, requesting_user_id, page, page_size):
    """Fetch session dates and compute live streaks for the given user rows."""
    if not user_rows:
        return [], None, 0

    user_ids = [u['user_id'] for u in user_rows]
    placeholders = ','.join(['%s'] * len(user_ids))

    sessions = execute_query(
        f"""SELECT user_id, DATE(created_at) AS session_date
            FROM sessions
            WHERE user_id IN ({placeholders})
              AND DATE(created_at) >= %s""",
        tuple(user_ids) + (STREAK_START_DATE,),
        fetch=True
    )

    dates_map = defaultdict(list)
    for s in sessions or []:
        dates_map[s['user_id']].append(s['session_date'])

    scored = []
    for u in user_rows:
        uid = u['user_id']
        streak = calculate_current_streak(dates_map[uid])
        if streak > 0:
            scored.append((u, streak))

    scored.sort(key=lambda x: x[1], reverse=True)
    total_count = len(scored)

    # Assign ranks (1-indexed, tied scores share rank)
    ranked = []
    for i, (u, streak) in enumerate(scored):
        ranked.append((u, streak, i + 1))

    # Find requesting user's entry
    my_entry = next(
        ({"user_id": u['user_id'], "nickname": u['nickname'], "user_number": u['user_number'],
          "score": streak, "rank": rank, "is_public": u.get('is_public', True)}
         for u, streak, rank in ranked if u['user_id'] == requesting_user_id),
        None
    )

    offset = (page - 1) * page_size
    page_slice = ranked[offset:offset + page_size]

    entries = [
        {"user_id": u['user_id'], "nickname": u['nickname'], "user_number": u['user_number'],
         "score": streak, "rank": rank, "is_public": u.get('is_public', True)}
        for u, streak, rank in page_slice
    ]

    return entries, my_entry, total_count


@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetLeaderboardV2 function processed a request.')

    try:
        user_id = req.user_id
        metric = req.params.get('metric', 'swings')
        scope = req.params.get('scope', 'global')
        page = max(int(req.params.get('page', 1)), 1)
        page_size = min(max(int(req.params.get('pageSize', 20)), 1), 50)

        if metric not in ('swings', 'streak'):
            return func.HttpResponse(
                json.dumps({"error": "metric must be 'swings' or 'streak'"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        if scope not in ('global', 'friends'):
            return func.HttpResponse(
                json.dumps({"error": "scope must be 'global' or 'friends'"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        requesting_user_id = user_id
        offset = (page - 1) * page_size

        def format_entry(row):
            is_own = row["user_id"] == requesting_user_id
            is_public = bool(row.get("is_public", True))
            nickname = row["nickname"] if (is_public or is_own) else mask_nickname(row["nickname"])
            return {
                "userId": row["user_id"],
                "nickname": nickname,
                "userNumber": int(row["user_number"]) if row["user_number"] is not None else None,
                "score": int(row["score"]) if row["score"] is not None else 0,
                "rank": int(row["rank"])
            }

        # ── STREAK: compute live from session dates ──────────────────────────
        if metric == 'streak':
            if scope == 'global':
                all_users = execute_query(
                    "SELECT id as user_id, nickname, user_number, is_public FROM users",
                    fetch=True
                ) or []
            else:
                all_users = execute_query(
                    """SELECT u.id as user_id, u.nickname, u.user_number, u.is_public
                       FROM users u
                       WHERE u.id = %s
                         OR u.id IN (
                             SELECT CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END
                             FROM friendships
                             WHERE user_id_a = %s OR user_id_b = %s
                         )""",
                    (user_id, user_id, user_id, user_id),
                    fetch=True
                ) or []

            entries_raw, my_entry_raw, total_count = build_streak_leaderboard(
                all_users, requesting_user_id, page, page_size
            )
            total_pages = math.ceil(total_count / page_size) if total_count > 0 else 1

            return func.HttpResponse(
                json.dumps({
                    "metric": metric,
                    "scope": scope,
                    "top": [format_entry(r) for r in entries_raw],
                    "me": format_entry(my_entry_raw) if my_entry_raw else None,
                    "aroundMe": [],
                    "page": page,
                    "pageSize": page_size,
                    "totalCount": total_count,
                    "totalPages": total_pages
                }, default=str),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )

        # ── SWINGS: use total_count column (unchanged) ───────────────────────
        col = 'total_count'

        if scope == 'global':
            count_row = execute_query(
                f"SELECT COUNT(*) as cnt FROM users WHERE {col} > 0",
                fetch=True
            )
            total_count = count_row[0]['cnt'] if count_row else 0

            entries = execute_query(
                f"""SELECT id as user_id, nickname, user_number, {col} as score, is_public,
                           RANK() OVER (ORDER BY {col} DESC) as `rank`
                    FROM users
                    WHERE {col} > 0
                    ORDER BY `rank` ASC
                    LIMIT %s OFFSET %s""",
                (page_size, offset),
                fetch=True
            )

            me_rows = execute_query(
                f"""SELECT user_id, nickname, user_number, score, is_public, `rank` FROM (
                        SELECT id as user_id, nickname, user_number, {col} as score, is_public,
                               RANK() OVER (ORDER BY {col} DESC) as `rank`
                        FROM users
                        WHERE {col} > 0
                    ) ranked
                    WHERE user_id = %s""",
                (user_id,),
                fetch=True
            )
        else:
            count_row = execute_query(
                f"""SELECT COUNT(*) as cnt FROM users u
                    WHERE u.{col} > 0
                    AND (
                        u.id = %s
                        OR u.id IN (
                            SELECT CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END
                            FROM friendships
                            WHERE user_id_a = %s OR user_id_b = %s
                        )
                    )""",
                (user_id, user_id, user_id, user_id),
                fetch=True
            )
            total_count = count_row[0]['cnt'] if count_row else 0

            entries = execute_query(
                f"""SELECT u.id as user_id, u.nickname, u.user_number, u.{col} as score, u.is_public,
                           RANK() OVER (ORDER BY u.{col} DESC) as `rank`
                    FROM users u
                    WHERE u.{col} > 0
                    AND (
                        u.id = %s
                        OR u.id IN (
                            SELECT CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END
                            FROM friendships
                            WHERE user_id_a = %s OR user_id_b = %s
                        )
                    )
                    ORDER BY `rank` ASC
                    LIMIT %s OFFSET %s""",
                (user_id, user_id, user_id, user_id, page_size, offset),
                fetch=True
            )

            me_rows = execute_query(
                f"""SELECT user_id, nickname, user_number, score, is_public, `rank` FROM (
                        SELECT u.id as user_id, u.nickname, u.user_number, u.{col} as score, u.is_public,
                               RANK() OVER (ORDER BY u.{col} DESC) as `rank`
                        FROM users u
                        WHERE u.{col} > 0
                        AND (
                            u.id = %s
                            OR u.id IN (
                                SELECT CASE WHEN user_id_a = %s THEN user_id_b ELSE user_id_a END
                                FROM friendships
                                WHERE user_id_a = %s OR user_id_b = %s
                            )
                        )
                    ) ranked
                    WHERE user_id = %s""",
                (user_id, user_id, user_id, user_id, user_id),
                fetch=True
            )

        total_pages = math.ceil(total_count / page_size) if total_count > 0 else 1
        my_entry = me_rows[0] if me_rows else None

        return func.HttpResponse(
            json.dumps({
                "metric": metric,
                "scope": scope,
                "top": [format_entry(r) for r in (entries or [])],
                "me": format_entry(my_entry) if my_entry else None,
                "aroundMe": [],
                "page": page,
                "pageSize": page_size,
                "totalCount": total_count,
                "totalPages": total_pages
            }, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting leaderboard v2: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
