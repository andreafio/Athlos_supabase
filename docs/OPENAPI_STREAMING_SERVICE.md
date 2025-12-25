# 📺 Streaming Service – OpenAPI Blueprint (v1)

Versioned endpoints for ingest, playback, and moderation around live streams. All routes are prefixed with `/v1` and require authenticated requests.

## 🔒 Authentication & Headers

- **JWT**: `Authorization: Bearer <user_jwt>` for user-facing playback and moderation actions.
- **Service Token**: `Athlos-Service-Token: <token>` for orchestrator → streaming service calls.
- **Idempotency**: `Idempotency-Key: <uuid>` is **required** on write operations (POST/PATCH/DELETE).

## 🌐 Base URL

```
https://api.athlos.app/v1
```

## 📡 Endpoints

### POST /streams

Create a live stream session for an event.

**Request**

```json
{
  "event_id": "evt_123",
  "title": "Finals Court 1",
  "ingest_profile": "1080p",
  "privacy": "public",
  "recording": true
}
```

**Response 201**

```json
{
  "id": "str_789",
  "status": "ready",
  "ingest_url": "rtmps://ingest.athlos.app/live/str_789",
  "playback_url": "https://cdn.athlos.app/hls/str_789.m3u8",
  "recording": true,
  "created_at": "2024-05-12T10:00:00Z"
}
```

**Error Codes**

- `400` invalid payload or unsupported profile
- `401` missing/invalid auth
- `403` user lacks event permissions
- `409` stream already exists for event/court (idempotent reuse)

### GET /streams/{streamId}

Fetch stream status and playback information.

**Response 200**

```json
{
  "id": "str_789",
  "status": "live",
  "playback_url": "https://cdn.athlos.app/hls/str_789.m3u8",
  "viewers": 152,
  "recording": true,
  "started_at": "2024-05-12T10:05:00Z"
}
```

**Error Codes**: `401`, `403`, `404`

### PATCH /streams/{streamId}

Update metadata (title/privacy) or toggle recording. Idempotent via key.

**Request**

```json
{
  "title": "Finals Court 1 (Updated)",
  "privacy": "private",
  "recording": false
}
```

**Response 200**

```json
{
  "id": "str_789",
  "title": "Finals Court 1 (Updated)",
  "privacy": "private",
  "recording": false,
  "status": "ready"
}
```

**Error Codes**: `400` invalid change, `403`, `404`, `409` stream locked (ended)

### POST /streams/{streamId}/end

End a live stream and finalize recording.

**Response 200**

```json
{
  "id": "str_789",
  "status": "ended",
  "vod_url": "https://cdn.athlos.app/vod/str_789.mp4",
  "ended_at": "2024-05-12T11:30:00Z"
}
```

**Error Codes**: `401`, `403`, `404`, `409` already ended

### GET /streams/{streamId}/viewers

Retrieve live viewer count and region breakdown (cached).

**Response 200**

```json
{
  "stream_id": "str_789",
  "total": 152,
  "regions": { "EU": 45, "NA": 70, "APAC": 37 }
}
```

**Error Codes**: `401`, `403`, `404`

## ⚠️ Edge Cases

- Replaying POST `/streams` with the same `Idempotency-Key` returns the original `201` body, preventing duplicate stream sessions.
- PATCH on an ended stream returns `409` and does not reopen it.
- GET endpoints may return stale metrics; clients should cache-bust only when status is `live`.

## 🔄 Retry & Rate Limiting Policy

- **Reads**: 200 RPM per tenant; **Writes**: 60 RPM per tenant.
- Backoff on `429`/`503` with `Retry-After` support; exponential retry up to 3 attempts using the same `Idempotency-Key` for writes.
- Ingest creation is idempotent by event/court to avoid duplicate live feeds.
