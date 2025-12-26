# Prompt per agente Frontend Athlos Supabase

## Obiettivo
Sviluppare il frontend per la gestione eventi sportivi (Judo) integrato con Supabase (PostgreSQL, Auth, RLS, Realtime). Il frontend deve rispettare le architetture e i flussi dati descritti nei documenti del progetto.

---

## Requisiti principali

- **Stack:** Next.js (admin/pubblico), React Native (mobile futuro), Supabase JS SDK per auth, query, subscriptions.
- **Accesso dati:** Tutto tramite Supabase (mai diretto al DB). Usa solo API REST, Realtime e Auth di Supabase.
- **RLS:** Rispetta le policy RLS definite in Supabase. Testa sempre con JWT reali. Consulta i file `docs/AUTH_RLS_DESIGN.md` e `docs/RLS_POLICIES.sql` per i ruoli e helper SQL.
- **Schema:** UUID per PK, JSONB per metadata, TIMESTAMPTZ per timestamp. Vedi mapping tabelle in `docs/DB_MAPPING_MYSQL_TO_SUPABASE.md`.
- **Realtime:** Implementa subscription per eventi live (es. match actions) usando Supabase Realtime.
- **Microservizi:** Tutta la logica non-CRUD (algoritmi, AI, streaming) è gestita da microservizi via endpoint REST/RPC documentati in `docs/MICROSERVICES_ARCHITECTURE.md`.
- **Streaming:** Integrazione con orchestratore video (YouTube/TikTok) solo tramite API esterne.
- **Audit & Sicurezza:** Ogni azione critica deve essere tracciata (created_at, updated_at, log azioni).
- **Monitoring:** Integra Sentry, LogRocket e Supabase monitoring per errori e metriche.

---

## Convenzioni e Best Practice

- Segui i pattern di naming per funzioni RPC, trigger e microservizi.
- Aggiorna sempre la documentazione (`CHANGELOG.md`, `ARCHITECTURE_OVERVIEW.md`) per ogni modifica strutturale.
- Usa Supabase JS SDK come da esempio:
  ```js
  const { data: matches } = await supabase
    .from('matches')
    .select('*')
    .eq('event_id', eventId);

  supabase
    .from(`match_actions:match_id=eq.${matchId}`)
    .on('*', payload => console.log('New action:', payload.new))
    .subscribe();
  ```
- Testa le policy RLS con JWT diversi (`SET jwt.claims.sub = ...`).

---

## Documenti chiave da consultare

- `docs/ARCHITECTURE_OVERVIEW.md`
- `docs/AUTH_RLS_DESIGN.md`
- `docs/DB_MAPPING_MYSQL_TO_SUPABASE.md`
- `docs/MICROSERVICES_ARCHITECTURE.md`
- `docs/CHANGELOG.md`

---

## Workflow

1. Analizza lo schema Supabase (`docs/SUPABASE_SCHEMA.sql`) e le policy RLS.
2. Progetta le pagine Next.js/SvelteKit per admin e pubblico.
3. Implementa autenticazione e gestione ruoli con Supabase Auth.
4. Integra le query e le subscription realtime.
5. Collega i microservizi tramite endpoint REST/RPC.
6. Prevedi audit trail e monitoring.
7. Aggiorna la documentazione ad ogni modifica.

---

**Nota:** In caso di dubbi su naming, test automatici RLS, gestione errori microservizi o versionamento API, suggerisci di formalizzare/documentare come da istruzioni.

Questo prompt è pronto per essere usato dall’agente frontend per avviare lo sviluppo secondo le regole del progetto.