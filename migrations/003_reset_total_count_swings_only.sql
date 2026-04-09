-- Migration 003: Reset total_count to only count swing-era sessions
-- Discards legacy tap_count data; recalculates from sessions with mode column
-- (All swing-based sessions have mode = 'guided' or 'free')

-- Also rename tap_count → swing_count in sessions table for clarity
ALTER TABLE sessions CHANGE COLUMN tap_count swing_count INT NOT NULL DEFAULT 0;

-- Reset all users' total_count to sum of swing_count from sessions with a mode value
UPDATE users u
SET total_count = COALESCE((
    SELECT SUM(s.swing_count)
    FROM sessions s
    WHERE s.user_id = u.id
      AND s.mode IN ('guided', 'free')
), 0);
