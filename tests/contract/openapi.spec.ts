import { describe, expect, it } from 'vitest';

import SwaggerParser from 'swagger-parser';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));

describe('OpenAPI contract', () => {
  it('is valid and contains critical paths', async () => {
    const schemaPath = resolve(currentDir, '../../openapi/athlos.yaml');
    const api = await SwaggerParser.validate(schemaPath);

    expect(api.paths).toHaveProperty('/events/{eventId}/registrations');
    expect(api.paths).toHaveProperty('/matches/{matchId}/score');
    expect(api.paths).toHaveProperty('/payments');
    expect(api.components?.schemas?.PaymentRequest).toBeDefined();
  });
});
