export interface Participant {
  id: string;
  seed?: number;
  club?: string;
}

export interface BracketMatch {
  id: string;
  round: number;
  red?: string;
  blue?: string;
  isBye: boolean;
}

const NEXT_POWER_OF_TWO = (value: number): number => {
  if (value < 1) {
    return 1;
  }

  return 2 ** Math.ceil(Math.log2(value));
};

export const normalizeParticipants = (participants: Participant[]): Participant[] => {
  return participants
    .map((participant, index) => ({
      ...participant,
      seed: participant.seed ?? index + 1
    }))
    .sort((a, b) => (a.seed ?? 0) - (b.seed ?? 0));
};

export const generateEliminationBracket = (participants: Participant[]): BracketMatch[] => {
  const normalizedParticipants = normalizeParticipants(participants);

  if (normalizedParticipants.length === 0) {
    return [];
  }

  const bracketSize = NEXT_POWER_OF_TWO(normalizedParticipants.length);
  const paddedParticipants: Participant[] = [...normalizedParticipants];

  while (paddedParticipants.length < bracketSize) {
    paddedParticipants.push({ id: `bye-${paddedParticipants.length + 1}` });
  }

  const matches: BracketMatch[] = [];

  for (let index = 0; index < paddedParticipants.length; index += 2) {
    const red = paddedParticipants[index];
    const blue = paddedParticipants[index + 1];
    const blueIsBye = !blue || blue.id.startsWith('bye');

    matches.push({
      id: `M${matches.length + 1}`,
      round: 1,
      red: red?.id,
      blue: blue?.id,
      isBye: blueIsBye
    });
  }

  return matches;
};
