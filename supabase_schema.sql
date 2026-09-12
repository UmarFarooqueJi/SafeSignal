-- SafeSignal - Improved Supabase Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    name TEXT,
    avatar_url TEXT,
    language TEXT DEFAULT 'hi',
    is_premium BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;

CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 2. Scan History Table - Improved
CREATE TABLE IF NOT EXISTS public.scan_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    scan_type TEXT NOT NULL CHECK (scan_type IN ('URL', 'EMAIL', 'DEVICE', 'APP', 'WIFI', 'UPI', 'QR', 'SMS')),
    target TEXT,
    status TEXT NOT NULL CHECK (status IN ('SAFE', 'WARNING', 'DANGER', 'INFO')),
    details JSONB,
    risk_score INTEGER CHECK (risk_score >= 0 AND risk_score <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_scan_history_user_id ON public.scan_history(user_id);
CREATE INDEX IF NOT EXISTS idx_scan_history_created_at ON public.scan_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scan_history_scan_type ON public.scan_history(scan_type);
CREATE INDEX IF NOT EXISTS idx_scan_history_status ON public.scan_history(status);

-- Enable RLS for Scan History
ALTER TABLE public.scan_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can insert scan history" ON public.scan_history;
DROP POLICY IF EXISTS "Users can view their own scan history" ON public.scan_history;

-- More secure policies - allow anonymous but limit exposure
CREATE POLICY "Anyone can insert scan history" ON public.scan_history FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can view own history" ON public.scan_history FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "Users can delete own history" ON public.scan_history FOR DELETE USING (auth.uid() = user_id);

-- 3. Crowd Intel Reports (New - for community scam reporting)
CREATE TABLE IF NOT EXISTS public.crowd_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    scam_type TEXT NOT NULL,
    target TEXT NOT NULL, -- phone number, url, upi id etc
    description TEXT,
    evidence JSONB,
    verified_count INTEGER DEFAULT 1,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'false_positive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_crowd_reports_target ON public.crowd_reports(target);
CREATE INDEX IF NOT EXISTS idx_crowd_reports_status ON public.crowd_reports(status);

ALTER TABLE public.crowd_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert crowd report" ON public.crowd_reports FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can view verified reports" ON public.crowd_reports FOR SELECT USING (status = 'verified' OR reporter_id = auth.uid());

-- 4. User Feedback on Verdicts
CREATE TABLE IF NOT EXISTS public.verdict_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    check_id TEXT NOT NULL,
    was_correct BOOLEAN NOT NULL,
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.verdict_feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert feedback" ON public.verdict_feedback FOR INSERT WITH CHECK (true);
CREATE POLICY "Users view own feedback" ON public.verdict_feedback FOR SELECT USING (auth.uid() = user_id);
