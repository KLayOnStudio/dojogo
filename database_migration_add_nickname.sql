-- Migration: Add nickname and user_number fields to users table
-- Run this on the existing database

-- Add user_number column (auto-increment)
ALTER TABLE users
ADD COLUMN user_number INT AUTO_INCREMENT UNIQUE AFTER id;

-- Add nickname column (optional, unique)
ALTER TABLE users
ADD COLUMN nickname VARCHAR(50) UNIQUE AFTER name;

-- Add nickname_last_changed column
ALTER TABLE users
ADD COLUMN nickname_last_changed TIMESTAMP NULL AFTER nickname;

-- Create index on nickname for faster lookups
CREATE INDEX idx_users_nickname ON users(nickname);
