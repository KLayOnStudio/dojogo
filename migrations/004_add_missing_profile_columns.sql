-- Migration 004: Add missing kendo experience columns to users table
-- These columns are referenced by UpdateProfile but were never created

ALTER TABLE users
ADD COLUMN IF NOT EXISTS kendo_experience_years INT DEFAULT 0 AFTER kendo_rank;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS kendo_experience_months INT DEFAULT 0 AFTER kendo_experience_years;
