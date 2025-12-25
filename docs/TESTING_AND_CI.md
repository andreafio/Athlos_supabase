# Testing, Coverage, and CI Standards

This project ships a consolidated workflow for linting/formatting, unit tests across database artefacts and services, contract validation against the OpenAPI spec, critical-path E2E flows, and opt-in load tests for realtime and bracket generation.

## Commands

| Purpose | Command |
| --- | --- |
| Format check | `npm run format:check` |
| Lint | `npm run lint` |
| Unit tests (DB + services) with coverage | `npm run test:unit` |
| Contract tests (OpenAPI) | `npm run test:contract` |
| Critical-path E2E simulations | `npm run test:e2e` |
| Full suite + coverage reports | `npm test` |

## Coverage thresholds

Coverage gates are enforced in `vitest.config.ts` (80% statements/functions/lines, 75% branches). The CI workflow uploads LCOV and JSON reports from `coverage/` for consumption by dashboards.

## Contract tests (OpenAPI)

`openapi/athlos.yaml` defines the registration, score update, and payment endpoints. `tests/contract/openapi.spec.ts` validates the schema with `swagger-parser` and asserts the critical paths are present.

## E2E simulations

`tests/e2e/criticalFlows.spec.ts` stitches together registration, payment confirmation, and score updates against the lightweight bracket generator to ensure the flows remain coherent even before full service integration.

## Load tests

Two k6 scenarios live in `tests/load/`:

- `realtime.js`: WebSocket subscriptions; gated by `REALTIME_WS_URL`.
- `bracket.js`: High-volume bracket generation API calls; gated by `BRACKET_ENDPOINT`.

Set the environment variables/secrets before running locally or enabling the workflow job. Without them the scenarios are skipped.

## CI workflow

`.github/workflows/ci.yml` orchestrates the suite:

- **lint_format**: lint + format check.
- **unit_contract_e2e**: unit, contract, and E2E suites with coverage artefacts.
- **load_tests**: optional, requires `REALTIME_WS_URL` and `BRACKET_ENDPOINT` secrets; uses k6.

Use `workflow_dispatch` to trigger load tests manually when infrastructure endpoints are available.
