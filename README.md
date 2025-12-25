# Athlos Supabase Migration

**Sports Management Platform - Supabase Migration & Competition Engine Development**

MVP for judo/sports event management with live streaming and AI match analysis capabilities.

---

## 📋 Project Overview

Athlos is transitioning from a Laravel + MySQL backend to a modern, scalable architecture:
- **Data Layer**: Supabase (PostgreSQL + Auth + RLS)
- **API**: RESTful via Supabase RPC functions
- **Competition Engine**: Microservice for bracket generation, match management, and ranking calculation
- **Frontend**: Google AI Studio (development) + Next.js/SvelteKit (production)
- **Live**: Direct Postgres connections + Realtime for arbiters, polling for public

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Google AI Studio                         │
│         (Development Tool for Interface Generation)          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│              Frontend (Next.js / SvelteKit)                  │
│         Public: Live Results, Rankings, Calendar             │
│   Staff: Dashboard, Arbitrage, Registration Management       │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌────────▼──────────────────┐
│   Supabase (DB)   │  │  Competition Engine       │
│  - Auth + RLS     │  │  - Bracket Generation     │
│  - Tables/Views   │  │  - Match Management       │
│  - RPC Functions  │  │  - Standings Calculation  │
│  - Realtime       │  │  - AI Analysis Integration│
└─────────────────┘  └────────────────────────────┘
```

## 📁 Repository Structure

```
Athlos_supabase/
├── docs/
│   ├── README.md                               # This file
│   ├── ARCHITECTURE_OVERVIEW.md                # Detailed architecture & design decisions
│   ├── DB_MAPPING_MYSQL_TO_SUPABASE.md        # Table mapping & consolidation decisions
│   ├── API_REFERENCE.md                        # RPC functions & endpoints
│   ├── AUTH_RLS_DESIGN.md                      # Auth strategy & row-level security
│   └── CHANGELOG.md                            # Versioned changes (semver)
├── schema/
│   ├── mysql-schema.sql                        # Original MySQL schema (read-only)
│   ├── supabase-schema.sql                     # Target Postgres schema with enums & constraints
│   ├── rpc/                                    # RPC function definitions
│   │   ├── competitions.sql
│   │   ├── matches.sql
│   │   └── ...
│   └── seed/                                   # Test data (optional)
├── services/
│   ├── competition-engine/                     # Microservice for bracket/match logic
│   │   ├── package.json
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── brackets.ts
│   │   │   ├── standings.ts
│   │   │   └── ...
│   │   └── tests/
│   ├── live-orchestrator/                      # (Future) Streaming & AI integration
│   └── ...
├── tools/
│   ├── migrate-mysql-to-supabase.ts           # ETL script
│   ├── validate-migration.ts                   # Data validation post-migration
│   └── ...
└── .github/
    └── workflows/                              # CI/CD for schema, migrations, tests
```

## 🎯 Migration Phases

### Phase 1: Analysis & Planning ✅
- [x] Repo setup
- [ ] Database analysis: Identify redundancies, consolidations
- [ ] Create `DB_MAPPING_MYSQL_TO_SUPABASE.md`
- [ ] Architecture decisions: Auth, RLS, RPC design

### Phase 2: Schema & Infrastructure
- [ ] Define Supabase schema (with enums, constraints)
- [ ] Design RLS policies by role (athlete, organizer, ref, admin)
- [ ] Create RPC functions for core operations
- [ ] Set up local dev environment (Supabase CLI)

### Phase 3: Data Migration
- [ ] Build ETL script (MySQL → Supabase)
- [ ] Validate data integrity
- [ ] Test rollback procedures
- [ ] Dry-run on staging

### Phase 4: Competition Engine
- [ ] Initialize Node.js microservice
- [ ] Implement bracket generation logic
- [ ] Implement standings/ranking calculation
- [ ] API contract with Supabase

### Phase 5: Frontend & Integration
- [ ] Build core CRUD views (events, registrations)
- [ ] Live match arbitrage interface
- [ ] Public results board
- [ ] Google AI Studio tools (optional)

---

## 📊 Key Design Decisions

### Auth & Permissions
- **Source of Truth**: Supabase Auth (JWT)
- **Roles**: `athlete`, `club_admin`, `organizer`, `referee`, `admin`, `public`
- **Visibility**: RLS policies on all tables
- **Example**: Athletes see only their own data unless organizer shares event

### Database Consolidations
- **Match Actions**: Single `match_actions` table + `action_type` enum (ippon, waza_ari, shido, hansoku, etc.)
- **Payments**: Unified `payments` table (no polymorphism; use nullable fields for details)
- **Documents**: Generic `documents` table with `doc_type` enum + metadata JSON

### Microservices
- **Competition Engine**: Separated from Supabase for reusability & scalability
  - Exposes JSON API: `POST /engine/generate-brackets`, `POST /engine/compute-standings`
  - Reads/writes via Supabase (service key or pooled connection)
  - Testable, versionable, deployable independently

---

## 🚀 Getting Started (Local Dev)

### Prerequisites
- Node.js 18+ (for competition-engine, tools)
- PostgreSQL 14+ (via Supabase local or Docker)
- Supabase CLI (`npm i -g supabase`)

### Setup

```bash
# Clone repo
git clone https://github.com/andreafio/Athlos_supabase.git
cd Athlos_supabase

# Install Supabase CLI & start local instance
npm install -g supabase
supabase start

# Link to your project or use local instance
supabase link  # or skip for local-only dev

# Run migrations
supabase migration up

# (Future) Start competition-engine
cd services/competition-engine
npm install
npm run dev
```

---

## 📖 Documentation

See `/docs` for detailed guides:
- **[ARCHITECTURE_OVERVIEW.md](./docs/ARCHITECTURE_OVERVIEW.md)** — System design, trade-offs
- **[DB_MAPPING_MYSQL_TO_SUPABASE.md](./docs/DB_MAPPING_MYSQL_TO_SUPABASE.md)** — Table mapping, consolidations
- **[AUTH_RLS_DESIGN.md](./docs/AUTH_RLS_DESIGN.md)** — Auth strategy, policy examples
- **[TESTING_AND_CI.md](./docs/TESTING_AND_CI.md)** — Unified lint/format, test strategy, coverage, and load testing
- **[CHANGELOG.md](./docs/CHANGELOG.md)** — Versioned changes (semver)

---

## 🎮 GitHub Project

Track progress: [Athlos Supabase Migration](https://github.com/users/andreafio/projects/9)

BoardStatus:
- **Backlog**: Not started
- **Ready**: Waiting to be picked up
- **In Progress**: Actively being worked on
- **In Review**: PR submitted, waiting for review
- **Done**: Completed & merged

---

## 📝 Contributing

1. Create an issue or comment on existing task
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Document changes in `CHANGELOG.md` (semver bump)
4. Open a PR and request review
5. Merge once approved

---

## 📞 Contact & Status

- **Status**: 🟡 Planning Phase (Architecture, Analysis)
- **Estimated MVP**: Q2 2025
- **Tech Lead**: @andreafio

---

*Last Updated: 2025-12-25*
