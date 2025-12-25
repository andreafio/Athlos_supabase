# 🛰️ Osservabilità e Monitoraggio

Linee guida per log, metriche e monitoraggio per Supabase Edge Functions e microservizi Athlos.

## 1) Formati di log (JSON) e correlazione trace/span

### Supabase Edge Functions
- **Formato**: JSON strutturato, un evento per riga.
- **Campi obbligatori**: `timestamp` (ISO-8601, UTC), `level`, `message`, `trace_id`, `span_id`, `user_id` (se autenticato), `tenant_id`, `request_id`, `function` (nome), `http.method`, `http.path`, `http.status`, `duration_ms`, `cold_start` (bool), `source`="supabase-edge".
- **Livello minimo**: `info` in produzione, `debug` solo in ambienti di test.
- **Correlazione**: propaga `traceparent` / `baggage` dagli header HTTP alle chiamate interne (es. fetch verso microservizi) e include `trace_id`/`span_id` nei log.
- **Esempio**:
```json
{"timestamp":"2024-09-01T10:15:30.123Z","level":"info","message":"created bracket","trace_id":"4f9c...","span_id":"a12b...","user_id":"auth0|123","tenant_id":"club_42","request_id":"req-abc","function":"bracket-create","http.method":"POST","http.path":"/functions/v1/bracket","http.status":201,"duration_ms":142,"cold_start":false,"source":"supabase-edge"}
```

### Microservizi (API/worker/streaming)
- **Formato**: JSON strutturato, coerente con Edge Functions.
- **Campi aggiuntivi**: `service` (es. `bracket-service`, `stream-orchestrator`), `environment`, `pod`/`instance`, `retry_count`, `queue_name` (per worker), `stream_session_id` (per streaming), `client_ip` (mascherato se necessario), `source`="microservice".
- **Livello minimo**: `info` per API/worker, `warn`+ sampling per eventi molto frequenti; `debug` solo se attivato via flag.
- **Correlazione**: estrai `traceparent` dagli ingressi (API Gateway/Supabase) e continua la catena su chiamate uscenti (HTTP/gRPC/DB). Loggare sempre `trace_id`/`span_id` e `parent_span_id` se disponibile.

## 2) Metriche chiave e SLO/SLA

| Area | Metrica | Definizione | Target SLO | SLA (clienti Enterprise) |
|------|---------|-------------|------------|--------------------------|
| **Performance** | Latency P95 (Edge Functions) | P95 end-to-end per richiesta HTTP | ≤ 350 ms | 99.5% richieste < 500 ms su base mensile |
| | Latency P95 (API microservizi) | P95 per endpoint critici | ≤ 300 ms | 99.5% richieste < 450 ms |
| **Affidabilità** | Error rate (5xx + timeout) | Percentuale su totale richieste | < 0.5% | < 1% su base mensile |
| **Realtime** | Realtime throughput | Messaggi consegnati/minuto per Realtime | ≥ 99% consegna entro 1s | Disponibilità 99.9% canale Realtime |
| | Stream health | Uptime pipeline streaming + drop frame | ≥ 99.9% uptime, drop frame < 1% | 99.5% uptime canale streaming |
| **Worker** | Job success rate | Successi / job totali per queue | ≥ 99.5% | 99% mensile |
| **DB** | Replication lag | Ritardo replica Supabase/PG | < 200 ms | < 500 ms |
| **Risorse** | CPU/RAM saturation | Utilizzo medio per pod/instance | < 70% sustained | < 85% sustained |

> Nota: SLO monitorati via burn-rate; SLA comunicato ai clienti e misurato mensilmente.

## 3) Stack di monitoraggio e standard
- **Tracing**: OpenTelemetry SDK in Edge Functions (Node Deno) e microservizi (Node/Go). Esporta su **Tempo/OTLP**.
- **Logging**: OTel logger o pino/winston con exporter **Loki** (via Promtail/OTLP). Livelli: `debug` (dev), `info` (prod default), `warn`, `error`, `fatal`.
- **Metriche**: OTel Metrics → **Prometheus**; visualizzazione **Grafana**.
- **Alerting**: Grafana Alerting su metriche; opz. PagerDuty/Slack.
- **Profiling**: OTel Profiling (se supportato) o pprof per Go; sampling 1-5%. 
- **Correlazione**: log-to-trace via `trace_id`/`span_id`; includere `tenant_id`/`org_id` per filtri multi-tenant.

## 4) Dashboard di base (Grafana)
1. **Edge Functions Overview**
   - P95/avg latency per funzione, cold starts, RPS, error rate (4xx/5xx), durations per span, throttle rate, Supabase Realtime throughput.
   - Logs correlati filtrabili per `trace_id`/`tenant_id`.
2. **API & Worker Health**
   - Error rate per endpoint/queue, retry count, queue depth, job duration P95/P99, dead-letter rate, dependency latency (DB/HTTP), saturation (CPU/RAM).
3. **Streaming & Realtime**
   - Stream uptime, drop frame %, ingest/egress bitrate, Realtime messages delivered, subscription churn, websocket disconnect reasons.
4. **Database & Supabase**
   - Replication lag, connection pool usage, slow queries (P95), cache hit rate, disk IO, backups status.

## 5) Alert di base (esempi)
- **High error rate**: error_rate > 1% per 5m (Edge/API); pagare se > 5% per 15m.
- **Latency burn**: P95 > SLO target per 15m; paging se P99 > 2x SLO per 10m.
- **Realtime drop**: consegna < 98% su 5m o disconnect spike > 2x baseline.
- **Streaming health**: uptime < 99.5% su 1h o drop frame > 2% per 5m.
- **Queue delay**: job wait time > 2x SLO o DLQ > 0.5% in 10m.
- **Infra**: CPU/RAM > 85% per 15m, replica lag > 500ms per 5m, disk > 80%.

## 6) Operatività
- **Runbook**: per ogni alert indicare contatto, passi di diagnostica (dashboard, query Loki/Tempo/Prometheus), rollback/feature-flag e limite massimo di tempo per mitigazione.
- **Sampling**: tracing 10-20% su traffico standard, 100% su errori; log sampling per eventi ad alta frequenza (p.es. Realtime ack) mantenendo `warn/error` sempre non campionati.
- **Retention**: log 14-30 giorni, trace 7-14 giorni, metriche 13 mesi (rollup), sessioni streaming 90 giorni per audit.
- **Privacy**: mascherare PII nei log (`user_email`, IP se richiesto); usare `tenant_id` per filtri.
