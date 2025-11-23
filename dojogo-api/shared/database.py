"""
Database connection utilities for Azure Functions
"""
import os
import mysql.connector
from mysql.connector import Error
import logging
from datetime import timezone

def get_db_connection():
    """
    Get a connection to the MySQL database using environment variables
    """
    try:
        connection = mysql.connector.connect(
            host=os.environ.get('DB_HOST'),
            user=os.environ.get('DB_USER'),
            password=os.environ.get('DB_PASSWORD'),
            database=os.environ.get('DB_NAME'),
            port=int(os.environ.get('DB_PORT', 3306)),
            ssl_disabled=False,
            autocommit=True,
            time_zone='+00:00'  # Force UTC timezone for all connections
        )
        return connection
    except Error as e:
        logging.error(f"Error connecting to database: {e}")
        raise

def datetime_to_timestamp(dt):
    """
    Convert a naive datetime from MySQL (assumed to be UTC) to Unix timestamp

    Args:
        dt: datetime object from MySQL

    Returns:
        int: Unix timestamp in seconds
    """
    if dt is None:
        return None
    # MySQL returns naive datetimes in the connection's timezone (UTC with our config)
    # We need to treat them as UTC and convert to timestamp
    return int(dt.replace(tzinfo=timezone.utc).timestamp())

def execute_query(query, params=None, fetch=False):
    """
    Execute a database query with optional parameters

    Args:
        query (str): SQL query to execute
        params (tuple, optional): Parameters for the query
        fetch (bool): Whether to fetch results

    Returns:
        Results if fetch=True, otherwise None
    """
    connection = None
    cursor = None

    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        if params:
            cursor.execute(query, params)
        else:
            cursor.execute(query)

        if fetch:
            if query.strip().upper().startswith('SELECT'):
                return cursor.fetchall()
            else:
                return cursor.fetchone()

        return None

    except Error as e:
        logging.error(f"Database query error: {e}")
        raise
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()