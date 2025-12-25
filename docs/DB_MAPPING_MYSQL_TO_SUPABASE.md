# Database Mapping: MySQL to Supabase (PostgreSQL)

## Overview
This document details the migration strategy from the current Laravel/MySQL architecture to Supabase (PostgreSQL) with optimizations and consolidations.

> **Detailed Analysis**: For a comprehensive table-by-table breakdown of all 64 MySQL tables, data type conversions, and migration phases, see [MYSQL_SCHEMA_ANALYSIS.md](./MYSQL_SCHEMA_ANALYSIS.md).

## Key Migration Principles

1. **Normalization**: Consolidate redundant tables (e.g., judo_match_points + match_points)
2. **Separation of Concerns**: Keep complex competition logic in microservices
3. **Performance**: Optimize for 1000 concurrent users with 3000 athletes across 4 events/year
4. **Auth/Security**: Move all permissions to Supabase RLS (Row-Level Security)

---

## Table Consolidation Strategy

### MERGE: judo_match_points + match_points → match_actions
**Reason**: Both tables track point scoring with sport-specific logic. A unified table with `sport_type` discriminator reduces redundancy.

**MySQL Structure**:
```sql
-- Current (redundant)
CREATE TABLE judo_match_points (
  id INT PRIMARY KEY,
  match_id INT,
  athlete_id INT,
  points INT,
  technique VARCHAR(50),
  timestamp DATETIME
);

CREATE TABLE match_points (
  id INT PRIMARY KEY,
  match_id INT,
  athlete_id INT,
  points INT,
  action_type VARCHAR(50),
  timestamp DATETIME
);
```

**Supabase Target**:
```sql
CREATE TABLE match_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id),
  athlete_id UUID NOT NULL REFERENCES athletes(id),
  action_type VARCHAR(50) NOT NULL, -- 'shido', 'waza_ari', 'ippon', 'penalty', etc.
  sport_type VARCHAR(20) NOT NULL, -- 'judo', 'wrestling', etc.
  points INT NOT NULL,
  metadata JSONB, -- sport-specific data (technique, description, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  INDEX: (match_id, created_at)
);
```

### MERGE: athlete_ranking + ranking → unified_rankings
**Reason**: Duplicate ranking tables (static vs. dynamic). Consolidate with status flag.

**Action**: Merge `athlete_ranking` into `rankings` table with `is_official` boolean.

### REMOVE: Redundant Timestamp Columns
**Tables Affected**: All tables with both `created_at` and `updated_at`
**Action**: Keep only `created_at` + `updated_at` for audit trail (no `timestamp`, `date_created`, etc.)

### DENORMALIZE: category_athletes → matches
**Reason**: Category assignments don't change mid-tournament. Store `category_id` in matches for fast filtering.

**New Column**:
```sql
ALTER TABLE matches ADD COLUMN category_id UUID REFERENCES categories(id);
```

---

## Full Table Mapping

| MySQL Table | Supabase Table | Status | Notes |
|---|---|---|---|
| athletes | athletes | ✓ Direct | Add RLS policies for coach/athlete access |
| categories | categories | ✓ Direct | Add cascade deletes |
| events | events | ✓ Direct | Add RLS for organizers |
| matches | matches | ✓ Optimized | Add category_id, sport_type denormalization |
| judo_match_points + match_points | match_actions | 🔄 Merge | Unified scoring table with sport_type discriminator |
| athlete_ranking + ranking | rankings | 🔄 Merge | Keep single ranking table, add is_official flag |
| team | team | ✓ Direct | Add org_id for multi-tenant support |
| judo_match_detail | match_metadata | ✓ Rename | Store as JSONB in matches.metadata |
| event_type | event_types | ✓ Direct | Standard lookup |
| user_permissions | auth.authorization_roles | ✓ Move to Auth | Use Supabase auth with RLS |
| tokens | sessions | ✓ Move to Auth | Supabase auth handles JWT tokens |

---

## Complex Logic Separation

### NOT in Supabase (Microservices Only)
1. **Bracket Generation**: Tournament-specific logic (Swiss, elimination, round-robin)
2. **Match Assignment**: Intelligent pairing based on weight/category/skill
3. **AI Match Analysis**: Real-time video processing for YouTube/TikTok streaming
4. **Live Feed Processing**: Event streaming to third-party platforms

### IN Supabase RLS
1. **Authentication**: User creation, password reset, session management
2. **Authorization**: Row-level security based on roles (admin, organizer, coach, athlete)
3. **Basic CRUD**: Insert/update/read operations on matches, athletes, events
4. **Read-only Queries**: Public leaderboards, event schedules

---

## RLS Policies (By Table)

### athletes
```sql
-- Athletes can see their own profile
CREATE POLICY "athletes_view_own" ON athletes
  FOR SELECT USING (auth.uid() = user_id OR is_public = true);

-- Coaches can see their athletes
CREATE POLICY "coaches_view_athletes" ON athletes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM athlete_coach_mapping
      WHERE coach_user_id = auth.uid() AND athlete_id = id
    )
  );
```

### matches
```sql
-- All users see matches for their registered event
CREATE POLICY "matches_view_registered" ON matches
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM event_registrations
      WHERE user_id = auth.uid() AND event_id = matches.event_id
    )
    OR is_public = true
  );
```

### match_actions
```sql
-- Admins and match officials can insert
CREATE POLICY "actions_insert" ON match_actions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM match_officials
      WHERE user_id = auth.uid() AND match_id = match_actions.match_id
    )
    OR is_admin(auth.uid())
  );
```

---

## Data Type Conversions

| MySQL Type | PostgreSQL/Supabase Type | Reason |
|---|---|---|
| INT AUTO_INCREMENT | UUID (gen_random_uuid()) | Better for distributed systems, DDoS resistance |
| DATETIME | TIMESTAMPTZ | Timezone awareness for global events |
| LONGTEXT | TEXT / JSONB | JSONB for structured metadata |
| TINYINT (bool) | BOOLEAN | Native boolean type |
| ENUM | VARCHAR with CHECK | More flexible, easier to extend |
| VARCHAR(255) | TEXT (indexed) | PostgreSQL has no practical limit, smaller overhead |

---

## Performance Indexes

```sql
-- Athletes
CREATE INDEX idx_athletes_user_id ON athletes(user_id);
CREATE INDEX idx_athletes_event_id ON athletes(event_id);

-- Matches (most frequently queried)
CREATE INDEX idx_matches_event_id ON matches(event_id);
CREATE INDEX idx_matches_category_id ON matches(category_id);
CREATE INDEX idx_matches_status ON matches(status) WHERE status != 'completed';
CREATE INDEX idx_matches_created ON matches(created_at DESC);

-- Match Actions (highest volume, most frequently read)
CREATE INDEX idx_actions_match_id ON match_actions(match_id, created_at DESC);
CREATE INDEX idx_actions_athlete_id ON match_actions(athlete_id);

-- Rankings
CREATE INDEX idx_rankings_event_id ON rankings(event_id);
CREATE INDEX idx_rankings_points ON rankings(points DESC) WHERE is_official = true;
```

---

## Migration Phases

### Phase 1: Data Import (Week 1)
- Export MySQL dump
- Transform and consolidate tables
- Import to Supabase PostgreSQL
- Validate data integrity

### Phase 2: Auth Migration (Week 2)
- Migrate user_permissions → Supabase auth
- Set up RLS policies
- Test access control
- Deactivate legacy token system

### Phase 3: API Refactoring (Week 3-4)
- Update REST API endpoints to use Supabase client
- Test with live database
- Create Supabase RPC functions for complex queries

### Phase 4: Microservice Integration (Week 5-6)
- Connect competition engine to PostgreSQL
- Test bracket generation with live data
- Implement match assignment logic

---

## Optimization Summary

✅ **Consolidations Achieved**:
- 2 → 1 (match_points tables)
- 2 → 1 (ranking tables)
- Legacy tokens → Supabase auth
- 5 permission tables → RLS policies

✅ **Storage Reduction**: ~35-40% smaller schema (estimated)

✅ **Performance Gains**:
- Faster ranking queries (single table scan)
- Reduced JOIN complexity for scoring
- Native UUID indexing better than INT
- JSONB metadata eliminates future schema changes

✅ **Maintainability**: Fewer tables to manage, centralized auth, clear data flow
