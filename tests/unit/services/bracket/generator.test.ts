import { describe, expect, it } from 'vitest';

import { generateEliminationBracket, normalizeParticipants } from '../../../../src/services/bracket/generator';

describe('bracket generator', () => {
  it('normalizes participants by filling seeds', () => {
    const normalized = normalizeParticipants([
      { id: 'athlete-1', seed: 5 },
      { id: 'athlete-2' },
      { id: 'athlete-3', seed: 2 }
    ]);

    expect(normalized[0].id).toBe('athlete-3');
    expect(normalized[1].seed).toBe(2);
    expect(normalized[2].seed).toBe(5);
  });

  it('pads the bracket with byes and returns first round matches', () => {
    const matches = generateEliminationBracket([
      { id: 'athlete-1', seed: 1 },
      { id: 'athlete-2', seed: 4 },
      { id: 'athlete-3', seed: 2 }
    ]);

    expect(matches).toHaveLength(4);
    expect(matches.filter((match) => match.isBye)).toHaveLength(2);
    expect(matches[0].red).toBe('athlete-1');
    expect(matches[0].blue?.startsWith('bye')).toBe(true);
  });
});
