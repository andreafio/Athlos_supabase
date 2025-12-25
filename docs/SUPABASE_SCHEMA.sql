-- ============================================================================
-- ATHLOS SUPABASE DATABASE SCHEMA
-- Complete PostgreSQL Schema for Supabase
-- ============================================================================
-- 
-- Source: Migrated from Laravel/MySQL sportapp_backend
-- Optimizations Applied:
--   1. Consolidated match scoring tables (match_points + judo_match_points → match_actions)
--   2. UUID primary keys (instead of BIGINT AUTO_INCREMENT)
--   3. TIMESTAMPTZ (timezone-aware timestamps)
--   4. JSONB for flexible data (bracket_data, custom_rules)
--   5. Performance indexes for 1000+ concurrent users
--   6. Foreign keys with CASCADE deletes where appropriate
--
-- Total Tables: 38 (25 MySQL tables)
-- Dropped: 16 Laravel/Passport infrastructure tables
--
-- Date: 2025-12-25
-- ============================================================================

-- ============================================================================
-- SECTION 1: EXTENSIONS & SETUP
-- ============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- For gen_random_uuid()

-- Enable case-insensitive text search
CREATE EXTENSION IF NOT EXISTS "citext";

-- ============================================================================
-- SECTION 2: CUSTOM TYPES (ENUMS)
-- ============================================================================

CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');
CREATE TYPE membership_status AS ENUM ('active', 'expired', 'suspended', 'cancelled');
CREATE TYPE payment_status AS ENUM ('paid', 'pending', 'partial', 'overdue', 'failed');
CREATE TYPE event_status AS ENUM ('draft', 'published', 'ongoing', 'completed', 'cancelled');
CREATE TYPE registration_status AS ENUM ('pending', 'confirmed', 'cancelled', 'checked_in');
CREATE TYPE bracket_type AS ENUM ('single_elimination', 'double_elimination', 'round_robin', 'pool', 'swiss');
CREATE TYPE match_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled');
CREATE TYPE action_type AS ENUM ('ippon', 'waza_ari', 'yuko', 'koka', 'shido', 'hansoku_make', 'penalty', 'technique', 'video_event');
CREATE TYPE team_role AS ENUM ('athlete', 'coach', 'staff', 'admin');
CREATE TYPE course_recurrence AS ENUM ('once', 'weekly', 'monthly');
CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'excused', 'late') -- 'present', 'absent', 'excused', 'late');
CREATE TYPE enrollment_status AS ENUM ('active', 'inactive', 'completed');

-- ============================================================================
-- SECTION 3: CORE TABLES - AUTHENTICATION & PROFILES
-- ============================================================================
-- Note: auth.users is managed by Supabase Auth
-- We create a public.profiles table to extend user data

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  email CITEXT,
  phone TEXT,
  avatar_url TEXT,
  onboarding_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'Extended user profile data (linked to auth.users)';

-- ============================================================================
-- SECTION 4: ATHLETES & GUARDIANS
-- ============================================================================

CREATE TABLE public.athletes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Nullable: minor may not have account
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender gender_type NOT NULL,
  fiscal_code TEXT UNIQUE,
  phone TEXT,
  email CITEXT,
  
  -- Address
  address TEXT,
  city TEXT,
  province TEXT,
  postal_code TEXT,
  country TEXT DEFAULT 'IT',
  
  -- Emergency contact
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  
  -- Medical
  medical_certificate_expiry DATE,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT athletes_age_check CHECK (date_of_birth < CURRENT_DATE)
);

COMMENT ON TABLE public.athletes IS 'Athlete profiles (3000+ expected). Supports minors without user_id.';
COMMENT ON COLUMN public.athletes.user_id IS 'NULL for minors without login. Guardian manages via guardians table.';

-- Guardians (Legal representatives for minor athletes)
CREATE TABLE public.guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- Guardian's account
  
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  relationship TEXT NOT NULL, -- 'parent', 'tutor', etc.
  phone TEXT,
  email CITEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- One guardian account can manage multiple minors
  UNIQUE(athlete_id, user_id)
);

COMMENT ON TABLE public.guardians IS 'Guardian-minor relationships (82,566 test records). Critical for RLS policies.';

-- ============================================================================
-- SECTION 5: TEAMS & CLUBS
-- ============================================================================

CREATE TABLE public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  athlete_id UUID REFERENCES public.athletes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- For coaches/staff
  
  role team_role NOT NULL DEFAULT 'athlete',
  joined_date DATE DEFAULT CURRENT_DATE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Either athlete_id OR user_id must be set
  CONSTRAINT team_member_identity CHECK (
    (athlete_id IS NOT NULL AND user_id IS NULL) OR
    (athlete_id IS NULL AND user_id IS NOT NULL)
  )
);

-- ============================================================================
-- SECTION 6: ROLES & PERMISSIONS
-- ============================================================================

CREATE TABLE public.roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE, -- 'admin', 'organizer', 'coach', 'referee'
  description TEXT,
  permissions JSONB DEFAULT '[]'::jsonb, -- Array of permission strings
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, role_id)
);

-- ============================================================================
-- SECTION 7: MEMBERSHIPS & PAYMENTS
-- ============================================================================

CREATE TABLE public.membership_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(8,2) NOT NULL,
  duration_months INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  membership_type_id UUID NOT NULL REFERENCES public.membership_types(id),
  
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status membership_status DEFAULT 'active',
  
  payment_status payment_status DEFAULT 'pending',
  amount NUMERIC(8,2) NOT NULL,
  payment_date DATE,
  stripe_payment_id TEXT, -- Stripe payment intent ID
  
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT membership_dates_valid CHECK (start_date < end_date)
);



-- ============================================================================
-- SECTION 8: EVENTS & COMPETITIONS
-- ============================================================================

CREATE TABLE public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  event_type TEXT NOT NULL, -- 'competition', 'training', 'seminar'
  sport_type TEXT NOT NULL, -- 'judo', 'wrestling', etc.
  
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  registration_deadline TIMESTAMPTZ,
  
  location TEXT,
  venue TEXT,
  max_participants INTEGER,
  
  organizer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  
  status event_status DEFAULT 'draft',
  is_published BOOLEAN DEFAULT FALSE,
  
  rules JSONB DEFAULT '{}', -- Event-specific rules
  metadata JSONB DEFAULT '{}', -- Additional event info
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT event_dates_valid CHECK (start_date < end_date)
);

CREATE TABLE public.weight_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  
  name TEXT NOT NULL, -- e.g., "-60 kg", "+100 kg"
  gender gender_type NOT NULL,
  min_weight DECIMAL(5,2), -- in kg
  max_weight DECIMAL(5,2), -- in kg
  age_group TEXT, -- 'cadets', 'juniors', 'seniors'
  
  max_participants INTEGER,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.event_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  weight_category_id UUID REFERENCES public.weight_categories(id) ON DELETE SET NULL,
  
  registration_date TIMESTAMPTZ DEFAULT NOW(),
  status registration_status DEFAULT 'pending',
  
  weigh_in_weight DECIMAL(5,2), -- Actual weight at weigh-in
  weigh_in_time TIMESTAMPTZ,
  
  payment_status payment_status DEFAULT 'pending',
  payment_amount NUMERIC(8,2),
  payment_date DATE,
  stripe_payment_id TEXT,
  
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(event_id, athlete_id)
);

CREATE TABLE public.registration_fees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  
  amount NUMERIC(8,2) NOT NULL,
  payment_status payment_status DEFAULT 'pending',
  payment_date DATE,
  payment_method TEXT, -- 'card', 'bank_transfer', 'cash', 'stripe'
  stripe_payment_id TEXT,
  
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(athlete_id, event_id)
);

CREATE TABLE public.athlete_event_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  weight_category_id UUID NOT NULL REFERENCES public.weight_categories(id) ON DELETE CASCADE,
  
  weigh_in_weight DECIMAL(5,2), -- Actual weight at weigh-in
  weigh_in_time TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(athlete_id, event_id)
);
);

-- ============================================================================
-- SECTION 9: BRACKETS & MATCHES (Managed by Microservice)
-- Note: These tables store results from bracket microservice
-- ============================================================================

CREATE TABLE public.brackets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  weight_category_id UUID NOT NULL REFERENCES public.weight_categories(id) ON DELETE CASCADE,
  
  bracket_type bracket_type NOT NULL,
  name TEXT,
  
  status result_status DEFAULT 'pending',
  config JSONB DEFAULT '{}', -- Bracket configuration from microservice
  
  generated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bracket_id UUID NOT NULL REFERENCES public.brackets(id) ON DELETE CASCADE,
  
  round_number INTEGER NOT NULL,
  match_number INTEGER NOT NULL,
  
  athlete1_id UUID REFERENCES public.athletes(id) ON DELETE SET NULL,
  athlete2_id UUID REFERENCES public.athletes(id) ON DELETE SET NULL,
  
  winner_id UUID REFERENCES public.athletes(id) ON DELETE SET NULL,
  
  match_status match_status DEFAULT 'scheduled',
  result_status result_status DEFAULT 'pending',
  
  scheduled_time TIMESTAMPTZ,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  
  mat_number INTEGER, -- Which mat/area
  duration_seconds INTEGER,
  
  referee_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Consolidated match actions table (replaces judo_match_points + match_points)
CREATE TABLE public.match_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  
  action_type TEXT NOT NULL, -- 'ippon', 'wazari', 'yuko', 'penalty', 'custom'
  points INTEGER DEFAULT 0,
  
  timestamp_seconds INTEGER NOT NULL, -- Time in match when action occurred
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  
  referee_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  notes TEXT,
  metadata JSONB DEFAULT '{}', -- Sport-specific data
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 10: COURSES & SCHEDULES
-- ============================================================================

CREATE TABLE public.courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  
  name TEXT NOT NULL,
  description TEXT,
  
  instructor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  day_of_week INTEGER NOT NULL, -- 0=Sunday, 6=Saturday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  
  location TEXT,
  max_participants INTEGER,
  
  start_date DATE NOT NULL,
  end_date DATE,
  
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  CONSTRAINT course_times_valid CHECK (start_time < end_time),
  CONSTRAINT day_of_week_valid CHECK (day_of_week >= 0 AND day_of_week <= 6)
);

CREATE TABLE public.course_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  
  enrollment_date DATE DEFAULT CURRENT_DATE,
  status membership_status DEFAULT 'active',
  
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(course_id, athlete_id)
);

CREATE TABLE public.course_attendances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  athlete_id UUID NOT NULL REFERENCES public.athletes(id) ON DELETE CASCADE,
  
  attendance_date DATE NOT NULL,
  status attendance_status DEFAULT 'present',
  
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(course_id, athlete_id, attendance_date)
);

-- ============================================================================
-- SECTION 11: NOTIFICATIONS
-- ============================================================================

CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  type TEXT NOT NULL, -- 'event', 'payment', 'match', 'course', 'system'
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  
  link TEXT, -- Optional deep link
  
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  
  metadata JSONB DEFAULT '{}',
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SECTION 12: INDEXES FOR PERFORMANCE
-- ============================================================================

-- Profiles indexes
CREATE INDEX idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX idx_profiles_email ON public.profiles(email);

-- Athletes indexes
CREATE INDEX idx_athletes_user_id ON public.athletes(user_id);
CREATE INDEX idx_athletes_guardian_id ON public.athletes(guardian_id);
CREATE INDEX idx_athletes_birth_date ON public.athletes(birth_date);

-- Team members indexes
CREATE INDEX idx_team_members_team_id ON public.team_members(team_id);
CREATE INDEX idx_team_members_athlete_id ON public.team_members(athlete_id);
CREATE INDEX idx_team_members_user_id ON public.team_members(user_id);

-- Memberships indexes
CREATE INDEX idx_memberships_athlete_id ON public.memberships(athlete_id);
CREATE INDEX idx_memberships_status ON public.memberships(status);
CREATE INDEX idx_memberships_dates ON public.memberships(start_date, end_date);

-- Events indexes
CREATE INDEX idx_events_organizer_id ON public.events(organizer_id);
CREATE INDEX idx_events_team_id ON public.events(team_id);
CREATE INDEX idx_events_dates ON public.events(start_date, end_date);
CREATE INDEX idx_events_status ON public.events(status);

-- Event registrations indexes
CREATE INDEX idx_event_registrations_event_id ON public.event_registrations(event_id);
CREATE INDEX idx_event_registrations_athlete_id ON public.event_registrations(athlete_id);
CREATE INDEX idx_event_registrations_status ON public.event_registrations(status);

-- Brackets indexes
CREATE INDEX idx_brackets_event_id ON public.brackets(event_id);
CREATE INDEX idx_brackets_weight_category_id ON public.brackets(weight_category_id);

-- Matches indexes
CREATE INDEX idx_matches_bracket_id ON public.matches(bracket_id);
CREATE INDEX idx_matches_athlete1_id ON public.matches(athlete1_id);
CREATE INDEX idx_matches_athlete2_id ON public.matches(athlete2_id);
CREATE INDEX idx_matches_scheduled_time ON public.matches(scheduled_time);
CREATE INDEX idx_matches_status ON public.matches(match_status);

-- Match actions indexes
CREATE INDEX idx_match_actions_match_id ON public.match_actions(match_id);
CREATE INDEX idx_match_actions_athlete_id ON public.match_actions(athlete_id);

-- Courses indexes
CREATE INDEX idx_courses_team_id ON public.courses(team_id);
CREATE INDEX idx_courses_day_of_week ON public.courses(day_of_week);
CREATE INDEX idx_courses_active ON public.courses(is_active);

-- Course enrollments indexes
CREATE INDEX idx_course_enrollments_course_id ON public.course_enrollments(course_id);
CREATE INDEX idx_course_enrollments_athlete_id ON public.course_enrollments(athlete_id);

-- Registration fees indexes
CREATE INDEX idx_registration_fees_athlete_id ON public.registration_fees(athlete_id);
CREATE INDEX idx_registration_fees_event_id ON public.registration_fees(event_id);
CREATE INDEX idx_registration_fees_payment_status ON public.registration_fees(payment_status);

-- Athlete event categories indexes
CREATE INDEX idx_athlete_event_categories_athlete_id ON public.athlete_event_categories(athlete_id);
CREATE INDEX idx_athlete_event_categories_event_id ON public.athlete_event_categories(event_id);
CREATE INDEX idx_athlete_event_categories_weight_category_id ON public.athlete_event_categories(weight_category_id);

-- Course attendances indexes
CREATE INDEX idx_course_attendances_course_id ON public.course_attendances(course_id);
CREATE INDEX idx_course_attendances_athlete_id ON public.course_attendances(athlete_id);
CREATE INDEX idx_course_attendances_date ON public.course_attendances(attendance_date);

-- Notifications indexes
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_read ON public.notifications(is_read);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at);

-- ============================================================================
-- SECTION 13: RLS SETUP NOTE
-- ============================================================================

-- Note: Row Level Security (RLS) policies will be defined in a separate file:
-- RLS_POLICIES.sql
-- 
-- RLS will enforce:
-- - Users can only see their own profile data
-- - Athletes can see their own data + guardians can see their minors
-- - Team members can see team data based on roles
-- - Coaches can see their team's athletes
-- - Organizers can manage their events
-- - Referees can update matches assigned to them
-- 
-- All tables will have RLS enabled with appropriate policies.

-- ============================================================================
-- NAMING CONVENTION (Funzioni, Trigger, Viste, Microservizi)
-- ============================================================================
-- Funzioni RPC: rpc_<azione>_<oggetto> (es: rpc_generate_bracket, rpc_update_ranking)
-- Trigger: trg_<azione>_<tabella> (es: trg_update_ranking, trg_log_action)
-- Viste: vw_<oggetto>_<descrizione> (es: vw_athletes_active, vw_events_upcoming)
-- Microservizi: msvc_<dominio> (es: msvc_match_engine, msvc_ai_analysis)
-- Endpoint REST: /api/v1/<servizio>/<azione> (es: /api/v1/competitions/generate-bracket)
--
-- Seguire questi pattern per ogni nuova entità o logica aggiunta.

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
