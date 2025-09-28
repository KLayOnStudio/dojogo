import azure.functions as func
import json
import logging
import jwt
import sys
import os

# Add shared directory to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from database import execute_query
from auth import get_token_from_header

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('CreateUserNoAuth function processed a request.')

    try:
        # Get user data from request
        req_body = req.get_json()

        if not req_body:
            return func.HttpResponse(
                json.dumps({"error": "Request body required"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Try to extract user_id from token manually
        token = get_token_from_header(req)
        user_id = None

        if token:
            try:
                unverified_payload = jwt.decode(token, options={"verify_signature": False})
                user_id = unverified_payload.get('sub')
                logging.info(f"MANUAL AUTH DEBUG - Extracted user_id: {user_id}")
            except Exception as jwt_error:
                logging.error(f"MANUAL AUTH DEBUG - JWT decode failed: {jwt_error}")
                return func.HttpResponse(
                    json.dumps({"error": f"JWT decode failed: {str(jwt_error)}"}),
                    status_code=400,
                    headers={"Content-Type": "application/json"}
                )
        else:
            logging.error("MANUAL AUTH DEBUG - No token found")
            return func.HttpResponse(
                json.dumps({"error": "No authorization token provided"}),
                status_code=401,
                headers={"Content-Type": "application/json"}
            )

        name = req_body.get('name')
        email = req_body.get('email')

        logging.info(f"CreateUserNoAuth called with user_id: {user_id}, name: {name}, email: {email}")

        if not all([user_id, name, email]):
            return func.HttpResponse(
                json.dumps({"error": "Missing required fields: user_id, name, email"}),
                status_code=400,
                headers={"Content-Type": "application/json"}
            )

        # Check if user already exists
        existing_user = execute_query(
            "SELECT id FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if existing_user:
            return func.HttpResponse(
                json.dumps({"message": "User already exists", "user_id": user_id}),
                status_code=200,
                headers={"Content-Type": "application/json"}
            )

        # Create new user
        execute_query(
            "INSERT INTO users (id, name, email, streak, total_count) VALUES (%s, %s, %s, 0, 0)",
            (user_id, name, email)
        )

        # Return created user
        user = execute_query(
            "SELECT id, name, email, streak, total_count, created_at FROM users WHERE id = %s",
            (user_id,),
            fetch=True
        )

        if user and user[0]:
            user_data = user[0]
            user_response = {
                "id": user_data.get("id"),
                "name": user_data.get("name"),
                "email": user_data.get("email"),
                "streak": user_data.get("streak"),
                "totalCount": user_data.get("total_count"),
                "createdAt": int(user_data.get("created_at").timestamp()) if user_data.get("created_at") else None
            }
        else:
            user_response = None

        return func.HttpResponse(
            json.dumps({
                "message": "User created successfully",
                "user": user_response
            }, default=str),
            status_code=201,
            headers={"Content-Type": "application/json"}
        )

    except Exception as e:
        logging.error(f"Error creating user: {e}")
        logging.error(f"Exception type: {type(e)}")
        logging.error(f"Exception args: {e.args}")
        return func.HttpResponse(
            json.dumps({"error": f"Internal server error: {str(e)}"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )