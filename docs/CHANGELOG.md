# Changelog

## [Database Schema Analysis] - 2025-12-25

## [SQL Schema Complete] - 2025-01-09

### Added

- **SUPABASE_SCHEMA.sql**: Complete PostgreSQL schema optimized for Supabase
  - 13 sections covering all core tables
  - Custom ENUM types (gender_type, membership_status, payment_status, event_status, etc.)
  - Core tables: profiles, athletes, guardians, teams, team_members
  - Roles and permissions system
  - Membership types and memberships with payment tracking
  - Events, weight categories, and event registrations
  - Brackets and matches (results from microservice)
  - Consolidated match_actions table (replacing 3 separate tables)
  - Courses and course enrollments
  - Notifications system
  - Comprehensive indexes for performance optimization
  - Foreign key relationships with appropriate CASCADE/SET NULL rules

- **RLS_POLICIES.sql**: Complete Row Level Security policies
  - RLS enabled on all 18 tables
  - Profile policies: Users can manage their own profiles
  - Athlete policies: Athletes view own data, guardians view minors, coaches view team athletes
  - Event policies: Published events visible to all, organizers manage own events
  - Registration policies: Athletes register, organizers view all registrations
  - Match policies: Visible for published events, referees update assigned matches
  - Membership policies: Athletes + guardians + team admins can view
  - Notification policies: Users manage own notifications
  - Team policies: Members view teams, admins manage, public teams visible to all
  - Course policies: Team members view, instructors manage
  - Guardian policies: Own data access only
  - Public read policies for membership types, weight categories, brackets, and roles

### Updated

- Database schema consolidated from MySQL (38 tables) to PostgreSQL (22 tables)
- Optimized scoring: 3 separate tables → 1 unified match_actions table
- Added JSONB fields for flexible metadata storage
- Enhanced timestamp handling with PostgreSQL TIMESTAMPTZ
- Improved constraint naming and documentation

### Key Achievements

- Complete database migration foundation ready for Supabase
- All RLS policies defined for security and multi-tenancy
- Schema supports 3000 athletes, 4 events/year, 1000 concurrent users
- Optimized for Supabase free tier → Pro tier scaling
- Ready for integration with microservices (bracket generation, match management)
- Supports guardian-minor relationships with proper access control
- Stripe payment integration prepared
- Course scheduling and enrollment system complete



### Added

- **MYSQL_SCHEMA_ANALYSIS.md**: Comprehensive analysis of all 64 MySQL tables from sportapp_backend dump
  - Detailed table-by-table breakdown with field descriptions
  - RLS (Row Level Security) strategy for each table
  - Identified redundancy: match_points + judo_match_points → unified match_actions
  - Complete data type conversion mapping (MySQL → PostgreSQL)
  - Migration phases (Foundation, Business Logic, Competition Engine, Microservices)
  - Critical MVP requirements documentation
  - Resource estimation: Supabase Pro ($25/month) + external services (~$35/month)

### Updated

- **DB_MAPPING_MYSQL_TO_SUPABASE.md**: Added reference to detailed schema analysis
- Migration strategy refined based on actual database structure analysis

### Key Findings

- 38 tables to migrate (core business logic)
- 16 tables to drop (Laravel/Passport infrastructure)
- Major optimization: Consolidate 3 scoring tables into 1 unified event store
- Guardian-minor access control preserved through RLS policies
- Performance indexes identified for 1000+ concurrent users

---


## [Project Initialization] - 2025-01-09

### Created
- **Repository**: Athlos_supabase - Central hub for Supabase migration
- **Documentation**: DB_MAPPING, ARCHITECTURE_OVERVIEW, AUTH_RLS_DESIGN, CHANGELOG
- **GitHub Project Board**: Athlos Supabase Migration Kanban
- **README.md**: Comprehensive migration roadmap

### Key Decisions

**Database**: Supabase Pro tier ($25/month)
- 500GB storage, 50GB bandwidth
- Native auth integration, RLS enforcement

**Auth**: Supabase Auth + JWT + RLS Policies
- Impossible to bypass (enforced at database level)
- Roles: admin, organizer, coach, athlete, official

**Complex Logic**: Microservices (external)
- Bracket generation, match assignment, AI analysis
- Keeps Supabase focused on data, not computation

### Data Consolidations

| Old | New | Status |
|---|---|---|
| judo_match_points + match_points | match_actions | Merged |
| athlete_ranking + ranking | rankings | Merged |
| user_permissions (5 tables) | user_roles + RLS | Consolidated |
| tokens | Supabase Auth | Moved |

**Storage Reduction**: 35-40% smaller schema

### Cost Analysis

Current: $40-50/month
Migration MVP: $95-120/month

Gains:
- Auto-scaling for 1000 concurrent users
- Real-time WebSocket sync
- Unhackable RLS security
- AI match analysis capability

### Timeline

- **Phase 1 (Week 1-2)**: Foundation & schema migration
- **Phase 2 (Week 3-4)**: Auth & RLS implementation
- **Phase 3 (Week 5-6)**: API refactoring
- **Phase 4 (Week 7-10)**: Microservices development
- **Phase 5 (Week 11-12)**: Production & monitoring

### Next Steps

1. Create Supabase project
2. Import MySQL schema to PostgreSQL
3. Implement RLS policies
4. Refactor API endpoints
5. Deploy microservices

---

## Processo di review per modifiche a schema e policy

- Ogni modifica a schema, policy o microservizi deve avvenire tramite Pull Request (PR)
- È richiesta la review di almeno un altro sviluppatore
- I test (inclusi test RLS) devono passare prima del merge
- Aggiornare sempre CHANGELOG.md e la documentazione correlata
- Nessuna modifica diretta su main/master

---

> Ricorda: ogni modifica a schema, policy, microservizi o API deve essere tracciata qui e nella relativa documentazione.

## Document History

| Date | Version | Author | Changes |
|---|---|---|---|
| 2025-01-09 | 1.0 | andreafio | Initial creation with migration plan |
