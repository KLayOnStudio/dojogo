# Dojogo API Endpoints

Base URL: `https://your-azure-api.azurewebsites.net/api`

## Authentication
All endpoints require Auth0 JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

## User Endpoints

### Create User
- **POST** `/users`
- **Body:**
```json
{
  "id": "auth0_user_id",
  "name": "User Name",
  "email": "user@example.com"
}
```
- **Response:**
```json
{
  "success": true,
  "data": {
    "id": "auth0_user_id",
    "name": "User Name",
    "email": "user@example.com",
    "streak": 0,
    "totalCount": 0,
    "createdAt": "2025-09-26T12:00:00Z",
    "lastSessionDate": null
  }
}
```

### Get User
- **GET** `/users/{userId}`
- **Response:** Same as Create User

### Update User
- **PUT** `/users/{userId}`
- **Body:** Same as Create User
- **Response:** Same as Create User

## Session Endpoints

### Log Session Start
- **POST** `/sessions/start`
- **Body:**
```json
{
  "userId": "auth0_user_id",
  "timestamp": "2025-09-26T12:00:00Z"
}
```
- **Response:**
```json
{
  "success": true,
  "message": "Session start logged"
}
```

### Submit Session
- **POST** `/sessions`
- **Body:**
```json
{
  "id": "session_uuid",
  "userId": "auth0_user_id",
  "date": "2025-09-26T12:00:00Z",
  "tapCount": 25,
  "duration": 120.5,
  "startTime": "2025-09-26T12:00:00Z",
  "endTime": "2025-09-26T12:02:00Z"
}
```
- **Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "auth0_user_id",
      "name": "User Name",
      "email": "user@example.com",
      "streak": 5,
      "totalCount": 125,
      "createdAt": "2025-09-26T12:00:00Z",
      "lastSessionDate": "2025-09-26"
    },
    "streak": 5
  }
}
```

## Leaderboard Endpoints

### Get Leaderboard
- **GET** `/leaderboard`
- **Response:**
```json
{
  "success": true,
  "data": {
    "totalTaps": [
      {
        "userId": "user1",
        "name": "Player 1",
        "value": 1000,
        "rank": 1
      },
      {
        "userId": "user2",
        "name": "Player 2",
        "value": 850,
        "rank": 2
      }
    ],
    "streaks": [
      {
        "userId": "user3",
        "name": "Player 3",
        "value": 30,
        "rank": 1
      },
      {
        "userId": "user1",
        "name": "Player 1",
        "value": 25,
        "rank": 2
      }
    ]
  }
}
```

## Error Responses

All endpoints may return error responses in this format:
```json
{
  "success": false,
  "message": "Error description",
  "data": null
}
```

Common HTTP status codes:
- `200` - Success
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `500` - Internal Server Error