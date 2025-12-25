# Analisi delle Logiche di Business Già Sviluppate

## Scoperta Completata: athlos_backend Repository

**Data**: 25 Dicembre 2025  
**Fonte**: https://github.com/andreafio/athlos_backend  
**Stato documento ufficiale**: DOCUMENTO_FUNZIONALE_UNIFICATO.md (aggiornato 29 Settembre 2025)

---

## 1. PANORAMICA SISTEMA (SportApp)

SportApp è una piattaforma completa per gestione associazioni sportive dilettantistiche (ASD) con focus su judo e arti marziali. **Completamento globale**: Frontend ~75%, Backend ~98%.

### Obiettivi Principali Implementati:
✅ Gestione completa atleti e club sportivi  
✅ Organizzazione tornei con regole IJF 2025  
✅ Sistema pagamenti integrato (Stripe)  
✅ Documentazione medica e amministrativa  
✅ Sistema guardian per atleti minori  
✅ Notifiche e comunicazione real-time

---

## 2. STACK TECNOLOGICO

### Backend (Laravel/PHP) - **98% COMPLETO**
- **Framework**: Laravel
- **Database**: MySQL con Eloquent ORM
- **Authentication**: Laravel Sanctum (stateful)
- **Payments**: Stripe API
- **API**: RESTful JSON con versioning `/api/v1/`

### Frontend (React/TypeScript) - **75% COMPLETO**
- **Framework**: React 19.0.0 con TypeScript
- **Build**: Vite
- **Styling**: Tailwind CSS
- **Routing**: React Router v7
- **State**: React hooks + Context

---

## 3. MODULI FUNZIONALI PRINCIPALI

### ✅ MODULO 1: Autenticazione (100% ALLINEATO)
**Status**: COMPLETAMENTE ALLINEATO

**Endpoint Backend**:
- `POST /api/v1/auth/login-stateful` - Login
- `GET /api/v1/auth/me-stateful` - Get current user
- `POST /api/v1/auth/logout-stateful` - Logout
- `GET /api/v1/auth/csrf-token` - CSRF protection

**Features**:
- Session management con CSRF
- Multi-guard support (web, api)
- Onboarding step-by-step per nuovi utenti

---

### 👥 MODULO 2: Gestione Atleti (95% ALLINEATO)
**Status**: QUASI COMPLETO - Gap: dashboard statistiche avanzate

**Models/Controllers Disponibili**:
- `Athlete.php` - Modello atleta
- `AthleteCategory.php` - Categorie atleti
- `AthleteNote.php` + `AthleteNoteController.php` - Annotazioni
- `AthletePerformanceMetric.php` + Controller - Metriche performance
- `AthleteEventRegistration.php` - Registrazione a eventi
- `AthleteCourse.php` - Corsi per atleti
- `AthleteTransfer.php` - Trasferimenti tra club
- `AthleteInvitation.php` - Sistema inviti

**API Endpoints**:
```
GET    /api/v1/athletes
GET    /api/v1/athletes/{id}
POST   /api/v1/athletes
PUT    /api/v1/athletes/{id}
DELETE /api/v1/athletes/{id}
GET    /api/v1/athletes/{id}/statistics
GET    /api/v1/athletes/{id}/matches
```

**Funzionalità**:
- CRUD completo atleti
- Statistiche e storia match
- Documenti medici integrati
- Relazioni: matches, tournaments, guardians
- Integrazione guardian per minori

---

### 🏆 MODULO 3: Sistema Tornei (80% ALLINEATO)
**Status**: MODERATO - Gap: scheduling real-time, bracket editing avanzato

**Models/Controllers Disponibili**:
- `Tournament.php` - Tornei
- `Bracket.php` + `BracketModel` - Bracket management
- `Match.php` - Match singoli
- `BaseMatch.php` - Base match class
- `TournamentRule.php` + `TournamentRuleController.php` - Regole tornei
- `Category.php` + `CategoryBlock.php` - Categorie e blocchi

**API Endpoints**:
```
GET    /api/v1/tournaments
GET    /api/v1/tournaments/{id}
POST   /api/v1/tournaments
PUT    /api/v1/tournaments/{id}
GET    /api/v1/tournaments/{id}/bracket
GET    /api/v1/tournaments/{id}/matches
POST   /api/v1/tournaments/{id}/generate-bracket
```

**Funzionalità**:
- Creazione tornei con regole IJF 2025
- Generazione automatica bracket (Swiss, elimination, round-robin)
- Scoring system completo
- Assegnazione tatami
- 40+ tornei di test generati

---

### 🏢 MODULO 4: Gestione Club/Team (100% ALLINEATO)
**Status**: COMPLETAMENTE ALLINEATO

**Models/Controllers Disponibili**:
- `Club.php` - Club management
- `Team.php` / `TeamModel` - Team management
- `Role` / `Permission` - Spatie permission system

**API Endpoints**:
```
GET    /api/v1/clubs
GET    /api/v1/clubs/{id}
POST   /api/v1/clubs
PUT    /api/v1/clubs/{id}
GET    /api/v1/clubs/{id}/athletes
GET    /api/v1/clubs/{id}/members
POST   /api/v1/clubs/{id}/members
```

**Funzionalità**:
- CRUD club completo
- Gestione membri con ruoli (owner, admin, coach, athlete)
- Permission system Spatie integrato
- Corsi integrati con pagamenti

---

### 👨‍👩‍👧‍👦 MODULO 5: Sistema Guardian (90% ALLINEATO)
**Status**: QUASI COMPLETO - Gap: Dashboard tutore, notifiche

**Models/Controllers Disponibili**:
- `Guardian.php` / `GuardianModel` - Modello tutore
- Relazione many-to-many con Athlete
- 82,566 guardian generati per minori

**Features Critiche**:
- Compliance legale per minori
- Accesso controllato ai dati del minore
- Dati realistici italiani
- Gestione medical decisions

**RLS Policies da Implementare in Supabase**:
```sql
-- Guardians view their assigned minors
CREATE POLICY "guardians_view_minors" ON athletes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM athlete_guardian_mapping
      WHERE guardian_id = (SELECT id FROM guardians WHERE user_id = auth.uid())
      AND athlete_id = athletes.id
    )
  );

-- Minors view own data
CREATE POLICY "minors_view_own" ON athletes
  FOR SELECT
  USING (auth.uid() = user_id);
```

---

### 💳 MODULO 6: Sistema Pagamenti (85% ALLINEATO)
**Status**: MODERATO - Gap: payment history, refund management, invoice

**Models/Controllers Disponibili**:
- `Stripe` integration completa
- `EventPaymentController.php` - Pagamenti evento
- `CoursePaymentController.php` - Pagamenti corsi
- `MembershipPaymentController.php` - Pagamenti membership
- Payment intent management
- Webhook handling parziale

**API Endpoints**:
```
POST   /api/v1/stripe/create-payment-intent
POST   /api/v1/stripe/confirm-payment
GET    /api/v1/payments
GET    /api/v1/payments/{id}
GET    /api/v1/payments/refunds
```

**Funzionalità Implementate**:
- Pagamenti Stripe integrati
- Payment intents e confirmations
- Quote iscrizione evento
- Quote gare
- Gestione corsi con pagamenti
- Webhook handling (parziale)

**Da Implementare**:
- Payment history dashboard
- Refund management
- Invoice generation
- Subscription management

---

### 📚 MODULO 7: Gestione Corsi (95% ALLINEATO)
**Status**: QUASI COMPLETO

**Models/Controllers Disponibili**:
- `Course.php` - Modello corso
- `CourseLessonSchedule.php` - Schedule lezioni
- `CoursePaymentController.php` - Pagamenti

**API Endpoints**:
```
GET    /api/v1/clubs/{id}/courses
GET    /api/v1/courses/{id}
POST   /api/v1/courses
PUT    /api/v1/courses/{id}
GET    /api/v1/courses/{id}/schedule
POST   /api/v1/courses/{id}/enroll
```

**Funzionalità**:
- Creazione corsi
- Iscrizioni con pagamenti
- Calendario lezioni
- Enrollment management
- Ricorrenza (una tantum, settimanale, mensile)

---

### 📄 MODULO 8: Gestione Documenti (95% ALLINEATO)
**Status**: QUASI COMPLETO

**Models/Controllers Disponibili**:
- `DocumentController.php` - Gestione documenti
- `Document.php` - Modello documento

**Funzionalità**:
- Upload documenti
- Versioning
- Sharing e approval workflow
- Bulk upload
- File storage locale

---

### 🏥 MODULO 9: Certificati Medici (0% ALLINEATO)
**Status**: ❌ CRITICO - NON IMPLEMENTATO

**Cosa Manca**:
- Upload certificati medici
- Tracking scadenza
- Alert automatici
- Sistema di validazione
- Compliance GDPR

**Priorità**: ALTA - Funzionalità legale essenziale

---

### 🔔 MODULO 10: Notifiche Real-time (70% ALLINEATO)
**Status**: PARZIALE - Gap: WebSocket, push notifications

**Models/Controllers Disponibili**:
- `NotificationCenter` - Base notification system
- `NotificationList` - Listino notifiche
- API: unread count, mark as read

**Da Implementare**:
- WebSocket integration
- Push notifications
- Broadcasting
- Real-time match updates

---

## 4. STRUTTURA DATABASE

### Modelli Identificati (parziale list):
```
Athletes
Clubs / Teams  
Guardians (82,566 generati)
Tournaments
Matches / BaseMatch
Brackets
Courses / CourseLessonSchedule
Categories
Payments (Stripe)
Documents
Notifications
AthleteTransfers
AthleteInvitations
AthletePerformanceMetrics
AuditLog
+ Molti altri modelli supporto
```

---

## 5. ROADMAP MIGRAZIONI SUPABASE

### FASE 1: Setup Database (Week 1)
- [ ] Esportare schema MySQL completo
- [ ] Analizzare ogni tabella vs Modello Laravel
- [ ] Identificare relazioni e constraints
- [ ] Creare schema PostgreSQL equivalente

### FASE 2: Core Entities (Week 2-3)
- [ ] Athletes + relationships
- [ ] Clubs/Teams
- [ ] Guardians + RLS policies
- [ ] Tournaments + Brackets
- [ ] Courses

### FASE 3: Payments & Docs (Week 4)
- [ ] Payment system
- [ ] Documents
- [ ] Medical certificates (NEW)

### FASE 4: RLS Policies (Week 5-6)
- [ ] Auth policies
- [ ] Guardian-athlete policies
- [ ] Team member policies
- [ ] Organizer policies

### FASE 5: API Refactoring (Week 7-8)
- [ ] Aggiornare endpoint a Supabase client
- [ ] Testare con live database
- [ ] Migrare business logic a RPC functions

---

## 6. CONTROLLI CRITICI DA VERIFICARE

### Sul Backend Attuale:
- [ ] Database dump completo MySQL
- [ ] API documentation completa
- [ ] Business logic nei controllers
- [ ] Migrations Laravel per schema
- [ ] Query N+1 problems
- [ ] Permission checks implementation

### Per Supabase MVP:
- [ ] Identificare logica che esce da DB (va in microservices)
- [ ] Definire RPC functions necessarie
- [ ] Pianificare storage files (Supabase Storage vs S3)
- [ ] Setup WebSocket per real-time

---

## 7. PROSSIMI STEP IMMEDIATI

1. **Ottieni dump MySQL** da `sportapp-backend`
2. **Analizza schema dettagliato** 
3. **Crea mapping Django →  Supabase**
4. **Documenta business rules** per ogni modulo
5. **Definisci MVP scope**: quale subset entra in Phase 1?
6. **Setup locale database** per testing migration
