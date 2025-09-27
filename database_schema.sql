-- Database Schema for Dojogo App
-- MySQL Database on Azure

-- Users table
CREATE TABLE users (
    id VARCHAR(255) PRIMARY KEY, -- Auth0 user ID
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    streak INT DEFAULT 0,
    total_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_session_date DATE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Sessions table
CREATE TABLE sessions (
    id VARCHAR(36) PRIMARY KEY, -- UUID
    user_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    tap_count INT NOT NULL,
    duration DECIMAL(10,2) NOT NULL, -- Duration in seconds
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_date (user_id, date),
    INDEX idx_date (date)
);

-- Session starts table (for tracking app launches)
CREATE TABLE session_starts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_timestamp (user_id, timestamp)
);

-- Indexes for performance
CREATE INDEX idx_users_total_count ON users(total_count DESC);
CREATE INDEX idx_users_streak ON users(streak DESC);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_tap_count ON sessions(tap_count DESC);