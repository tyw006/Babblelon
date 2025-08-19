-- Migration: Add comprehensive onboarding and multi-language support fields to players table
-- Date: 2025-01-08
-- Description: Extends players table with language selection, character customization, 
--              learning preferences, and anonymous auth support

-- Core language settings
ALTER TABLE players ADD COLUMN IF NOT EXISTS target_language TEXT DEFAULT 'thai';
COMMENT ON COLUMN players.target_language IS 'Selected language to learn: thai, japanese, korean, mandarin, vietnamese';

ALTER TABLE players ADD COLUMN IF NOT EXISTS target_language_level TEXT DEFAULT 'beginner';
COMMENT ON COLUMN players.target_language_level IS 'Proficiency level: beginner, elementary, intermediate, advanced';

ALTER TABLE players ADD COLUMN IF NOT EXISTS has_prior_learning BOOLEAN DEFAULT false;
ALTER TABLE players ADD COLUMN IF NOT EXISTS prior_learning_details TEXT;

-- Character customization
ALTER TABLE players ADD COLUMN IF NOT EXISTS selected_character TEXT;
COMMENT ON COLUMN players.selected_character IS 'Character ID/type selected by player';

ALTER TABLE players ADD COLUMN IF NOT EXISTS character_customization JSONB DEFAULT '{}';
COMMENT ON COLUMN players.character_customization IS 'Character appearance: skin, outfit, accessories';

-- Learning preferences (language-agnostic)
ALTER TABLE players ADD COLUMN IF NOT EXISTS native_language TEXT;
COMMENT ON COLUMN players.native_language IS 'ISO language code: en, zh, ja, ko, es, fr, de, pt, ru, ar, hi, id, vi, my';

ALTER TABLE players ADD COLUMN IF NOT EXISTS learning_motivation TEXT;
COMMENT ON COLUMN players.learning_motivation IS 'Primary motivation: travel, culture, business, family, personal, education';

ALTER TABLE players ADD COLUMN IF NOT EXISTS learning_pace TEXT;
COMMENT ON COLUMN players.learning_pace IS 'Preferred pace: casual, moderate, intensive';

ALTER TABLE players ADD COLUMN IF NOT EXISTS learning_style TEXT;
COMMENT ON COLUMN players.learning_style IS 'Learning style: visual, auditory, kinesthetic, mixed';

ALTER TABLE players ADD COLUMN IF NOT EXISTS learning_context TEXT;
COMMENT ON COLUMN players.learning_context IS 'Usage context: living_abroad, travel_prep, academic, business, cultural_interest';

ALTER TABLE players ADD COLUMN IF NOT EXISTS daily_goal_minutes INTEGER DEFAULT 15;
ALTER TABLE players ADD COLUMN IF NOT EXISTS preferred_practice_time TEXT;
COMMENT ON COLUMN players.preferred_practice_time IS 'Preferred time: morning, afternoon, evening, flexible';

-- Consent & metadata
ALTER TABLE players ADD COLUMN IF NOT EXISTS voice_recording_consent BOOLEAN DEFAULT false;
ALTER TABLE players ADD COLUMN IF NOT EXISTS personalized_content_consent BOOLEAN DEFAULT true;
ALTER TABLE players ADD COLUMN IF NOT EXISTS onboarding_version TEXT DEFAULT '1.0';
ALTER TABLE players ADD COLUMN IF NOT EXISTS learning_preferences JSONB DEFAULT '{}';
COMMENT ON COLUMN players.learning_preferences IS 'Flexible storage for additional preferences';

ALTER TABLE players ADD COLUMN IF NOT EXISTS privacy_policy_accepted BOOLEAN DEFAULT false;
ALTER TABLE players ADD COLUMN IF NOT EXISTS data_collection_consented BOOLEAN DEFAULT false;
ALTER TABLE players ADD COLUMN IF NOT EXISTS consent_date TIMESTAMP WITH TIME ZONE;

-- Profile metadata
ALTER TABLE players ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE players ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE players ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Anonymous auth support
ALTER TABLE players ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT true;
ALTER TABLE players ADD COLUMN IF NOT EXISTS account_upgraded_at TIMESTAMP WITH TIME ZONE;
COMMENT ON COLUMN players.is_anonymous IS 'Whether user is using anonymous auth or has upgraded to email/social';

-- Tutorial tracking (per language)
ALTER TABLE players ADD COLUMN IF NOT EXISTS tutorials_completed JSONB DEFAULT '{}';
COMMENT ON COLUMN players.tutorials_completed IS 'Tutorial completion status per language: {"thai_gameplay": true, "korean_writing": false}';

-- Onboarding completion tracking
ALTER TABLE players ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;
ALTER TABLE players ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMP WITH TIME ZONE;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_players_target_language ON players(target_language);
CREATE INDEX IF NOT EXISTS idx_players_native_language ON players(native_language);
CREATE INDEX IF NOT EXISTS idx_players_is_anonymous ON players(is_anonymous);
CREATE INDEX IF NOT EXISTS idx_players_onboarding_completed ON players(onboarding_completed);

-- Row Level Security (RLS) Policies
-- Ensure users can only access their own data
ALTER TABLE players ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists and recreate
DROP POLICY IF EXISTS "Users can view own profile" ON players;
CREATE POLICY "Users can view own profile" ON players
    FOR SELECT USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "Users can update own profile" ON players;
CREATE POLICY "Users can update own profile" ON players
    FOR UPDATE USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "Users can insert own profile" ON players;
CREATE POLICY "Users can insert own profile" ON players
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Anonymous users can create their profile
DROP POLICY IF EXISTS "Anonymous users can create profile" ON players;
CREATE POLICY "Anonymous users can create profile" ON players
    FOR INSERT WITH CHECK (
        auth.jwt()->>'is_anonymous' = 'true' 
        OR auth.uid()::text = user_id
    );

-- Add constraint to ensure language values are valid
ALTER TABLE players ADD CONSTRAINT valid_target_language 
    CHECK (target_language IN ('thai', 'japanese', 'korean', 'mandarin', 'vietnamese'));

ALTER TABLE players ADD CONSTRAINT valid_language_level 
    CHECK (target_language_level IN ('beginner', 'elementary', 'intermediate', 'advanced'));

ALTER TABLE players ADD CONSTRAINT valid_learning_pace 
    CHECK (learning_pace IN ('casual', 'moderate', 'intensive'));

ALTER TABLE players ADD CONSTRAINT valid_learning_motivation 
    CHECK (learning_motivation IN ('travel', 'culture', 'business', 'family', 'personal', 'education'));