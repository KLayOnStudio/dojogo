-- Migration 006: Friends system tables

-- 1. friend_requests table
CREATE TABLE IF NOT EXISTS friend_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    from_user_id VARCHAR(255) NOT NULL,
    to_user_id VARCHAR(255) NOT NULL,
    status ENUM('pending','accepted','declined','canceled') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP NULL,
    UNIQUE KEY uq_friend_request (from_user_id, to_user_id),
    INDEX idx_to_status (to_user_id, status),
    INDEX idx_from_status (from_user_id, status),
    CONSTRAINT fk_fr_from FOREIGN KEY (from_user_id) REFERENCES users(id),
    CONSTRAINT fk_fr_to FOREIGN KEY (to_user_id) REFERENCES users(id)
);

-- 2. friendships table (normalized: user_id_a < user_id_b)
CREATE TABLE IF NOT EXISTS friendships (
    user_id_a VARCHAR(255) NOT NULL,
    user_id_b VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id_a, user_id_b),
    INDEX idx_friendships_b (user_id_b),
    CONSTRAINT fk_fs_a FOREIGN KEY (user_id_a) REFERENCES users(id),
    CONSTRAINT fk_fs_b FOREIGN KEY (user_id_b) REFERENCES users(id),
    CONSTRAINT chk_ordering CHECK (user_id_a < user_id_b)
);

-- 3. Add insights_visibility column to users
SET @col_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'users' AND COLUMN_NAME = 'insights_visibility' AND TABLE_SCHEMA = DATABASE());
SET @sql = IF(@col_exists = 0,
    'ALTER TABLE users ADD COLUMN insights_visibility VARCHAR(20) DEFAULT ''public'' AFTER home_dojo',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
