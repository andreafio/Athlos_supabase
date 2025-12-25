import { describe, expect, it } from 'vitest';

import { generateEliminationBracket } from '../../src/services/bracket/generator';

type Registration = {
  id: string;
  athleteId: string;
  eventId: string;
  status: 'pending' | 'confirmed';
};

type Payment = {
  id: string;
  registrationId: string;
  status: 'requires_action' | 'succeeded' | 'failed';
};

type MatchScore = {
  matchId: string;
  red: number;
  blue: number;
  penalties: number;
};

type EventContext = {
  registrations: Registration[];
  payments: Payment[];
  scores: MatchScore[];
};

const createContext = (): EventContext => ({
  registrations: [],
  payments: [],
  scores: []
});

const registerAthlete = (
  context: EventContext,
  payload: Omit<Registration, 'status'>
): Registration => {
  const registration: Registration = { ...payload, status: 'pending' };
  context.registrations.push(registration);
  return registration;
};

const confirmPayment = (context: EventContext, registrationId: string, amount: number): Payment => {
  const payment: Payment = {
    id: `payment-${context.payments.length + 1}`,
    registrationId,
    status: amount > 0 ? 'succeeded' : 'failed'
  };

  context.payments.push(payment);
  const registration = context.registrations.find((item) => item.id === registrationId);

  if (registration && payment.status === 'succeeded') {
    registration.status = 'confirmed';
  }

  return payment;
};

const recordScoreUpdate = (context: EventContext, update: MatchScore): MatchScore => {
  const existing = context.scores.find((score) => score.matchId === update.matchId);

  if (existing) {
    existing.red = update.red;
    existing.blue = update.blue;
    existing.penalties = update.penalties;
    return existing;
  }

  context.scores.push(update);
  return update;
};

describe('critical E2E flows', () => {
  it('registers an athlete, confirms payment, and seeds a bracket', () => {
    const context = createContext();
    const registration = registerAthlete(context, {
      id: 'registration-1',
      athleteId: 'athlete-1',
      eventId: 'event-1'
    });

    const payment = confirmPayment(context, registration.id, 45);
    const matches = generateEliminationBracket(
      context.registrations.map((entry) => ({ id: entry.athleteId }))
    );

    expect(payment.status).toBe('succeeded');
    expect(context.registrations[0].status).toBe('confirmed');
    expect(matches).not.toHaveLength(0);
  });

  it('records live score updates without mutating other matches', () => {
    const context = createContext();
    const first = recordScoreUpdate(context, { matchId: 'match-1', red: 1, blue: 0, penalties: 0 });
    const second = recordScoreUpdate(context, { matchId: 'match-2', red: 0, blue: 0, penalties: 1 });

    const updated = recordScoreUpdate(context, { matchId: 'match-1', red: 2, blue: 0, penalties: 0 });

    expect(first).not.toBe(second);
    expect(updated.red).toBe(2);
    expect(context.scores).toHaveLength(2);
  });
});
