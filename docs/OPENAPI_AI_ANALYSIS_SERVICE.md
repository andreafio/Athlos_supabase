# 🤖 AI Analysis Service – OpenAPI Blueprint (v1)

Versioned endpoints for generating and retrieving AI-driven match insights. All routes are prefixed with `/v1` and require authenticated requests.

## 🔒 Authentication & Headers

- **JWT**: `Authorization: Bearer <user_jwt>` for coaches/analysts requesting insights.
- **Service Token**: `Athlos-Service-Token: <token>` for internal pipelines ingesting match data.
- **Idempotency**: `Idempotency-Key: <uuid>` **required** on write operations (POST) to ensure safe retries.

## 🌐 Base URL

```
https://api.athlos.app/v1
```

## 📡 Endpoints

### POST /ai/analysis

Submit a match for AI processing.

**Request**

```json
{
  "match_id": "mtc_123",
  "video_url": "https://cdn.athlos.app/vod/mtc_123.mp4",
  "signals": ["highlights", "momentum", "player_stats"],
  "webhook_url": "https://coach.app/hooks/ai",
  "priority": "standard"
}
```

**Response 202**

```json
{
  "job_id": "job_456",
  "status": "queued",
  "eta_seconds": 120
}
```

**Error Codes**

- `400` invalid payload or unsupported signal type
- `401` missing/invalid auth
- `403` access denied to match
- `409` job already queued for match (idempotent reuse)

### GET /ai/analysis/{jobId}

Retrieve job status and final outputs.

**Response 200**

```json
{
  "job_id": "job_456",
  "status": "completed",
  "outputs": {
    "highlights": ["00:10-00:30", "03:20-03:45"],
    "momentum": [{ "time": "00:00", "score": 0.4 }],
    "player_stats": [{ "athlete_id": "ath_1", "aces": 5 }]
  },
  "completed_at": "2024-05-12T12:10:00Z"
}
```

**Error Codes**: `401`, `403`, `404`

### POST /ai/analysis/{jobId}/cancel

Cancel a queued or running job (idempotent).

**Response 200**

```json
{ "job_id": "job_456", "status": "canceled" }
```

**Error Codes**: `401`, `403`, `404`, `409` job already completed

## ⚠️ Edge Cases

- Duplicate submissions with the same `Idempotency-Key` return the original `202` response, preventing duplicate processing charges.
- Cancel after completion returns `409` without changing the job state.
- Webhook delivery failures trigger retries with exponential backoff and HMAC signatures (documented separately).

## 🔄 Retry & Rate Limiting Policy

- **Reads**: 120 RPM per tenant; **Writes**: 40 RPM per tenant.
- Backoff on `429`/`503` honoring `Retry-After`; up to 3 attempts with jitter using the same `Idempotency-Key` for writes.
- Async processing: clients should poll GET status with ETag/If-None-Match to reduce rate usage.
