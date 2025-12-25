# Microservices Architecture: Supabase + External Services

## Overview

This document defines the complete architecture split between **Supabase** (database + RLS + simple logic) and **Microservices** (complex algorithms + external integrations).

**Source Analysis**: Based on `athlos_backend` Laravel codebase analysis (Controllers + Services)
**Date**: 2025-12-25

---

## Architecture Principles

### Golden Rule: Supabase vs Microservices

```
Supabase (80%):
- CRUD operations
- Data relationships (SQL JOIN)
- Permission enforcement (RLS)
- Real-time subscriptions (WebSocket)
- Simple validations
- File storage

Microservices (20%):
- Complex algorithms (loops, nested logic)
- External API integrations
- Heavy processing (AI, video, bulk)
- Scheduled jobs (cron)
- Webhook receivers
```

### Decision Matrix

| Criteria | Supabase | Microservice |
|----------|----------|-------------|
| **Operation type** | SELECT, INSERT, UPDATE, DELETE | Complex computation |
| **Logic complexity** | Simple WHERE/JOIN | Loops, algorithms, recursion |
| **Data scope** | Single/few records | Bulk processing |
| **External calls** | None | API calls to Stripe, YouTube, etc. |
| **Performance** | <100ms query | >1s processing |
| **State** | Stateless (SQL) | Stateful (in-memory) |

---

## Component Classification

## 1. SUPABASE - Core Database Operations (80%)

### ✅ Athletes Management
**Source**: `AthleteController.php`, `Athlete.php`

**Supabase Handles**:
- CRUD athletes (INSERT, SELECT, UPDATE, DELETE)
- Guardian relationships (RLS policies)
- Athlete statistics queries (JOIN with matches)
- Profile updates
- Medical certificate expiry tracking

**RLS Policies**:
```sql
-- Athletes view own profile
-- Guardians view linked minors
-- Coaches view team athletes
-- Admins view all
```

### ✅ Events & Registrations
**Source**: `EventController.php`, `EventRegistrationController.php`

**Supabase Handles**:
- Event CRUD
- Registration management
- Check-in status updates
- Public event listing

### ✅ Memberships & Payments Tracking
**Source**: `MembershipController.php`, `MembershipPaymentController.php`

**Supabase Handles**:
- Membership CRUD
- Payment status tracking
- Subscription queries

**Note**: Payment processing (Stripe) remains in microservice (see below)

### ✅ Courses & Enrollments
**Source**: `CourseController.php`, `CoursePaymentController.php`

**Supabase Handles**:
- Course CRUD
- Enrollment management
- Schedule queries
- Attendance tracking

### ✅ Documents & Storage
**Source**: `DocumentController.php`

**Supabase Handles**:
- Document metadata (DB)
- File storage (Supabase Storage)
- Sharing permissions
- Version tracking

### ✅ Clubs & Teams
**Source**: `ClubController.php`, `TeamController.php`

**Supabase Handles**:
- Club/Team CRUD
- Member management
- Role assignments (via RLS)

### ✅ Notifications
**Source**: `NotificationController.php`

**Supabase Handles**:
- Notification CRUD
- Real-time delivery (Supabase Realtime)
- Read/unread status

---

## 2. MICROSERVICES - Complex Business Logic (20%)

### 🔴 CRITICAL: Bracket Generation Service

**Source**: `BracketGenerationService.php`, `TournamentRuleService.php`, `Brackets/`

**Why Microservice**:
- Complex algorithms (Swiss pairing, seeding, bye assignment)
- Recursive tree generation
- State management during generation
- Multiple bracket types (elimination, double-elimination, round-robin, pool)

**Algorithms Implemented** (from Laravel backend):
```php
// Swiss System Pairing
- Sort athletes by ranking/points
- Avoid rematches within N rounds
- Handle byes for odd numbers
- Swiss pairing logic (avoid same opponents)

// Single Elimination
- Power-of-2 bracket tree
- Seeding based on ranking
- Bye handling in first rounds

// Round Robin
- Generate all possible matches
- Fair rotation scheduling
```

**API Contract**:
```typescript
// Microservice Endpoint
POST /api/bracket/generate

Request:
{
  tournament_id: string,
  bracket_type: 'swiss' | 'single_elimination' | 'double_elimination' | 'round_robin',
  participants: Array<{
    athlete_id: string,
    ranking?: number,
    seed?: number
  }>,
  rules: {
    min_athletes: number,
    max_athletes?: number,
    rounds?: number // for Swiss
  }
}

Response:
{
  bracket_id: string,
  matches: Array<{
    match_number: number,
    round: number,
    athlete1_id: string | null, // null for bye
    athlete2_id: string | null,
    scheduled_time?: string
  }>
}
```

**Stack**: Node.js/TypeScript (Vercel Functions)
**Estimated Complexity**: ~500 LOC algorithm
**Performance**: 2-5s for 64 participants

---

### 🔴 CRITICAL: Match Assignment & Scheduling Service

**Source**: `MatAssignmentService.php`, `TatamiScheduler.php`

**Why Microservice**:
- Complex scheduling optimization
- Constraint solving (tatami availability, athlete rest time, judge assignment)
- Conflict resolution
- Multi-dimensional optimization

**Algorithm**:
```
1. Group matches by weight category
2. Calculate tatami capacity per hour
3. Assign matches avoiding:
   - Same athlete on multiple tatami
   - Insufficient rest time between matches
   - Judge conflicts
4. Optimize tatami utilization
5. Handle match delays and rescheduling
```

**API Contract**:
```typescript
POST /api/matches/assign-tatami

Request:
{
  event_id: string,
  matches: Array<{match_id: string, estimated_duration: number}>,
  tatami_count: number,
  start_time: string,
  constraints: {
    min_rest_minutes: number,
    max_matches_per_tatami_hour: number
  }
}

Response:
{
  schedule: Array<{
    match_id: string,
    tatami_number: number,
    scheduled_time: string,
    estimated_end: string
  }>,
  utilization: { tatami_1: 85%, tatami_2: 92%, ... }
}
```

**Stack**: Python (optimization libraries) or TypeScript
**Deployment**: Railway/Render (longer timeout needed)

---

### 🟡 MEDIUM: Payment Processing Service

**Source**: `EventPaymentController.php`, `CoursePaymentController.php`, `MembershipPaymentController.php`

**Why Microservice**:
- Stripe API integration
- Webhook handling (must receive POST from Stripe)
- Payment intent creation
- Refund processing

**Flow**:
```
1. Frontend → Microservice: Create payment intent
2. Microservice → Stripe: POST /payment_intents
3. Stripe → Frontend: Client secret
4. Frontend → Stripe: Confirm payment
5. Stripe → Microservice Webhook: payment_intent.succeeded
6. Microservice → Supabase: Update membership/registration status
```

**API Contract**:
```typescript
POST /api/payments/create-intent

Request:
{
  type: 'membership' | 'event_registration' | 'course',
  entity_id: string,
  amount: number,
  currency: 'eur',
  customer_id: string
}

Response:
{
  client_secret: string,
  payment_intent_id: string
}

// Webhook
POST /api/payments/webhook
// Stripe signature verification
// Update Supabase based on event type
```

**Stack**: Node.js/TypeScript (Vercel Functions)
**Special**: Needs public URL for webhook

---

### 🟢 LOW: Email Service

**Source**: `EmailTemplateService.php`, `NotificationService.php`

**Why Microservice** (optionally):
- Bulk email sending
- Template rendering
- Email queue management

**Alternative**: Could use Supabase Edge Functions + Resend API

**API Contract**:
```typescript
POST /api/emails/send-bulk

Request:
{
  template: 'event_reminder' | 'match_notification' | 'membership_expiry',
  recipients: Array<{email: string, data: object}>
}
```

**Stack**: Supabase Edge Function + Resend
**Cost**: Free tier 100 emails/day

---

### 🔴 FUTURE: Live Streaming Service

**Why Microservice**:
- YouTube Data API integration
- TikTok Live API integration
- Stream key management
- Multi-platform broadcasting

**Not in MVP** - Deferred to Phase 2

---

### 🔴 FUTURE: AI Match Analysis Service

**Source**: Mentioned in requirements (video analysis, technique recognition)

**Why Microservice**:
- Video processing (heavy CPU)
- TensorFlow/PyTorch models
- Frame-by-frame analysis
- Long-running tasks (minutes)

**Stack**: Python + TensorFlow
**Deployment**: Dedicated GPU server or AWS Lambda

**Not in MVP** - Deferred to Phase 3

---

## 3. EDGE FUNCTIONS vs MICROSERVICES

**Supabase Edge Functions** (Deno on Cloudflare Edge):
- ✅ Fast cold start (<50ms)
- ✅ Automatic auth context
- ✅ Direct DB access
- ❌ Limited to 10s timeout
- ❌ No heavy dependencies

**External Microservices** (Vercel/Railway/Render):
- ✅ Longer timeouts (60s+)
- ✅ Any language/framework
- ✅ Heavy dependencies OK
- ❌ Slower cold start
- ❌ Manual auth verification

### Decision Tree:

```
Bracket Generation → Vercel Functions (complex algorithm, <5s)
Matching Scheduling → Railway (optimization, 10-30s)
Payment Processing → Vercel Functions (webhook receiver)
Email Sending → Supabase Edge Function (simple, <2s)
```

---

## 4. DEPLOYMENT ARCHITECTURE

### MVP Stack (Phase 1)

```
┌──────────────────────────────────────────────────┐
│           FRONTEND (Vercel)                      │
│           Next.js / React                        │
└────────────┬─────────────────────────────────────┘
             │
             ├─────────────────┬─────────────────┐
             ▼                 ▼                 ▼
┌─────────────────────┐ ┌──────────────┐ ┌───────────────┐
│   SUPABASE (80%)    │ │  VERCEL      │ │  RAILWAY      │
│                     │ │  FUNCTIONS   │ │  (Optional)   │
├─────────────────────┤ ├──────────────┤ ├───────────────┤
│ • PostgreSQL DB     │ │ • Bracket    │ │ • Scheduling  │
│ • Auth (JWT)        │ │   Generation │ │   (if slow)   │
│ • RLS Policies      │ │ • Payments   │ └───────────────┘
│ • Storage (Files)   │ │   Webhook    │
│ • Realtime          │ └──────────────┘
│ • Edge Functions    │
│   (Email, simple)   │
└─────────────────────┘
```

### Service Endpoints

```yaml
Supabase:
  URL: https://your-project.supabase.co
  Auth: https://your-project.supabase.co/auth/v1
  REST API: https://your-project.supabase.co/rest/v1
  Realtime: wss://your-project.supabase.co/realtime/v1

Microservices:
  Brackets: https://athlos-brackets.vercel.app/api/
  Payments: https://athlos-payments.vercel.app/api/
  Scheduling: https://athlos-scheduling.railway.app/api/
```

### Environment Variables

**Frontend (.env)**:
```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_BRACKET_SERVICE_URL=
NEXT_PUBLIC_PAYMENT_SERVICE_URL=
```

**Microservices (.env)**:
```bash
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=  # Server-side only
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
```

---

## 5. AUTHENTICATION FLOW

### Frontend → Supabase (Direct)
```typescript
// All CRUD operations
const { data } = await supabase
  .from('athletes')
  .select('*')
// JWT automatically included in header
// RLS policies applied automatically
```

### Frontend → Microservice → Supabase
```typescript
// Complex operations
const response = await fetch(`${BRACKET_SERVICE_URL}/generate`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${supabase.auth.session().access_token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ tournament_id, participants })
});

// Microservice verifies JWT:
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  global: {
    headers: { Authorization: req.headers.authorization }
  }
});

// Microservice can now query Supabase as authenticated user
const { data: tournament } = await supabase
  .from('tournaments')
  .select('*')
  .eq('id', tournament_id)
  .single();
```

---

## 6. COST ESTIMATION

### MVP Monthly Costs

```yaml
Supabase Pro: $25/month
  - 8GB database
  - 100GB file storage
  - 250GB bandwidth
  - Connection pooling
  - Daily backups

Vercel Pro: $20/month
  - Unlimited functions
  - 100GB bandwidth
  - Custom domains

Railway (optional): $5-10/month
  - Only if scheduling service needed
  - Pay-as-you-go

Stripe: Transaction fees only
  - 1.4% + €0.25 per transaction (EU cards)

Resend (Email): Free
  - 100 emails/day free tier
  - Upgrade to $10/month for 50k emails

TOTAL MVP: €45-55/month + transaction fees
```

### Scale Estimates (3000 athletes, 4 events/year)

```
Database queries: ~50k/month (within free tier)
Bracket generations: ~20/month (4 events × 5 categories)
Payment webhooks: ~500/month (memberships + registrations)
Email sends: ~2000/month (notifications)

Concurrent peak (1000 users):
- Supabase connection pooling: handles 100-200 concurrent
- Need Supabase Pro for this
- Vercel Functions: auto-scale to 1000 concurrent
```

---

## 7. MIGRATION CHECKLIST

### Phase 1: Setup (Week 1)
- [ ] Create Supabase project
- [ ] Migrate database schema
- [ ] Set up RLS policies (basic)
- [ ] Deploy frontend to Vercel
- [ ] Configure environment variables

### Phase 2: Core Features (Week 2-3)
- [ ] Implement CRUD operations via Supabase
- [ ] Test RLS policies (guardian-minor, team access)
- [ ] Migrate file storage to Supabase Storage
- [ ] Implement real-time subscriptions

### Phase 3: Microservices (Week 4-5)
- [ ] Deploy bracket generation service
- [ ] Migrate bracket generation logic from Laravel
- [ ] Deploy payment webhook service
- [ ] Integrate Stripe webhooks
- [ ] Test end-to-end flows

### Phase 4: Testing (Week 6)
- [ ] Load test with 1000 concurrent users
- [ ] Test bracket generation with 64 participants
- [ ] Test payment flows
- [ ] Guardian-minor access control validation

---

## 8. SUMMARY

### Final Architecture Decision

| Component | Platform | Reason |
|-----------|----------|--------|
| **Database** | Supabase PostgreSQL | RLS, real-time, managed |
| **Auth** | Supabase Auth | JWT, built-in, RLS integration |
| **CRUD APIs** | Supabase Auto REST | No backend code needed |
| **File Storage** | Supabase Storage | Integrated, RLS-protected |
| **Bracket Generation** | Vercel Functions | Complex algorithm, <5s |
| **Payment Webhook** | Vercel Functions | Public URL, fast response |
| **Scheduling** | Railway (optional) | Long-running optimization |
| **Email** | Supabase Edge + Resend | Simple, fast |
| **Real-time** | Supabase Realtime | WebSocket auto-managed |

### Key Benefits

1. **❌ Eliminate 80% of Laravel backend** - No more Controllers, Middleware, Models for CRUD
2. **✅ Security by default** - RLS enforced at database level
3. **✅ Real-time out of the box** - WebSocket with zero config
4. **✅ Scalable** - Auto-scales to 1000+ concurrent users
5. **✅ Cost-effective** - €45-55/month for MVP vs €100+ for Laravel hosting
6. **✅ Developer experience** - Single codebase (TypeScript), no API layer needed

### What Stays Complex

- Bracket generation algorithms (Swiss, elimination logic)
- Match scheduling optimization
- Payment processing (Stripe integration)
- Future: Live streaming, AI analysis

---

**Document Status**: COMPLETE  
**Last Updated**: 2025-12-25  
**Next Steps**: Implement Phase 1 (Setup Supabase project)
