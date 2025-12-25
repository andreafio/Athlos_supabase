-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES FOR ATHLOS SUPABASE
-- ============================================================================
-- This file contains all RLS policies for the Athlos Supabase database.
-- These policies enforce data access control at the database level.
--
-- Date: 2025-01
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membership_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.weight_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brackets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ==========================================================================
-- PROFILES: Users can manage their own profile
-- ==========================================================================

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ==========================================================================
-- ATHLETES: Own data + guardians + coaches
-- ==========================================================================

CREATE POLICY "Athletes can view own data" ON public.athletes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Guardians can view their minors" ON public.athletes
  FOR SELECT USING (
    guardian_id IN (SELECT id FROM public.guardians WHERE user_id = auth.uid())
  );

CREATE POLICY "Coaches can view team athletes" ON public.athletes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      WHERE tm.athlete_id = athletes.id
      AND tm.team_id IN (
        SELECT team_id FROM public.team_members
        WHERE user_id = auth.uid() AND role = 'coach'
      )
    )
  );

-- ==========================================================================
-- EVENTS: Published events visible to all, organizers manage own
-- ==========================================================================

CREATE POLICY "Published events visible to all" ON public.events
  FOR SELECT USING (is_published = true AND auth.uid() IS NOT NULL);

CREATE POLICY "Organizers can view own events" ON public.events
  FOR SELECT USING (organizer_id = auth.uid());

CREATE POLICY "Organizers can manage own events" ON public.events
  FOR ALL USING (organizer_id = auth.uid());

-- ==========================================================================
-- REGISTRATIONS: Athletes register, organizers view
-- ==========================================================================

CREATE POLICY "Athletes view own registrations" ON public.event_registrations
  FOR SELECT USING (
    athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
  );

CREATE POLICY "Organizers view event registrations" ON public.event_registrations
  FOR SELECT USING (
    event_id IN (SELECT id FROM public.events WHERE organizer_id = auth.uid())
  );

CREATE POLICY "Athletes can register" ON public.event_registrations
  FOR INSERT WITH CHECK (
    athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
  );

-- ==========================================================================
-- MATCHES: Visible for published events, referees update
-- ==========================================================================

CREATE POLICY "Matches in published events visible" ON public.matches
  FOR SELECT USING (
    bracket_id IN (
      SELECT b.id FROM public.brackets b
      JOIN public.events e ON b.event_id = e.id
      WHERE e.is_published = true
    )
  );

CREATE POLICY "Referees update assigned matches" ON public.matches
  FOR UPDATE USING (referee_id = auth.uid());

CREATE POLICY "Organizers manage event matches" ON public.matches
  FOR ALL USING (
    bracket_id IN (
      SELECT b.id FROM public.brackets b
      JOIN public.events e ON b.event_id = e.id
      WHERE e.organizer_id = auth.uid()
    )
  );

-- ==========================================================================
-- MEMBERSHIPS: Athletes + guardians + team admins view
-- ==========================================================================

CREATE POLICY "Athletes view own memberships" ON public.memberships
  FOR SELECT USING (
    athlete_id IN (SELECT id FROM public.athletes WHERE user_id = auth.uid())
  );

CREATE POLICY "Guardians view minors memberships" ON public.memberships
  FOR SELECT USING (
    athlete_id IN (
      SELECT id FROM public.athletes WHERE guardian_id IN (
        SELECT id FROM public.guardians WHERE user_id = auth.uid()
      )
    )
  );

-- ==========================================================================
-- NOTIFICATIONS: Users manage own notifications
-- ==========================================================================

CREATE POLICY "Users view own notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users update own notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- ==========================================================================
-- PUBLIC READ POLICIES
-- ==========================================================================

-- Active membership types visible to all authenticated users
CREATE POLICY "Active membership types visible" ON public.membership_types
  FOR SELECT USING (is_active = true AND auth.uid() IS NOT NULL);

-- Weight categories for published events
CREATE POLICY "Weight categories visible" ON public.weight_categories
  FOR SELECT USING (
    event_id IN (SELECT id FROM public.events WHERE is_published = true)
  );

-- Brackets for published events
CREATE POLICY "Brackets visible" ON public.brackets
  FOR SELECT USING (
    event_id IN (SELECT id FROM public.events WHERE is_published = true)
  );

-- Roles visible to authenticated users
CREATE POLICY "Roles visible" ON public.roles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- ==========================================================================
-- TEAMS: Members view their teams, admins manage
-- ==========================================================================

CREATE POLICY "Team members view their teams" ON public.teams
  FOR SELECT USING (
    id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() OR athlete_id IN (
        SELECT id FROM public.athletes WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Public teams visible" ON public.teams
  FOR SELECT USING (is_public = true AND auth.uid() IS NOT NULL);

CREATE POLICY "Team admins manage teams" ON public.teams
  FOR ALL USING (
    id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() AND role = 'admin'
    )
  );

-- ==========================================================================
-- COURSES: Team members view, instructors manage
-- ==========================================================================

CREATE POLICY "Team members view courses" ON public.courses
  FOR SELECT USING (
    team_id IN (
      SELECT team_id FROM public.team_members
      WHERE user_id = auth.uid() OR athlete_id IN (
        SELECT id FROM public.athletes WHERE user_id = auth.uid()
      )
    )
  );

CREATE POLICY "Instructors manage courses" ON public.courses
  FOR ALL USING (instructor_id = auth.uid());

-- ==========================================================================
-- GUARDIANS: Own data only
-- ==========================================================================

CREATE POLICY "Guardians view own data" ON public.guardians
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Guardians update own data" ON public.guardians
  FOR UPDATE USING (auth.uid() = user_id);

-- ==========================================================================
-- Note: Additional policies can be added as needed.
-- Always test policies thoroughly before deploying to production.
-- ==========================================================================
