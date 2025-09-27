import azure.functions as func
import json
import logging
import sys
import os

# Deployment trigger - storage settings now properly saved

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('GetLeaderboard function processed a request.')

    try:
        # Get leaderboard type from query parameters
        leaderboard_type = req.params.get('type', 'total')  # 'total' or 'streak'
        limit = int(req.params.get('limit', 100))  # Default to top 100

        if leaderboard_type not in ['total', 'streak']:
            return func.HttpResponse(
                json.dumps({"error": "Invalid leaderboard type. Use 'total' or 'streak'"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Build query based on type
        if leaderboard_type == 'total':
            query = """
                SELECT name, total_count as score, streak
                FROM users
                WHERE total_count > 0
                ORDER BY total_count DESC, streak DESC
                LIMIT %s
            """
        else:  # streak
            query = """
                SELECT name, streak as score, total_count
                FROM users
                WHERE streak > 0
                ORDER BY streak DESC, total_count DESC
                LIMIT %s
            """

        leaderboard = execute_query(query, (limit,), fetch=True)

        # Add ranking
        for i, entry in enumerate(leaderboard):
            entry['rank'] = i + 1

        return func.HttpResponse(
            json.dumps({
                "type": leaderboard_type,
                "leaderboard": leaderboard
            }, default=str),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error getting leaderboard: {e}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )