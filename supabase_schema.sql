-- Run this in your Supabase SQL Editor

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 2. Scan History Table
CREATE TABLE IF NOT EXISTS public.scan_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    scan_type TEXT NOT NULL, -- 'URL', 'EMAIL', 'DEVICE', 'APP', 'UPI', 'WIFI'
    target TEXT, -- the URL, Email, SSID or Target
    status TEXT NOT NULL, -- 'SAFE', 'WARNING', 'DANGER'
    details JSONB, -- full scan results
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for Scan History
ALTER TABLE public.scan_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can insert their own scan history" ON public.scan_history FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.uid() IS NOT NULL);
CREATE POLICY "Users can view only their own scan history" ON public.scan_history FOR SELECT USING (auth.uid() = user_id);

-- 3. Crowd Intelligence & Threat Reports Table
CREATE TABLE IF NOT EXISTS public.threat_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type TEXT NOT NULL, -- 'url', 'sms', 'upi', 'phone'
    value_hash TEXT UNIQUE NOT NULL,
    verdict TEXT NOT NULL, -- 'SCAM', 'SAFE'
    reporter_count INT DEFAULT 1,
    confidence NUMERIC(3,2) DEFAULT 0.75,
    status TEXT DEFAULT 'pending', -- 'pending', 'verified', 'dismissed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.threat_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can view verified threats" ON public.threat_reports FOR SELECT USING (true);
CREATE POLICY "Authenticated or anonymous users can report threats" ON public.threat_reports FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow upserting reporter count" ON public.threat_reports FOR UPDATE USING (true);

-- 4. Verified Blocklist View / Table
CREATE TABLE IF NOT EXISTS public.blocklist (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    value_hash TEXT UNIQUE NOT NULL,
    confidence NUMERIC(3,2) DEFAULT 0.90,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.blocklist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public can read verified blocklist" ON public.blocklist FOR SELECT USING (true);
