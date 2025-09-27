#!/usr/bin/env python3
"""
Script to set up the dojogo MySQL database on Azure
"""
import mysql.connector
from mysql.connector import Error

# Database connection configuration
config = {
    'host': 'dojogo-mysql-us-west2.mysql.database.azure.com',
    'user': 'klayon',
    'password': 'Zmfodyd4urAI',
    'port': 3306,
    'ssl_disabled': False,
    'autocommit': True
}

def create_database():
    """Create the dojogo database"""
    try:
        # Connect to MySQL server (without specifying database)
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor()

        # Create database
        print("Creating database 'dojogo'...")
        cursor.execute("CREATE DATABASE IF NOT EXISTS dojogo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
        print("✅ Database 'dojogo' created successfully")

        # Close connection
        cursor.close()
        connection.close()

        return True

    except Error as e:
        print(f"❌ Error creating database: {e}")
        return False

def create_tables():
    """Create the required tables in the dojogo database"""

    # Update config to use the dojogo database
    db_config = config.copy()
    db_config['database'] = 'dojogo'

    try:
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()

        print("Creating tables...")

        # Create users table
        users_table = """
        CREATE TABLE IF NOT EXISTS users (
            id VARCHAR(255) PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            streak INT DEFAULT 0,
            total_count INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """

        cursor.execute(users_table)
        print("✅ Users table created")

        # Create sessions table
        sessions_table = """
        CREATE TABLE IF NOT EXISTS sessions (
            id VARCHAR(36) PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            tap_count INT NOT NULL,
            duration DECIMAL(10,2) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            INDEX idx_user_sessions (user_id),
            INDEX idx_session_date (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """

        cursor.execute(sessions_table)
        print("✅ Sessions table created")

        # Create session_starts table
        session_starts_table = """
        CREATE TABLE IF NOT EXISTS session_starts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(255) NOT NULL,
            started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            INDEX idx_user_starts (user_id),
            INDEX idx_start_date (started_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        """

        cursor.execute(session_starts_table)
        print("✅ Session starts table created")

        # Verify tables were created
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print(f"\n📋 Tables in database: {[table[0] for table in tables]}")

        cursor.close()
        connection.close()

        return True

    except Error as e:
        print(f"❌ Error creating tables: {e}")
        return False

def main():
    print("🚀 Setting up dojogo database on Azure MySQL...")
    print(f"Host: {config['host']}")
    print(f"User: {config['user']}")
    print("-" * 50)

    # Step 1: Create database
    if not create_database():
        return

    # Step 2: Create tables
    if not create_tables():
        return

    print("\n🎉 Database setup completed successfully!")
    print("The dojogo database is ready for use.")

if __name__ == "__main__":
    main()