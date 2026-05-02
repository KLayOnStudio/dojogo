import azure.functions as func
import json
import logging
import math
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

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

        col = 'total_count' if metric == 'swings' else 'streak'
        requesting_user_id = user_id
        offset = (page - 1) * page_size

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
            # Friends scope: self + accepted friends (no CTEs for compatibility)
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

        def mask_nickname(nickname):
            if not nickname:
                return "???"
            if len(nickname) <= 2:
                return nickname
            return nickname[0] + "*" * (len(nickname) - 2) + nickname[-1]

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

        return func.HttpResponse(
            json.dumps({
                "metric": metric,
                "scope": scope,
                "top": [format_entry(r) for r in entries],
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
