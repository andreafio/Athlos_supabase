
# Copilot Instructions for Athlos Supabase Migration

## Project Overview
- **Purpose**: Gestione eventi sportivi (focus Judo) migrata da Laravel/MySQL a Supabase (PostgreSQL + Auth + RLS).
- **Core**: Supabase per dati, auth, realtime; microservizi per logica complessa (bracket, AI, streaming); frontend Next.js/SvelteKit.

## Architettura & Flussi Dati
- **Supabase**: DB centrale, REST API (PostgREST), Realtime (WebSocket), Auth (JWT, RLS).
- **Microservizi**: Node.js/Python per bracket, match, AI video, orchestrazione streaming. Solo accesso via REST/RPC, mai diretto al DB.
- **Frontend**: Next.js (admin/pubblico), Google AI Studio (dev), React Native (mobile futuro).
- **Esterni**: API YouTube/TikTok per streaming e analytics.

## Convenzioni & Pattern
- **RLS**: Tutto il controllo accessi è a livello DB. Vedi `docs/AUTH_RLS_DESIGN.md` e `docs/RLS_POLICIES.sql` per policy e helper (`is_admin`, `has_role`).
- **Consolidamento Tabelle**: Tabelle ridondanti MySQL unite (es. `judo_match_points` + `match_points` → `match_actions`). Vedi `docs/DB_MAPPING_MYSQL_TO_SUPABASE.md`.
- **Schema**: UUID per PK, JSONB per metadata, TIMESTAMPTZ per timestamp. Index su tutte le FK e colonne ad alto volume.
- **Microservizi**: Tutta la logica non-CRUD (algoritmi, AI, streaming) va in microservizi, non in Supabase.
- **Naming**: Funzioni RPC, trigger e microservizi devono seguire pattern chiari e documentati (da formalizzare se mancante).

## Workflow Sviluppo
- **Schema DB**: Modifica `docs/SUPABASE_SCHEMA.sql` e `docs/RLS_POLICIES.sql`. Ogni cambiamento va documentato in `docs/CHANGELOG.md`.
- **Policy RLS**: Abilita RLS su tutte le tabelle, usa helper SQL per i ruoli. Testa sempre con JWT reali (vedi esempi in AUTH_RLS_DESIGN.md).
- **Test RLS**: Esegui test manuali/automatici con JWT diversi (`SET jwt.claims.sub = ...`).
- **Aggiunta Tabelle/Policy/Microservizi**: Segui pattern di naming, aggiorna la documentazione (`CHANGELOG.md`, `ARCHITECTURE_OVERVIEW.md`, `MICROSERVICES_ARCHITECTURE.md`).
- **Audit & Sicurezza**: Ogni modifica che impatta dati sensibili o accessi deve prevedere audit trail e test di sicurezza. Usa `created_at`, `updated_at` e log delle azioni.
- **Frontend**: Usa Supabase JS SDK per auth, query, subscriptions. Esempio:
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
- **Migrazione**: Segui le fasi in `DB_MAPPING_MYSQL_TO_SUPABASE.md` e `PROJECT_ROADMAP.md`.

## Integrazione & Deployment
- **Supabase**: Tutti i dati e auth passano da Supabase. Niente accesso diretto al DB da microservizi/frontend.
- **Microservizi**: Esporre solo endpoint REST/RPC. Documentare ogni nuovo endpoint in `MICROSERVICES_ARCHITECTURE.md`.
- **Streaming**: Video live/overlay AI tramite orchestratore, output su YouTube/TikTok.
- **Monitoring**: Usa Sentry, LogRocket, Supabase monitoring per errori e metriche.

## Esempi e Best Practice
- **Test Policy RLS**:
	```sql
	SET ROLE coach_test;
	SET jwt.claims.sub = 'coach-uuid';
	SELECT * FROM athletes; -- Solo atleti assegnati
	```
- **Audit Trail**: Ogni tabella deve avere `created_at`, `updated_at`. Le azioni critiche devono essere loggate.
- **Documentazione**: Aggiorna sempre `CHANGELOG.md` e i file docs/ per ogni modifica strutturale.

## Riferimenti Chiave
- `docs/ARCHITECTURE_OVERVIEW.md`: Architettura, flussi dati, boundary servizi.
- `docs/AUTH_RLS_DESIGN.md`: Policy RLS, gerarchia ruoli, helper SQL.
- `docs/DB_MAPPING_MYSQL_TO_SUPABASE.md`: Mapping tabelle, migrazione, ottimizzazione.
- `docs/MICROSERVICES_ARCHITECTURE.md`: Pattern microservizi, esempi endpoint.
- `docs/CHANGELOG.md`: Traccia tutte le modifiche a schema e policy.

---

**Per AI agents:**
- Verifica sempre policy RLS e accesso per ruolo prima di proporre pattern di accesso dati.
- Usa helper SQL per i ruoli nelle policy.
- Se mancano naming convention, test automatici RLS, gestione errori microservizi o versionamento API, suggerisci di formalizzare/documentare.
- In caso di dubbio, consulta i file docs/ sopra per i workflow e le convenzioni di progetto.
