# Authentication & RLS Design

## Overview

This document defines the migration from Laravel's permission system to Supabase's Row-Level Security (RLS) with native authentication. RLS is the primary security mechanism—it operates at the database level and cannot be bypassed via API.

## Migration Strategy: Laravel Permissions → Supabase RLS

### Current State (Laravel/MySQL)
- User roles stored in `user_roles` table (admin, organizer, coach, athlete, official)
- Permissions in `user_permissions` table (can_edit_event, can_view_athletes, etc.)
- Token-based auth with custom middleware
- Checks happen in application code (app/Http/Middleware)
- **Problem**: Permissions can be bypassed if API logic has bugs

### Target State (Supabase)
- User roles in `public.user_roles` table (referenced by `auth.users`)
- **RLS Policies** enforce permissions at database level
- JWT tokens from Supabase Auth (iss: https://[project].supabase.co)
- Permissions checked by PostgreSQL engine before data is returned
- **Benefit**: Impossible to bypass—database enforces rules

---

## Role Hierarchy

```
ADMIN (Superuser)
├─ View/Edit all events, athletes, matches
├─ Manage user roles and permissions
├─ Access analytics dashboard
└─ System configuration

ORGANIZER (Event Manager)
├─ Create/manage own events
├─ Register athletes to events
├─ Manage tournament bracket
├─ Appoint match officials
├─ View event analytics
└─ Cannot view other organizers' data

COACH (Athlete Manager)
├─ View/update own athletes' profiles
├─ View athletes' match history
├─ Submit feedback/notes on athletes
└─ Cannot create athletes

ATHLETE (Competitor)
├─ View own profile
├─ View registered events
├─ View match schedule
├─ View public rankings
└─ Cannot edit own profile (locked after registration)

OFFICIAL (Match Referee)
├─ View assigned matches
├─ Submit match actions (scores, penalties)
├─ Cannot view other officials' data
└─ Can only submit for assigned matches
```

---

## Role-Specific User Flows & UI Mapping

| Ruolo | Flusso chiave | Permesso/RLS richiesto | UI/Comportamento |
| --- | --- | --- | --- |
| Organizer | Crea/aggiorna evento, carica regolamento, pubblica bracket | `events_create`, `events_update_own`, `match_actions_view` (solo lettura) | Dashboard eventi con wizard di setup; CTA "Pubblica" abilitato solo se stato = `draft` e l'utente è organizer/`is_admin()`; pulsante "Aggiungi official" visibile se `events.organizer_id = auth.uid()`. |
| Coach | Consulta schede atleta, invia note tecniche, registra disponibilità a eventi | `coaches_view_assigned`, `coach_notes_insert`, `event_registrations_insert` (per atleti assegnati) | Lista atleti assegnati filtrata via `coach_athlete_assignments`; form note abilitato solo se mapping coach-atleta esiste; pulsante "Iscrivi a evento" mostra error state se RLS blocca l'inserimento. |
| Athlete | Visualizza profilo e iscrizioni, scarica pass gara, riceve notifiche match | `athletes_view_own`, `event_registrations_view`, `matches_view_registered` | Home atleta con blocco "Le mie competizioni" alimentato da query filtrate; bottoni di editing disabilitati dopo `is_registered=true`; banner sul match successivo con aggiornamenti realtime. |
| Official | Consulta match assegnati, invia punteggi/penalità, chiude incontro | `match_actions_insert`, `matches_view_registered` (per match assegnati) | "Sala ufficiali" mostra solo match da `match_officials`; il form di scoring attiva controlli client-side (campo match_id obbligatorio) e fallback offline in sola lettura; il pulsante "Chiudi match" compare solo se l'utente è official per quel match. |

### Pattern UI
- **CTA condizionati da RLS**: mostra CTA solo se i dati di contesto (organizer_id, mapping coach/athlete, assignment ufficiale) sono già disponibili lato client; evita di affidarti all'errore server per nascondere elementi.
- **Modalità read-only**: per ruoli che non possono modificare (es. atleta), mantieni la stessa UI con controlli disabilitati + tooltip "permessi insufficienti".
- **Feature flags per admin**: `is_admin()` può forzare percorsi di debug (es. vedere dati cross-tenant) ma l'UI deve esplicitare lo scope "Admin override" per evitare confusione.

---

## Gestione Errori RLS nel Frontend

1. **Messaggistica utente**
   - 401/403 dal client Supabase → messaggio umano: "Non hai i permessi per questa azione" + hint contestuale (es. "Chiedi all'organizer di aggiungerti come official").
   - 404 con `data: null` dopo query filtrata da RLS → mostra stato vuoto "Nessun elemento visibile con i tuoi permessi" invece di errore generico.

2. **Retry controllato**
   - Ripeti una sola volta dopo refresh token (`supabase.auth.refreshSession()`) se l'errore è `jwt expired`.
   - Non fare retry su 403 (permesso mancante); proponi azione alternativa (es. link a richiesta ruolo).

3. **Fallback offline/cache**
   - Usa cache locale (React Query/SWR) in modalità **stale-while-revalidate**: se RLS blocca una query che prima era consentita, mantieni l'ultima versione in sola lettura e mostra badge "Dati da cache".
   - Per azioni bloccate da RLS, evita di mettere in coda job offline: salva un log locale con motivazione e chiedi riconferma prima di riprovare quando torna online.

4. **Telemetria**
   - Logga `user_id`, `role`, `table`, `policy` (se disponibile in errore) in Sentry per individuare configurazioni RLS mancanti.
   - Throttling: massimo 5 eventi di errore RLS per sessione per evitare rumore.

---

## Realtime Client Patterns

### Subscribe / Unsubscribe
- Crea un **channel per feature** (`matches:<event_id>`, `actions:<match_id>`) e riusa lo stesso channel per più listener per ridurre socket aperti.
- Disiscrivi nel `useEffect` cleanup o onUnmount: `supabase.channel(id).unsubscribe()` per evitare leak.
- Per views con filtri dinamici (es. cambio match), esegui `channel.unsubscribe()` prima di creare la nuova sottoscrizione.

### Politica di riconnessione
- Usa backoff esponenziale con jitter (1s → 2s → 4s, max 30s) e resetta il backoff dopo 30s di stabilità.
- Se la sessione è scaduta, attendi il refresh JWT prima di riaprire i channel; in caso di fallimento mostra banner "Connessione in pausa, riprova login".
- Dopo 3 fallimenti consecutivi, entra in modalità **read-only** mostrando i dati da cache e un pulsante "Riprova" manuale.

### Rate limit lato client
- Max **5 channel attivi per tab** (match list, match detail, scoreboard, notifications, chat). Se serve un nuovo channel, chiudi il meno recente.
- Debounce degli handler: non processare più di 10 payload/secondo per match (queue con `requestAnimationFrame` o throttle 100ms) per evitare jank UI.
- Aggrega update non critici (es. aggiornamenti di ranking) usando polling leggero (15-30s) invece della sottoscrizione se l'utente non è nella vista attiva.

---

## RLS Policy Examples

### 1. Athletes Table

**Policy: athletes_view_own**
- Everyone can view their own profile
- Public profiles (is_public=true) are visible to all

```sql
CREATE POLICY "athletes_view_own" ON athletes
  FOR SELECT
  USING (
    auth.uid() = user_id
    OR is_public = true
    OR is_admin(auth.uid())
  );
```

**Policy: coaches_view_assigned**
- Coaches can view only their assigned athletes

```sql
CREATE POLICY "coaches_view_assigned" ON athletes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM coach_athlete_assignments
      WHERE coach_user_id = auth.uid()
      AND athlete_id = athletes.id
    )
    OR is_admin(auth.uid())
  );
```

**Policy: athletes_update_own** (blocked after registration)
```sql
CREATE POLICY "athletes_update_own" ON athletes
  FOR UPDATE
  WITH CHECK (
    auth.uid() = user_id
    AND is_registered = false
    AND is_admin(auth.uid())
  );
```

### 2. Events Table

**Policy: events_view_all**
- Public events visible to all authenticated users
- Draft events only visible to creator/admin

```sql
CREATE POLICY "events_view_all" ON events
  FOR SELECT
  USING (
    is_published = true
    OR organizer_id = auth.uid()
    OR is_admin(auth.uid())
  );
```

**Policy: events_create**
- Only organizers and admins can create events

```sql
CREATE POLICY "events_create" ON events
  FOR INSERT
  WITH CHECK (
    has_role(auth.uid(), 'organizer')
    OR is_admin(auth.uid())
  );
```

### 3. Matches Table

**Policy: matches_view_registered**
- View matches only if athlete/coach/official is registered for the event

```sql
CREATE POLICY "matches_view_registered" ON matches
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM event_registrations
      WHERE user_id = auth.uid()
      AND event_id = matches.event_id
    )
    OR is_admin(auth.uid())
    OR (
      EXISTS (
        SELECT 1 FROM match_officials
        WHERE user_id = auth.uid()
        AND match_id = matches.id
      )
    )
  );
```

### 4. Match Actions Table (Scores/Penalties)

**Policy: match_actions_insert** (RLS for writes)
- Only match officials can submit actions for their assigned matches

```sql
CREATE POLICY "match_actions_insert" ON match_actions
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM match_officials
      WHERE user_id = auth.uid()
      AND match_id = match_actions.match_id
    )
    OR is_admin(auth.uid())
  );
```

**Policy: match_actions_view**
- Match participants and officials can view all actions for their match

```sql
CREATE POLICY "match_actions_view" ON match_actions
  FOR SELECT
  USING (
    (
      SELECT athlete_1_id = auth.uid()
      OR athlete_2_id = auth.uid()
      FROM matches
      WHERE id = match_actions.match_id
    )
    OR EXISTS (
      SELECT 1 FROM match_officials
      WHERE user_id = auth.uid()
      AND match_id = match_actions.match_id
    )
    OR is_admin(auth.uid())
  );
```

### 5. Rankings Table (Public)

**Policy: rankings_view_all** (No RLS needed)
- Rankings are fully public (no secrets)

```sql
ALTER TABLE rankings DISABLE ROW LEVEL SECURITY;
```

Or if you want RLS:
```sql
CREATE POLICY "rankings_view_all" ON rankings
  FOR SELECT
  USING (true);
```

---

## Helper Functions

### is_admin()
```sql
CREATE OR REPLACE FUNCTION is_admin(user_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = $1
    AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

### has_role()
```sql
CREATE OR REPLACE FUNCTION has_role(user_id uuid, role_name text)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = $1
    AND role = role_name
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

### get_user_role()
```sql
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS text AS $$
  SELECT role FROM user_roles
  WHERE user_id = auth.uid()
  LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;
```

---

## User Roles Table Structure

```sql
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('admin', 'organizer', 'coach', 'athlete', 'official')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, role)
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role);
```

---

## Data Migration: Laravel → Supabase

### Step 1: Export Laravel Data
```sql
-- From Laravel MySQL
SELECT user_id, role FROM user_roles;
```

### Step 2: Transform & Import to Supabase
```sql
-- Insert into Supabase (PostgreSQL)
INSERT INTO public.user_roles (user_id, role, created_at)
SELECT 
  users.id,
  CASE 
    WHEN old_roles.role = 'super_admin' THEN 'admin'
    WHEN old_roles.role = 'event_organizer' THEN 'organizer'
    ELSE old_roles.role
  END,
  NOW()
FROM old_user_roles
JOIN auth.users ON old_user_roles.user_id = auth.users.id
ON CONFLICT (user_id, role) DO NOTHING;
```

### Step 3: Verify Migration
```sql
SELECT role, COUNT(*) FROM user_roles GROUP BY role;
```

---

## Testing RLS Policies

### Test as Coach (can only view assigned athletes)
```sql
SET ROLE coach_test;
SET jwt.claims.sub = 'coach-uuid-here';

SELECT * FROM athletes; -- Should return only assigned athletes
```

### Test as Admin (can view all)
```sql
SET ROLE admin_test;
SET jwt.claims.sub = 'admin-uuid-here';

SELECT * FROM athletes; -- Returns all athletes
```

### Test as Athlete (can only view own profile)
```sql
SET ROLE authenticated;
SET jwt.claims.sub = 'athlete-uuid-here';

SELECT * FROM athletes; -- Returns only own profile
SELECT * FROM athletes WHERE id != auth.uid(); -- Returns error/empty
```

---

## Test automatici RLS

- Utilizzare framework come pgTAP o script SQL per testare le policy.
- Esempio di test automatico:
  ```sql
  -- Test: un coach vede solo i propri atleti
  SET jwt.claims.sub = 'coach-uuid';
  SELECT * FROM athletes; -- Deve restituire solo gli atleti assegnati
  -- Test: un admin vede tutto
  SET jwt.claims.sub = 'admin-uuid';
  SELECT count(*) FROM athletes; -- Deve restituire tutti gli atleti
  ```
- Versionare i test insieme alle policy in una cartella `/tests/rls/`.
- Automatizzare i test in CI/CD dove possibile.

---

## JWT Token Structure

Supabase JWT contains:
```json
{
  "aud": "authenticated",
  "exp": 1234567890,
  "iat": 1234567890,
  "iss": "https://[project].supabase.co",
  "sub": "[user-uuid]",
  "email": "user@example.com",
  "email_verified": true,
  "phone_verified": false,
  "app_metadata": {
    "provider": "email",
    "providers": ["email"]
  },
  "user_metadata": {
    "name": "John Doe"
  }
}
```

**auth.uid()** in RLS policies extracts the `sub` claim.

---

## Client-Side Implementation

### JavaScript (Next.js)
```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(url, key);

// Login
await supabase.auth.signInWithPassword({ email, password });

// JWT automatically included in all subsequent requests
const { data: athletes } = await supabase
  .from('athletes')
  .select('*');
// RLS policies automatically filter based on JWT sub claim
```

---

## Common Pitfalls

1. **Forgetting ALTER TABLE ... ENABLE ROW LEVEL SECURITY**
   - Table must have RLS enabled for policies to take effect
   - Default: All data denied if any policy exists and RLS is enabled

2. **using() vs WITH CHECK()**
   - `USING`: Controls SELECT/UPDATE visibility
   - `WITH CHECK`: Controls INSERT/UPDATE data validation
   - Use both for full coverage

3. **Performance Issues**
   - RLS policies add joins—create indexes on foreign keys
   - Example: `CREATE INDEX idx_match_officials_user_id ON match_officials(user_id);`

4. **Testing with Wrong Credentials**
   - Always test with real JWT tokens from Supabase Auth
   - Anon keys bypass some checks—use authenticated tokens

---

## Rollout Plan

### Phase 1: Setup (Week 1)
- Create user_roles table
- Migrate Laravel permission data
- Create RLS helper functions

### Phase 2: Policies (Week 2)
- Deploy athletes table policies
- Deploy events/matches policies
- Test with staging data

### Phase 3: Enforcement (Week 3)
- Enable RLS on production tables
- Monitor error logs
- Gradual rollout to users

### Phase 4: Cleanup (Week 4)
- Disable old Laravel permission middleware
- Deactivate legacy API tokens
- Document for team
