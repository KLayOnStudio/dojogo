-- Migration 002: Add mode column to sessions table
-- Distinguishes guided sessions (with cues) from free practice
-- Default 'guided' since that is now the default mode

ALTER TABLE sessions
  ADD COLUMN mode VARCHAR(10) NOT NULL DEFAULT 'guided'
  COMMENT 'Session mode: guided (with cues) or free (no cues)';
