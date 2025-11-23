-- Migration: Add kendo_rank field to users table

ALTER TABLE users
ADD COLUMN kendo_rank VARCHAR(20) AFTER nickname_last_changed;
