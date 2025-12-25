import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '1m'
};

export default function bracketLoad() {
  const endpoint = __ENV.BRACKET_ENDPOINT;

  if (!endpoint) {
    return;
  }

  const payload = JSON.stringify({
    participants: ['athlete-1', 'athlete-2', 'athlete-3', 'athlete-4']
  });

  const headers = { 'Content-Type': 'application/json' };
  const response = http.post(endpoint, payload, { headers });

  check(response, {
    'received 200/201': (r) => r.status === 200 || r.status === 201,
    'body is not empty': (r) => !!r.body
  });

  sleep(1);
}
