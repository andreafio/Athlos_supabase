# 📚 Athlos Supabase - Documentation Index

> **Comprehensive documentation for migrating SportApp from Laravel/MySQL to Supabase + Microservices architecture**

## 🎯 Project Overview

**Athlos** is a SaaS platform for sports club management, competition organization, and real-time match tracking. The system is being migrated from Laravel/MySQL to a modern Supabase + Microservices architecture to support:

- **Multi-tenant SaaS model** with subscription management
- **3000+ athletes** across multiple sports clubs
- **4 major events/year** with 1000+ concurrent users
- **Real-time match updates** and live streaming capabilities
- **AI-powered match analysis** (future)
- **YouTube/TikTok streaming** integration (future)

---

## 📋 Core Documentation

### 1. 🏗️ [Architecture Overview](./ARCHITECTURE_OVERVIEW.md)
**System architecture and component breakdown**

- Supabase PostgREST API layer
- Supabase Realtime subscriptions
- Microservices architecture (20% complex logic)
- Frontend technologies (Next.js 14, React Native)
- Deployment strategy

**Read this first** to understand the overall system design.

---

### 2. 🔐 [Authentication & RLS Design](./AUTH_RLS_DESIGN.md)
**Security and access control strategy**

- Supabase Auth integration
- Row Level Security (RLS) policies
- User roles: System Admin, Club Admin, Coach, Athlete, Guardian, Referee
- Multi-tenant data isolation
- Guardian-minor access control

**Critical for SaaS security** and data protection.

---

### 3. 🧩 [Business Logic Analysis](./BUSINESS_LOGIC_ANALYSIS.md)
**Analysis of Laravel backend business logic**

- Controller and Service layer mapping
- Authentication flows
- Event management logic
- Match scoring and bracket generation
- Payment processing
- Notification system

**Essential for understanding** what logic stays in Supabase vs moves to microservices.

---

### 4. 🔄 [Database Mapping: MySQL → Supabase](./DB_MAPPING_MYSQL_TO_SUPABASE.md)
**Detailed table-by-table migration guide**

- Field type conversions (MySQL → PostgreSQL)
- Relationship mappings
- Data migration strategy
- Optimization recommendations

**Use this as your migration reference** when moving data.

---

### 5. 📊 [MySQL Schema Analysis](./MYSQL_SCHEMA_ANALYSIS.md)
**Complete analysis of the original 64 MySQL tables**

- Table purposes and relationships
- Redundancy identification
- Performance indexes
- Tables to migrate vs drop

**Background context** for understanding the legacy system.

---

### 6. 🚀 [Microservices Architecture](./MICROSERVICES_ARCHITECTURE.md)
**Microservices design for complex business logic**

- **80% Supabase** (CRUD, auth, real-time)
- **20% Microservices** (bracket generation, streaming orchestration)
- API Gateway strategy
- Service communication patterns
- Deployment (Vercel, Railway, Cloud Run)

**Guide for what logic** should NOT be in Supabase.

---

### 7. 🛡️ [CI/CD, Sicurezza e Deploy](./CI_CD_SECURITY.md)
**Pipeline, controlli di sicurezza e deploy**

- Gating lint/unit/e2e per PR, staging e production
- Test RLS e contract test
- Secret management (Doppler/1Password, Vercel env) e rotazione chiavi
- Migrazioni con rollback e controlli di sicurezza (audit, SAST)

**Linee guida operative** per release sicure.

---

### 8. 🛰️ [Observability & Monitoring](./OBSERVABILITY_MONITORING.md)
**Logging, metriche e monitoraggio per Supabase Edge Functions e microservizi**

- Formati di log JSON, trace/span correlation, livelli minimi
- Metriche chiave (latency, error rate, Realtime/streaming health) con SLO/SLA target
- Stack OTel + Grafana/Loki/Tempo, dashboard e alert di base

**Usa questo come guida** per implementare telemetria coerente e verificare gli SLO.

---

## 💾 Database Files

### 9. 🗄️ [Supabase Schema (SQL)](./SUPABASE_SCHEMA.sql)
**Complete PostgreSQL schema for Supabase**

- **25 tables** (optimized from 64 MySQL tables)
- **18 custom ENUM types**
- Foreign key relationships
- Performance indexes
- Consolidated match scoring (3 tables → 1)

**Ready to execute** in Supabase SQL Editor.

---

### 10. 🔒 [RLS Policies (SQL)](./RLS_POLICIES.sql)
**Row Level Security policies for all tables**

- Enable RLS on all 25 tables
- User-specific data access
- Multi-tenant isolation
- Guardian-minor relationships
- Team and event access control

**Apply after** creating the schema.

---

## 📈 Project Management

### 11. 📝 [Changelog](./CHANGELOG.md)
**Version history and progress tracking**

- Database schema completion
- RLS policies
- Documentation updates
- Migration milestones

**Track project evolution** and major decisions.

---

### 12. 🗓️ [Project Roadmap](./PROJECT_ROADMAP.md)
**Gantt chart, epics, and task breakdown**

- **Phase 1**: Foundation & SaaS Setup (Weeks 1-3)
- **Phase 2**: Core MVP Features (Weeks 4-6)
- **Phase 3**: Competition Engine (Weeks 7-9)
- **Phase 4**: Advanced Features (Weeks 10-12)
- Sprint planning and milestones

**Your execution guide** with timeline and dependencies.

---

## 🏢 SaaS Architecture

### Multi-Tenancy Model

**Athlos operates as a SaaS platform:**

#### 1. **System Administrators**
- Platform-wide access
- Client onboarding
- Subscription management
- System monitoring

#### 2. **Client Organizations (Sports Clubs)**
- Each club is a separate tenant
- Subscription plans: Free, Pro, Enterprise
- Data isolation via RLS policies
- Custom branding (future)

#### 3. **Subscription Tiers**

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Athletes | Up to 50 | Up to 500 | Unlimited |
| Events/Year | 2 | 12 | Unlimited |
| Courses | 5 | Unlimited | Unlimited |
| Live Streaming | ❌ | ✅ | ✅ |
| AI Analysis | ❌ | ❌ | ✅ |
| White-label | ❌ | ❌ | ✅ |
| Support | Community | Email | Priority |

#### 4. **Database Schema for SaaS**
```sql
-- Additional tables needed for SaaS:
CREATE TABLE public.organizations (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  subscription_tier TEXT, -- 'free', 'pro', 'enterprise'
  subscription_status TEXT, -- 'active', 'trial', 'cancelled'
  trial_ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.subscriptions (
  id UUID PRIMARY KEY,
  organization_id UUID REFERENCES organizations(id),
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  plan_id TEXT,
  status TEXT,
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ
);
```

---

## 🎯 Quick Start Guide

### For Developers

1. **Start with [Architecture Overview](./ARCHITECTURE_OVERVIEW.md)** - Understand the system
2. **Read [Auth & RLS Design](./AUTH_RLS_DESIGN.md)** - Learn security model
3. **Review [Supabase Schema](./SUPABASE_SCHEMA.sql)** - See database structure
4. **Check [Project Roadmap](./PROJECT_ROADMAP.md)** - Know what to build next

### For Database Migration

1. **Analyze [MySQL Schema Analysis](./MYSQL_SCHEMA_ANALYSIS.md)** - Understand source
2. **Use [Database Mapping Guide](./DB_MAPPING_MYSQL_TO_SUPABASE.md)** - Map tables
3. **Execute [Supabase Schema SQL](./SUPABASE_SCHEMA.sql)** - Create tables
4. **Apply [RLS Policies SQL](./RLS_POLICIES.sql)** - Secure data
5. **Migrate data** using generated scripts

### For Product/Business

1. **Review [Business Logic Analysis](./BUSINESS_LOGIC_ANALYSIS.md)** - See features
2. **Check [Project Roadmap](./PROJECT_ROADMAP.md)** - Understand timeline
3. **Read [Microservices Architecture](./MICROSERVICES_ARCHITECTURE.md)** - Know costs

---

## 🛠️ Tech Stack

### **Backend**
- **Supabase** (PostgreSQL + PostgREST + Realtime)
- **Microservices** (Node.js/Python)
- **Stripe** (Payment processing)
- **Vercel/Railway** (Deployment)

### **Frontend**
- **Next.js 14** (Web app)
- **React Native** (Mobile - future)
- **Tailwind CSS** (Styling)
- **Supabase JS Client** (API)

### **External Services**
- **Google AI Studio** (AI development)
- **YouTube/TikTok APIs** (Streaming - future)
- **Upstash Redis** (Caching/queues)

---

## 📊 Project Stats

- **Total Tables**: 25 (from 64 MySQL)
- **Documentation Files**: 10
- **Lines of SQL**: 596
- **Custom ENUMs**: 18
- **RLS Policies**: 50+
- **Estimated Timeline**: 12 weeks
- **Team Size**: 1-2 developers

---

## 🔗 External Resources

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Stripe API Reference](https://stripe.com/docs/api)

---

## 📞 Support

**Questions or need clarification?**

- Create an issue in this repository
- Review the [Changelog](./CHANGELOG.md) for recent updates
- Check [Project Roadmap](./PROJECT_ROADMAP.md) for current status

---

**Last Updated**: December 25, 2025  
**Version**: 1.0  
**Status**: ✅ Schema Complete | 🚧 Implementation Pending
