# 🏆 Bracket Service – OpenAPI Blueprint (v1)

Versioned endpoints for bracket generation, seeding updates, and match retrieval. All routes are prefixed with `/v1` and require authenticated requests.

## 🔒 Authentication & Headers

- **JWT**: `Authorization: Bearer <user_jwt>` for end-user actions scoped by club/event.
- **Service Token**: `Athlos-Service-Token: <token>` for trusted microservice-to-microservice calls.
- **Idempotency**: `Idempotency-Key: <uuid>` is **required** on all write operations (POST/PATCH) to guarantee safe retries.

## 🌐 Base URL

```
https://api.athlos.app/v1
```

## 📡 Endpoints

### POST /brackets

Create a bracket for an event/division with deterministic seeding.

**Request**

```json
{
  "event_id": "evt_123",
  "division": "senior",
  "participants": [
    { "id": "ath_1", "seed": 1 },
    { "id": "ath_2", "seed": 2 }
  ],
  "rules": { "format": "single_elim", "best_of": 3 }
}
```

**Response 201**

```json
{
  "id": "brk_789",
  "status": "ready",
  "matches": [
    { "id": "mtc_1", "round": 1, "participants": ["ath_1", "ath_2"] }
  ],
  "created_at": "2024-05-12T10:00:00Z"
}
```

**Error Codes**

- `400` invalid payload (e.g., missing seeds or duplicate participants)
- `401` missing/invalid JWT or service token
- `409` bracket already exists for event/division (idempotent reuse)
- `422` unsupported ruleset

**Retry & Rate Limit**

- Backoff for `429` (60 RPM per tenant) and `503` with exponential retries up to 3 attempts when using the same `Idempotency-Key`.

### GET /brackets/{bracketId}

Retrieve bracket topology and status.

**Response 200**

```json
{
  "id": "brk_789",
  "status": "ready",
  "rounds": 3,
  "matches": [
    { "id": "mtc_1", "round": 1, "participants": ["ath_1", "ath_2"], "score": null }
  ]
}
```

**Error Codes**: `401`, `403` (cross-club access), `404` (not found)

### PATCH /brackets/{bracketId}/seeding

Update participant seeding before play begins. Uses idempotent writes.

**Request**

```json
{
  "participants": [
    { "id": "ath_2", "seed": 1 },
    { "id": "ath_1", "seed": 2 }
  ]
}
```

**Response 200**

```json
{
  "id": "brk_789",
  "status": "ready",
  "participants": [
    { "id": "ath_2", "seed": 1 },
    { "id": "ath_1", "seed": 2 }
  ]
}
```

**Error Codes**: `400` invalid seed ordering, `409` bracket locked (matches started), plus auth errors above.

### GET /brackets/{bracketId}/matches

List matches and scores for client sync.

**Query Params**: `round` (optional), `status` (optional: pending|live|final)

**Response 200**

```json
{
  "bracket_id": "brk_789",
  "matches": [
    {
      "id": "mtc_1",
      "round": 1,
      "status": "live",
      "participants": ["ath_1", "ath_2"],
      "score": { "ath_1": 1, "ath_2": 0 }
    }
  ]
}
```

**Error Codes**: `401`, `403`, `404`

## ⚠️ Edge Cases

- Repeated POST with same `Idempotency-Key` returns the original `201` body even if the client retries after a timeout.
- PATCH after the bracket is locked yields `409` and must not mutate matches.
- Participants missing seeds default to lowest priority but still validate uniqueness.

## 🔄 Retry & Rate Limiting Policy

- **Reads**: 120 RPM per tenant; **Writes**: 60 RPM per tenant.
- Honor `Retry-After` header on `429`/`503`; exponential backoff starting at 2s.
- Idempotent writes prevent duplicate brackets when clients retry.

