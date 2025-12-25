import { describe, expect, it } from 'vitest';

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = dirname(fileURLToPath(import.meta.url));

describe('supabase schema snapshot', () => {
  it('contains table definitions for core entities', () => {
    const schemaPath = resolve(currentDir, '../../../docs/SUPABASE_SCHEMA.sql');
    const content = readFileSync(schemaPath, 'utf8');

    expect(content.length).toBeGreaterThan(100);
    expect(content).toMatch(/CREATE TABLE/i);
    expect(content).toMatch(/events/i);
    expect(content).toMatch(/athletes/i);
  });
});
