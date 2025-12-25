# Architecture Overview: Athlos Supabase Migration

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                            │
│  Web (Next.js) │ Mobile (React Native) │ Admin Dashboard   │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────┐
│              REST API & Real-time Subscriptions             │
│  (Supabase PostgREST) + Supabase Realtime WebSockets       │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────┐
│         AUTH LAYER (Supabase Authentication)               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ JWT Tokens │ Session Management │ RLS Policies      │   │
│  └─────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────┴────────────────────────────────┐
│              DATA LAYER (Supabase PostgreSQL)              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Tables: athletes │ matches │ rankings │ events │    │   │
│  │ match_actions │ team │ categories │ ...           │   │
│  │                                                      │   │
│  │ RLS Policies │ Triggers │ Functions (RPC)          │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────┘
                             │
         ┌───────────────────┴──────────────────┐
         │                                      │
┌────────┴──────────┐             ┌───────────┴──────────┐
│  MICROSERVICES    │             │ EXTERNAL SERVICES    │
│  (Node.js/Python) │             │                      │
│                   │             │ YouTube Live API     │
│ • Bracket Gen     │             │ TikTok API           │
│ • Match Engine    │             │ Google AI Studio     │
│ • AI Analysis     │             │ (Match Analysis)     │
│ • Live Streaming  │             │                      │
│   Orchestrator    │             │                      │
└───────────────────┘             └──────────────────────┘
```

## Component Breakdown

### 1. Client Layer

**Frontend Technologies**:
- **Web**: Next.js 14+ with TypeScript
- **Mobile**: React Native / Expo (future)
- **Admin Dashboard**: Next.js + Tailwind CSS
- **Real-time**: Supabase JavaScript SDK for subscriptions

**Responsibilities**:
- User authentication via Supabase Auth UI
- Fetch athletes, events, match schedules via REST API
- Subscribe to live match updates via WebSocket
- Display leaderboards and rankings
- Queue match officials for live updates

### 2. API Layer

**Supabase PostgREST**:
- Auto-generated REST endpoints for all tables
- Query filtering, sorting, pagination via HTTP API
- Authentication via JWT tokens in Authorization header

**Supabase Realtime**:
- WebSocket subscriptions to specific tables
- Broadcast channel for real-time match updates
- Example: Listen to `match_actions` table for score changes

**Example Request**:
```javascript
// Fetch matches for an event
const { data: matches } = await supabase
  .from('matches')
  .select('*')
  .eq('event_id', eventId)
  .order('created_at', { ascending: false });

// Subscribe to score changes
supabase
  .from(`match_actions:match_id=eq.${matchId}`)
  .on('*', payload => {
    console.log('New action:', payload.new);
  })
  .subscribe();
```

### 3. Authentication & Authorization (RLS)

**Auth Strategy**:
1. User signs up/logs in via Supabase Auth
2. JWT token issued by Supabase
3. Client includes JWT in all API requests
4. Supabase validates JWT + applies RLS policies
5. Middleware enforces role-based access

**Roles**:
- **Admin**: Full access to all data and settings
- **Organizer**: Can manage events, athletes, matches
- **Coach**: Can view/update only their registered athletes
- **Athlete**: Can view own profile, public rankings, registered matches
- **Official**: Can submit match actions (scores, penalties)

**RLS Policies** (Examples):
```sql
-- Athletes can view their own profile
CREATE POLICY "athletes_view_own"
  ON athletes FOR SELECT
  USING (auth.uid() = user_id OR is_public = true);

-- Coaches see only their athletes
CREATE POLICY "coaches_view_assigned"
  ON athletes FOR SELECT
  USING (
    auth.uid() = user_id 
    OR EXISTS (
      SELECT 1 FROM athlete_coach_mapping
      WHERE coach_user_id = auth.uid()
      AND athlete_id = id
    )
  );

-- Match officials can insert actions
CREATE POLICY "officials_insert_actions"
  ON match_actions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM match_officials
      WHERE user_id = auth.uid()
      AND match_id = match_actions.match_id
    )
  );
```

### 4. Data Layer (PostgreSQL/Supabase)

**Schema Overview**:
```
ATHLETES
├─ id (UUID, PK)
├─ user_id (FK to auth.users)
├─ first_name, last_name
├─ weight_class
├─ sport_type
├─ is_public (BOOLEAN)
└─ created_at, updated_at

EVENTS
├─ id (UUID, PK)
├─ title
├─ description
├─ organizer_id (FK to auth.users)
├─ status ('draft', 'registration', 'active', 'completed')
├─ start_date, end_date
└─ metadata (JSONB: location, rules, etc.)

MATCHES
├─ id (UUID, PK)
├─ event_id (FK to events)
├─ category_id (FK to categories)
├─ athlete_1_id (FK to athletes)
├─ athlete_2_id (FK to athletes)
├─ status ('pending', 'scheduled', 'in_progress', 'completed')
├─ winner_id (FK to athletes, nullable)
├─ start_time, end_time
└─ metadata (JSONB: bracket_position, round, etc.)

MATCH_ACTIONS (Consolidated from judo_match_points + match_points)
├─ id (UUID, PK)
├─ match_id (FK to matches)
├─ athlete_id (FK to athletes)
├─ action_type ('shido', 'waza_ari', 'ippon', 'penalty', 'timeout')
├─ sport_type ('judo', 'wrestling', etc.)
├─ points (INT)
├─ metadata (JSONB: technique, description)
└─ created_at

RANKINGS (Consolidated from athlete_ranking + ranking)
├─ id (UUID, PK)
├─ athlete_id (FK to athletes)
├─ event_id (FK to events)
├─ points (INT)
├─ rank (INT)
├─ is_official (BOOLEAN)
└─ updated_at
```

**Performance Indexes**:
- `idx_matches_event_id` - Fast filtering by event
- `idx_matches_status` - Filter active matches
- `idx_actions_match_id` - Order actions by timestamp
- `idx_rankings_points` - Sort by points (public leaderboards)
- `idx_athletes_user_id` - Quick user lookups

### 5. Microservices Layer

**Purpose**: Handle complex, CPU-intensive logic that shouldn't run in database

**Services**:

#### a) Competition Engine
**Tech**: Node.js / Python (FastAPI)
**Responsibilities**:
- Bracket generation (Swiss, single-elimination, round-robin)
- Intelligent match assignment based on:
  - Weight class
  - Skill rating
  - Previous opponents
  - Geographic location (if applicable)
- Automatic ranking updates after each match
- Tournament flow orchestration

**API Endpoints**:
```
POST /api/competitions/generate-bracket
  Input: { event_id, tournament_type, athletes[] }
  Output: { matches[] }

POST /api/competitions/assign-matches
  Input: { available_athletes[], weight_class, skill_tier }
  Output: { match_assignments[] }

POST /api/competitions/update-rankings
  Input: { match_id, winner_id }
  Output: { updated_rankings[] }
```

**Database Interaction**: 
- Reads: athletes, matches, rankings via Supabase
- Writes: match updates, ranking changes back to Supabase

#### b) AI Match Analysis Service
**Tech**: Python (TensorFlow/PyTorch)
**Responsibilities**:
- Real-time video processing from match feed
- Action recognition (techniques, penalties)
- Performance metrics (speed, efficiency)
- Automated commentary generation
- Store analysis results in match_metadata

**Integration**:
- Consumes: YouTube Live stream input
- Produces: Match analysis stored in Supabase
- Outputs to: YouTube/TikTok live feeds

#### c) Live Streaming Orchestrator
**Tech**: Node.js (FFmpeg wrapper)
**Responsibilities**:
- Ingest live camera feeds
- Apply AI analysis overlays
- Route to multiple platforms (YouTube, TikTok)
- Manage bitrate, resolution, frame rate
- Handle failover and stream recovery

**Platform APIs**:
- YouTube Live API for stream management
- TikTok RTMP ingestion
- Stream key rotation and security

**Monitoring**:
- Stream health metrics to Supabase logs
- Audience metrics to dashboard

### 6. External Services

**Google AI Studio** (Development Tool)
- **Purpose**: Rapid AI model development and testing
- **Use Case**: Develop match analysis models offline
- **NOT used**: In live production (models exported to microservice)
- **Workflow**:
  1. Collect sample match videos
  2. Train model in Google AI Studio
  3. Export model to PyTorch/TensorFlow
  4. Deploy to Match Analysis microservice

**YouTube & TikTok APIs**:
- Stream ingestion via RTMP
- Chat integration for live comments
- Analytics ingestion for audience metrics

---

## Data Flow Examples

### Example 1: Athlete Views Live Match
```
1. Client subscribes to match_actions via Supabase Realtime
2. Match official submits action via REST API:
   POST /match_actions { match_id, athlete_id, action_type }
3. Supabase trigger updates match.winner_id if match is complete
4. WebSocket broadcasts update to all subscribed clients
5. Client re-renders score, animation plays
```

### Example 2: Tournament Bracket Generation
```
1. Organizer clicks "Generate Bracket" in admin panel
2. Client calls microservice: POST /competitions/generate-bracket
3. Microservice fetches athletes from Supabase
4. Generates bracket using algorithm
5. Creates match records via Supabase API
6. Returns bracket to client
7. Client displays bracket, matches ready for officials
```

### Example 3: Live Analysis & Streaming
```
1. Camera feed → AI Analysis Service (Python)
2. Service processes frames, detects techniques
3. Stores analysis in match_metadata via Supabase
4. Sends enhanced frame to YouTube Live API
5. Client shows AI overlay on YouTube player
6. TikTok RTMP feed gets mirrored stream
7. Highlights auto-generated and posted to TikTok
```

---

## Deployment Architecture

### Development
- **Database**: Supabase (Free tier)
- **APIs**: Supabase PostgREST (included)
- **Microservices**: Local Docker containers
- **Frontend**: Next.js dev server (localhost:3000)

### Production
- **Database**: Supabase (Pro tier, $25/month)
  - 500GB storage
  - 50GB bandwidth
  - Backup to S3
- **Microservices**: Docker on AWS ECS or Google Cloud Run
  - Auto-scaling for bracket generation peaks
  - Reserved capacity for live events
- **Frontend**: Vercel (Next.js optimized)
  - Edge caching for static assets
  - CDN for global distribution
- **Monitoring**: 
  - Sentry for error tracking
  - LogRocket for user session replay
  - Supabase built-in monitoring

---

## Security Considerations

1. **RLS Policies**: Enforce at database level (cannot be bypassed)
2. **JWT Tokens**: Short-lived (15 min), refresh tokens (7 days)
3. **SSL/TLS**: All communications encrypted
4. **API Rate Limiting**: Supabase built-in per role
5. **Sensitive Data**:
   - Passwords hashed by Supabase Auth
   - API keys stored in environment variables
   - Stream keys rotated weekly
6. **Audit Logs**: 
   - `created_at`, `updated_at` on all tables
   - Match action history immutable
   - User permission changes logged

---

## Future Scalability

- **Sharding**: Partition athletes by event_id for 100K+ users
- **Caching**: Redis for leaderboards (cached rankings)
- **CDN**: CloudFront for match video archives
- **Mobile**: React Native client for offline bracket viewing
- **AI Expansion**: Athlete performance predictions, injury risk analysis
