import azure.functions as func
import json
import logging
import sys
import os
from datetime import datetime

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import require_auth

@require_auth
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('UpdateProfile function processed a request.')

    try:
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        user_id = req.user_id  # From auth decorator
        nickname = req_body.get('nickname')
        kendo_rank = req_body.get('kendoRank')
        kendo_experience_years = req_body.get('kendoExperienceYears')
        kendo_experience_months = req_body.get('kendoExperienceMonths')

        # Check if user exists
        user = execute_query(
            "SELECT nickname_last_changed FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if not user or not user[0]:
            return func.HttpResponse(
                json.dumps({"error": "User not found"}),
                status_code=404,
                headers={"Content-Type": "application/json"}
            )

        # Build update query dynamically
        update_fields = []
        update_values = []

        # Handle nickname update (with cooldown check)
        if nickname is not None:
            # Validate nickname
            if not (3 <= len(nickname) <= 50):
                return func.HttpResponse(
                    json.dumps({"error": "Nickname must be 3-50 characters"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )

            # Check 30-day cooldown
            last_changed = user[0].get('nickname_last_changed')
            if last_changed:
                days_since_change = (datetime.now() - last_changed).days
                if days_since_change < 30:
                    days_remaining = 30 - days_since_change
                    return func.HttpResponse(
                        json.dumps({
                            "error": f"You can change your nickname again in {days_remaining} days",
                            "daysRemaining": days_remaining
                        }),
                        status_code=429,
                        headers={"Content-Type": "application/json"}
                    )

            # Check if nickname is already taken
            existing = execute_query(
                "SELECT id FROM users WHERE nickname = %s AND id != %s",
                (nickname, user_id),
                fetch=True
            )

            if existing:
                return func.HttpResponse(
                    json.dumps({"error": "Nickname is already taken"}),
                    status_code=409,
                    headers={"Content-Type": "application/json"}
                )

            update_fields.append("nickname = %s")
            update_values.append(nickname)
            update_fields.append("nickname_last_changed = NOW()")

        # Handle kendo_rank update (no restrictions)
        if kendo_rank is not None:
            # Validate kendo rank
            valid_ranks = [
                "unranked", "9kyu", "8kyu", "7kyu", "6kyu", "5kyu", "4kyu", "3kyu", "2kyu", "1kyu",
                "1dan", "2dan", "3dan", "4dan", "5dan", "6dan", "7dan", "8dan"
            ]
            if kendo_rank not in valid_ranks:
                return func.HttpResponse(
                    json.dumps({"error": "Invalid kendo rank"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )

            update_fields.append("kendo_rank = %s")
            update_values.append(kendo_rank)

        # Handle kendo experience years update
        if kendo_experience_years is not None:
            if not isinstance(kendo_experience_years, int) or kendo_experience_years < 0 or kendo_experience_years > 100:
                return func.HttpResponse(
                    json.dumps({"error": "Invalid experience years (must be 0-100)"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )
            update_fields.append("kendo_experience_years = %s")
            update_values.append(kendo_experience_years)

        # Handle kendo experience months update
        if kendo_experience_months is not None:
            if not isinstance(kendo_experience_months, int) or kendo_experience_months < 0 or kendo_experience_months > 11:
                return func.HttpResponse(
                    json.dumps({"error": "Invalid experience months (must be 0-11)"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )
            update_fields.append("kendo_experience_months = %s")
            update_values.append(kendo_experience_months)

        if not update_fields:
            return func.HttpResponse(
                json.dumps({"error": "No fields to update"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Build and execute update query
        update_query = f"UPDATE users SET {', '.join(update_fields)} WHERE id = %s"
        update_values.append(user_id)

        execute_query(update_query, tuple(update_values))

        # Return updated user
        updated_user = execute_query(
            "SELECT id, user_number, name, nickname, nickname_last_changed, kendo_rank, kendo_experience_years, kendo_experience_months, email, streak, total_count, created_at FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if updated_user and updated_user[0]:
            user_data = updated_user[0]
            user_response = {
                "id": user_data.get("id"),
                "userNumber": user_data.get("user_number"),
                "name": user_data.get("name"),
                "nickname": user_data.get("nickname"),
                "nicknameLastChanged": int(user_data.get("nickname_last_changed").timestamp()) if user_data.get("nickname_last_changed") else None,
                "kendoRank": user_data.get("kendo_rank"),
                "kendoExperienceYears": user_data.get("kendo_experience_years"),
                "kendoExperienceMonths": user_data.get("kendo_experience_months"),
                "email": user_data.get("email"),
                "streak": user_data.get("streak"),
                "totalCount": user_data.get("total_count"),
                "createdAt": int(user_data.get("created_at").timestamp()) if user_data.get("created_at") else None
            }

            return func.HttpResponse(
                json.dumps({
                    "message": "Profile updated successfully",
                    "user": user_response
                }, default=str),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )
        else:
            return func.HttpResponse(
                json.dumps({"error": "Failed to retrieve updated user"}),
                status_code=500,
                headers={"Content-Type": "application/json"}
            )

    except Exception as e:
        logging.error(f"Error updating profile: {e}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
