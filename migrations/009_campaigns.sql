-- Migration 009: Campaigns system
-- Creates campaigns and campaign_members tables

CREATE TABLE IF NOT EXISTS campaigns (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    rules TEXT,
    prize TEXT,
    prize_url VARCHAR(255),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_by VARCHAR(255) REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS campaign_members (
    campaign_id INT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (campaign_id, user_id),
    FOREIGN KEY (campaign_id) REFERENCES campaigns(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Insert the first campaign
INSERT IGNORE INTO campaigns (name, description, rules, prize, prize_url, start_date, end_date, created_by)
VALUES (
    'Sugiyama Suburi Challenge',
    'Hey Miyoga kenshis! You know I''ve been building this app for a year now — it''s finally time to put it out there. I''d love for you to be part of this from the beginning. Every suburi you log helps me move forward, and I genuinely believe we can build something that changes how our whole community practices kendo. Let''s do this together.',
    'Score = Total Swings + (Max Streak × 50). Swings and streak are counted only within the campaign window (May 4–17).',
    'Prize in progress — stay tuned!',
    NULL,
    '2026-05-04',
    '2026-05-17',
    'google-oauth2|109014600756206092446'
);
