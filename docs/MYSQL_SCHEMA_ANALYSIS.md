# MySQL Schema Analysis - SportApp Backend

## Overview
Detailed analysis of the current MySQL database structure from `sportapp_backend_2025-12-25_111005.sql`.

**Database**: `sportapp_backend`  
**Total Tables**: 64  
**Schema Type**: Laravel-based with passport authentication

## 1. AUTHENTICATION & USER MANAGEMENT

### Core User Tables

#### `users` (11 columns)
- **Purpose**: Main user authentication and profile
- **Key Fields**: 
  - `id` BIGINT UNSIGNED (AUTO_INCREMENT)
  - `name`, `surname` VARCHAR(255)
  - `email` VARCHAR(255) UNIQUE
  - `email_verified_at` TIMESTAMP
  - `password` VARCHAR(255)
  - `two_factor_secret`, `two_factor_recovery_codes` TEXT
  - `two_factor_confirmed_at` TIMESTAMP
  - `remember_token` VARCHAR(100)
  - `timestamps` (created_at, updated_at)
- **Indexes**: email_unique, users_email_index
- **RLS Strategy**: User can read/update own profile
- **Supabase Mapping**: Migrate to `auth.users` + custom `profiles` table

#### `oauth_access_tokens` (9 columns)
- **Purpose**: Laravel Passport OAuth tokens
- **Key Fields**: id, user_id, client_id, name, scopes TEXT, revoked TINYINT(1), expires_at
- **Supabase Mapping**: NOT NEEDED - Supabase handles auth tokens natively

#### `oauth_auth_codes`, `oauth_clients`, `oauth_personal_access_clients`, `oauth_refresh_tokens`
- **Purpose**: Laravel Passport infrastructure
- **Supabase Mapping**: NOT NEEDED - Replace entirely with Supabase Auth

### Password Resets

#### `password_reset_tokens`
- **Purpose**: Password reset flow
- **Fields**: email (PRIMARY), token, created_at
- **Supabase Mapping**: NOT NEEDED - Supabase Auth handles password resets

#### `password_resets` 
- **Purpose**: Legacy password resets table
- **Supabase Mapping**: NOT NEEDED

---

## 2. ATHLETE & MEMBERSHIP MANAGEMENT

### Core Athlete Tables

#### `athletes` (18 columns)
- **Purpose**: Main athlete profiles and data
- **Key Fields**:
  - `id` BIGINT UNSIGNED
  - `user_id` BIGINT UNSIGNED (FK to users)
  - `name`, `surname` VARCHAR(255)
  - `date_of_birth` DATE
  - `gender` ENUM('male','female','other')
  - `fiscal_code` VARCHAR(255)
  - `phone`, `email` VARCHAR(255)
  - `address`, `city`, `province`, `postal_code`, `country` VARCHAR(255)
  - `emergency_contact_name`, `emergency_contact_phone` VARCHAR(255)
  - `medical_certificate_expiry` DATE
  - `timestamps`
- **Indexes**: athletes_user_id_foreign
- **RLS Strategy**: Athletes can read own data, guardians can read/update minors, coaches/admins can read team athletes
- **Supabase Mapping**: `public.athletes` with RLS policies
- **Optimization**: Consider splitting address into separate `addresses` table for normalization

#### `guardians` (9 columns)
- **Purpose**: Legal guardians for minor athletes
- **Key Fields**:
  - `id` BIGINT UNSIGNED
  - `athlete_id` BIGINT UNSIGNED (FK to athletes)
  - `user_id` BIGINT UNSIGNED (FK to users) - Guardian's account
  - `name`, `surname` VARCHAR(255)
  - `relationship` VARCHAR(255)
  - `phone`, `email` VARCHAR(255)
  - `timestamps`
- **Indexes**: guardians_athlete_id_foreign, guardians_user_id_foreign
- **RLS Strategy**: Guardian can read/update linked minor athlete data
- **Supabase Mapping**: `public.guardians` with athlete_id FK
- **Critical**: MVP must preserve guardian-minor access control

### Membership & Payments

#### `memberships` (11 columns)
- **Purpose**: Club membership subscriptions
- **Key Fields**:
  - `id` BIGINT UNSIGNED
  - `athlete_id` BIGINT UNSIGNED (FK)
  - `membership_type_id` BIGINT UNSIGNED (FK)
  - `start_date`, `end_date` DATE
  - `status` ENUM('active','expired','suspended','cancelled')
  - `payment_status` ENUM('paid','pending','partial','overdue')
  - `amount` DECIMAL(8,2)
  - `payment_date` DATE
  - `notes` TEXT
  - `timestamps`
- **RLS Strategy**: Athlete/guardian can read own memberships, admin can manage all
- **Supabase Mapping**: `public.memberships`

#### `membership_types` (7 columns)
- **Purpose**: Different membership tier definitions
- **Key Fields**: id, name, description TEXT, price DECIMAL(8,2), duration_months INT, is_active TINYINT(1), timestamps
- **RLS Strategy**: Public read, admin write
- **Supabase Mapping**: `public.membership_types`

#### `registration_fees` (9 columns)
- **Purpose**: Event/competition registration fees
- **Key Fields**: id, athlete_id, event_id, amount DECIMAL(8,2), payment_status ENUM, payment_date, payment_method VARCHAR(255), timestamps
- **RLS Strategy**: Athlete can read own, admin can manage
- **Supabase Mapping**: `public.registration_fees`

---

## 3. COMPETITION & EVENT MANAGEMENT

### Core Event Tables

#### `events` (11 columns)
- **Purpose**: Main competition/event definitions
- **Key Fields**: id, name VARCHAR(255), description TEXT, event_date DATE, location VARCHAR(255), registration_deadline DATE, max_participants INT, status ENUM('draft','published','ongoing','completed','cancelled'), timestamps
- **RLS Strategy**: Public read for published, admin full control
- **Supabase Mapping**: `public.events`

#### `event_registrations` (8 columns)
- **Purpose**: Athlete registrations to events
- **Key Fields**: id, event_id, athlete_id, registration_date, status ENUM('pending','confirmed','cancelled','checked_in'), notes TEXT, timestamps
- **RLS Strategy**: Athlete can register self, view own registrations, admin can manage
- **Supabase Mapping**: `public.event_registrations`

### Weight Categories & Divisions

#### `weight_categories` (7 columns)
- **Purpose**: Weight class definitions for judo competitions
- **Key Fields**: id, name VARCHAR(255), min_weight DECIMAL(5,2), max_weight DECIMAL(5,2), gender ENUM('male','female','mixed'), age_category VARCHAR(255), timestamps
- **RLS Strategy**: Public read, admin write
- **Supabase Mapping**: `public.weight_categories`

#### `athlete_event_category` (6 columns)
- **Purpose**: Links athletes to their specific category in an event
- **Key Fields**: id, athlete_id, event_id, weight_category_id, weigh_in_result DECIMAL(5,2), timestamps
- **RLS Strategy**: Public read for confirmed, admin write
- **Supabase Mapping**: `public.athlete_categories` (renamed for clarity)

### Competition Brackets & Matches

#### `brackets` (10 columns)
- **Purpose**: Tournament bracket structures
- **Key Fields**: id, event_id, weight_category_id, name VARCHAR(255), bracket_type ENUM('single_elimination','double_elimination','round_robin','pool'), status ENUM('pending','in_progress','completed'), bracket_data JSON, timestamps
- **RLS Strategy**: Public read, admin write
- **Supabase Mapping**: `public.brackets`
- **Note**: JSON field for flexibility in bracket structure
- **MICROSERVICE CANDIDATE**: Bracket generation logic should remain in separate service

#### `matches` (13 columns)
- **Purpose**: Individual match/bout records
- **Key Fields**:
  - `id` BIGINT UNSIGNED
  - `bracket_id` BIGINT UNSIGNED
  - `event_id` BIGINT UNSIGNED
  - `athlete1_id`, `athlete2_id` BIGINT UNSIGNED
  - `round` INT - Tournament round number
  - `match_number` INT
  - `scheduled_time` DATETIME
  - `actual_start_time`, `actual_end_time` DATETIME
  - `winner_id` BIGINT UNSIGNED (FK to athletes)
  - `status` ENUM('scheduled','in_progress','completed','cancelled')
  - `timestamps`
- **Indexes**: matches_bracket_id_foreign, matches_event_id_foreign, matches_athlete1_id_foreign, matches_athlete2_id_foreign, matches_winner_id_foreign
- **RLS Strategy**: Public read, referees/admin write
- **Supabase Mapping**: `public.matches`
- **Performance**: Index on event_id + status for live event queries

### Match Scoring Tables - **REDUNDANCY IDENTIFIED**

#### `match_points` (10 columns)
- **Purpose**: Generic point scoring system
- **Key Fields**: id, match_id, athlete_id, point_type VARCHAR(255), points INT, timestamp DATETIME, referee_id BIGINT UNSIGNED, notes TEXT, timestamps
- **Issues**: Overlaps with judo_match_points

#### `judo_match_points` (10 columns)
- **Purpose**: Judo-specific scoring
- **Key Fields**: id, match_id, athlete_id, point_type ENUM('ippon','waza_ari','yuko','koka','shido','hansoku_make'), points INT, timestamp DATETIME, referee_id, notes TEXT, timestamps
- **Issues**: Duplicates match_points functionality

#### `match_actions` (11 columns)
- **Purpose**: Detailed match event log
- **Key Fields**: id, match_id, athlete_id, action_type VARCHAR(255), action_value VARCHAR(255), timestamp DATETIME, referee_id, video_timestamp VARCHAR(255), notes TEXT, timestamps
- **Issues**: Could serve as unified event store

### 🔴 OPTIMIZATION RECOMMENDATION:
**CONSOLIDATE** `match_points` + `judo_match_points` → Single `match_actions` table
- Use JSONB `action_data` field for flexibility
- `action_type` ENUM: 'ippon', 'waza_ari', 'shido', 'penalty', 'technique', 'video_event'
- Single source of truth for all match events
- Better for real-time event streaming
- Easier AI analysis integration

**Supabase Mapping**: `public.match_actions` (unified)
**RLS Strategy**: Public read, referees/admin write

---

## 4. TEAM & ROLE MANAGEMENT

#### `teams` (7 columns)
- **Purpose**: Sports club/team management
- **Key Fields**: id, name VARCHAR(255), description TEXT, logo_url VARCHAR(255), is_active TINYINT(1), timestamps
- **Supabase Mapping**: `public.teams`

#### `team_members` (6 columns)
- **Purpose**: Links athletes to teams
- **Key Fields**: id, team_id, athlete_id, role ENUM('athlete','coach','staff'), joined_date DATE, timestamps
- **Supabase Mapping**: `public.team_members`

#### `roles` (5 columns)
- **Purpose**: User role definitions
- **Key Fields**: id, name VARCHAR(255), description TEXT, permissions JSON, timestamps
- **Supabase Mapping**: Custom `public.roles` + use Supabase custom claims

#### `user_roles` (5 columns)
- **Purpose**: Assigns roles to users
- **Key Fields**: id, user_id, role_id, granted_at TIMESTAMP, timestamps
- **Supabase Mapping**: Use Supabase `auth.users.raw_user_meta_data` for role claims

---

## 5. CALENDAR & SCHEDULING

#### `courses` (9 columns)
- **Purpose**: Training course/class definitions
- **Key Fields**: id, name VARCHAR(255), description TEXT, instructor_id BIGINT UNSIGNED, day_of_week ENUM, start_time TIME, end_time TIME, is_active TINYINT(1), timestamps
- **RLS Strategy**: Public read active courses, admin/instructors write
- **Supabase Mapping**: `public.courses`

#### `course_enrollments` (6 columns)
- **Purpose**: Athletes enrolled in courses
- **Key Fields**: id, course_id, athlete_id, enrollment_date DATE, status ENUM('active','inactive','completed'), timestamps
- **Supabase Mapping**: `public.course_enrollments`

#### `course_attendances` (7 columns)
- **Purpose**: Track attendance for each course session
- **Key Fields**: id, course_id, athlete_id, attendance_date DATE, status ENUM('present','absent','excused','late'), notes TEXT, timestamps
- **Supabase Mapping**: `public.course_attendances`

---

## 6. ADDITIONAL SUPPORT TABLES

#### `notifications` (9 columns)
- **Purpose**: User notification system
- **Key Fields**: id, user_id, type VARCHAR(255), title VARCHAR(255), message TEXT, is_read TINYINT(1), action_url VARCHAR(255), timestamps
- **Supabase Mapping**: Could use Supabase Realtime + custom notifications table

#### `failed_jobs` (6 columns)
- **Purpose**: Laravel queue failed jobs
- **Supabase Mapping**: NOT NEEDED - Use external queue service (BullMQ, etc.)

#### `jobs` (4 columns)
- **Purpose**: Laravel queue jobs
- **Supabase Mapping**: NOT NEEDED - External queue

#### `job_batches` (9 columns)
- **Purpose**: Laravel batch job tracking
- **Supabase Mapping**: NOT NEEDED

#### `migrations` (3 columns)
- **Purpose**: Laravel migration history
- **Supabase Mapping**: NOT NEEDED - Supabase handles migrations differently

#### `personal_access_tokens` (8 columns)
- **Purpose**: Sanctum API tokens
- **Supabase Mapping**: NOT NEEDED - Supabase Auth handles API tokens

#### `sessions` (7 columns)
- **Purpose**: Laravel session storage
- **Supabase Mapping**: NOT NEEDED - Handle sessions client-side or use Supabase session

#### `cache`, `cache_locks` 
- **Purpose**: Laravel cache layer
- **Supabase Mapping**: Use Redis/Upstash or Supabase edge functions

---

## 7. SCHEMA OPTIMIZATION SUMMARY

### Tables to MIGRATE (Core Business Logic): 38 tables

**Authentication & Users**: 
- `users` → Split into `auth.users` + `public.profiles`

**Athletes & Guardians**: 
- `athletes`, `guardians`

**Membership & Payments**:
- `memberships`, `membership_types`, `registration_fees`

**Events & Competitions**:
- `events`, `event_registrations`, `weight_categories`, `athlete_event_category` → `athlete_categories`

**Brackets & Matches**:
- `brackets`, `matches`
- **CONSOLIDATED**: `match_actions` (unified from match_points + judo_match_points + match_actions)

**Teams & Roles**:
- `teams`, `team_members`, `roles`, `user_roles`

**Calendar & Courses**:
- `courses`, `course_enrollments`, `course_attendances`

**Notifications**:
- `notifications`

### Tables to DROP (Laravel/Passport Infrastructure): 16 tables
- All `oauth_*` tables (5)
- `password_reset_tokens`, `password_resets`
- `personal_access_tokens`, `sessions`
- `failed_jobs`, `jobs`, `job_batches`
- `migrations`
- `cache`, `cache_locks`

### Key Data Type Conversions

**MySQL → PostgreSQL**:
- `BIGINT UNSIGNED` → `BIGINT` (PostgreSQL doesn't have unsigned)
- `TINYINT(1)` → `BOOLEAN`
- `DATETIME` → `TIMESTAMPTZ` (timezone aware)
- `ENUM()` → `TEXT` with CHECK constraints or custom ENUM types
- `DECIMAL(8,2)` → `NUMERIC(8,2)`
- `VARCHAR(255)` → `TEXT` (PostgreSQL TEXT is more efficient)
- `JSON` → `JSONB` (binary JSON, faster queries)

### Performance Indexes Required

**High Priority**:
```sql
-- Real-time event queries
CREATE INDEX idx_matches_event_status ON matches(event_id, status);
CREATE INDEX idx_match_actions_match_timestamp ON match_actions(match_id, timestamp);

-- Authentication lookups
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_athletes_user_id ON athletes(user_id);

-- Guardian access
CREATE INDEX idx_guardians_athlete_user ON guardians(athlete_id, user_id);

-- Event registrations
CREATE INDEX idx_registrations_athlete_event ON event_registrations(athlete_id, event_id);
```

---

## 8. MIGRATION STRATEGY

### Phase 1: Foundation (Week 1-2)
1. Set up Supabase project
2. Migrate auth: `users` → `auth.users` + `profiles`
3. Migrate core athlete data: `athletes`, `guardians`
4. Implement basic RLS policies
5. Test guardian-minor access control

### Phase 2: Business Logic (Week 3-4)
1. Migrate membership system
2. Migrate teams and roles
3. Migrate calendar/courses
4. Migrate events and registrations
5. Set up payment tracking

### Phase 3: Competition Engine (Week 5-6)
1. Migrate brackets and matches structure
2. **CRITICAL**: Consolidate scoring into unified match_actions
3. Migrate existing match_points + judo_match_points data
4. Set up real-time subscriptions for live events
5. Test with 1000 concurrent connections

### Phase 4: Microservices (Week 7-8)
1. Extract bracket generation logic to separate service
2. Set up YouTube/TikTok streaming service
3. Prepare AI analysis pipeline integration
4. Edge functions for complex business rules

---

## 9. CRITICAL MVP REQUIREMENTS

### Must Preserve:
1. Guardian-Minor Access Control: RLS policies for guardian to athlete data access
2. Multi-role Support: Athletes can have linked user accounts + guardians
3. Payment Tracking: Membership fees + registration fees
4. Course Calendar: Training schedule and attendance
5. Competition Brackets: Tournament structure and match assignment
6. Real-time Scoring: Live match updates for 1000+ concurrent users

### Can Defer to Post-MVP:
- Advanced AI match analysis
- Live streaming to YouTube/TikTok
- Automated bracket generation (keep simple manual/semi-auto for MVP)
- Complex notification system

---

## 10. ESTIMATED RESOURCE REQUIREMENTS

### Supabase Free Tier Limits:
- 500 MB database (current MySQL ~200MB with test data)
- 1 GB file storage
- 2 GB bandwidth
- 50K monthly active users

### Recommended: Supabase Pro ($25/month)
- 8 GB database
- 100 GB file storage
- 250 GB bandwidth
- Connection pooling for 1000+ concurrent
- Better for MVP

### External Services Needed:
- **Queue**: Upstash Redis or BullMQ (~$10/month)
- **File Storage**: Consider Cloudflare R2 for videos (~$5/month)
- **Microservices**: Vercel/Railway for bracket generation (~$20/month)

**Total Est: $55-60/month for MVP**

---

## Next Steps

1. Review this schema analysis
2. Create detailed Supabase SQL migration scripts
3. Define all RLS policies in AUTH_RLS_DESIGN.md
4. Update DB_MAPPING_MYSQL_TO_SUPABASE.md with final table mapping
5. Create data migration scripts for existing test data
6. Set up Supabase project and test schema

---

**Analysis Date**: 2025-12-25  
**Source**: sportapp_backend_2025-12-25_111005.sql  
**Analyzed By**: Schema migration planning for Athlos_supabase project
