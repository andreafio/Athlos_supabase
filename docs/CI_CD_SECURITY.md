# CI/CD, Sicurezza e Deploy

Piano operativo per pipeline, gestioni secret e migrazioni con rollback.

## 1) Pipeline CI/CD

- **Trigger**: PR verso `main`, push su `main`, tag/release per deploy.
- **Job core** (tutti bloccanti):
  - **Lint & format**: ESLint/TypeScript + formatter.
  - **Unit test**: coverage minimo e report.
  - **RLS & auth test**: suite SQL/pgTAP per evitare regressioni di policy.
  - **API contract/e2e**: test PostgREST/RPC con contratti OpenAPI/contract test + smoke e2e per i flussi critici (registrazione evento, aggiornamento match).
  - **Security**: audit dipendenze (`npm|pnpm audit`), SAST TypeScript.
  - **Migrations dry-run**: applica le migration Supabase su DB effimero, esegue test e genera artefatto stato schema.

### Gating per ambiente

| Ambiente | Gating obbligatorio |
| --- | --- |
| **PR → main** | Lint, Unit, RLS, Security (audit+SAST) |
| **Deploy staging** | Tutto quanto sopra + API contract/e2e + migrations dry-run |
| **Deploy production** | Tutti i job; approvazione manuale release manager; finestra di cambio; evidenza backup/rollback pronta |

- **Artefatti**: report test, coverage, log audit/SAST, dump schema post-migrazione.
- **Rollback check**: il deploy prod parte solo se esiste procedura di rollback validata nella run (backup o migrazione inversa disponibile).

## 2) Gestione secret e rotazione

- **Fonte di verità**: vault (Doppler o 1Password) con audit trail; sincronizzazione verso Vercel/GitHub Actions/Supabase env solo tramite integrazioni.
- **Separation of env**: `dev`, `staging`, `prod` isolati; no riuso di chiavi tra ambienti.
- **Rotazione**: 
  - Chiavi service Supabase e webhook Stripe: mensile o immediata in caso di sospetto leak.
  - Stream/API keys (es. streaming): settimanale come indicato nelle note di sicurezza.
  - Segreti CI/CD (token deploy, SSH): trimestrale o on-demand.
- **Distribuzione**: caricare le variabili solo via secret manager → environment Vercel/railway/microservizi; vietato commitare `.env`.

## 3) Migrazioni DB & rollback

- **Versioning**: ogni migration è accoppiata a un ID release; mantenere script `down` o playbook di ripristino (dump/restore).
- **Pipeline**:
  1. Esegue migration su DB effimero in CI.
  2. Lancia test unit, RLS, contract/e2e contro lo schema migrato.
  3. Salva schema diff e dati seed come artefatti.
- **Staging**: applica migration; se fallisce test smoke → rollback immediato con migration inversa o restore backup.
- **Production**:
  - Pre-requisito: backup completo o snapshot automatica.
  - Deploy con lock/maintenance breve; verifica post-deploy automatica (query di salute, policy RLS critiche).
  - **Rollback**: script `down` validato in CI **oppure** restore da backup + re-run test smoke.

## 4) Controlli di sicurezza continui

- Audit dipendenze e SAST sono bloccanti su `main` e per i deploy.
- Aggiungere scanning periodico programmato (es. weekly) per nuove CVE anche senza code change.
- Loggare i risultati di security job e conservarli per audit.
