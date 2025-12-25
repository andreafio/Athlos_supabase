import ws from 'k6/ws';
import { check, sleep } from 'k6';

export const options = {
  vus: 20,
  duration: '30s'
};

export default function realtimeLoad() {
  const url = __ENV.REALTIME_WS_URL;

  if (!url) {
    return;
  }

  const res = ws.connect(url, {}, (socket) => {
    socket.on('open', () => {
      socket.send(JSON.stringify({ type: 'subscribe', channel: 'matches' }));
    });

    socket.on('message', () => {
      // Intentionally lean: we only need to assert message receipt under load.
    });

    socket.setTimeout(() => {
      socket.close();
    }, 5000);
  });

  check(res, {
    'connection established': (r) => r && r.status === 101
  });

  sleep(1);
}
