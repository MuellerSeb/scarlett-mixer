const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
const statusEl = document.getElementById('status');
const join = document.getElementById('join');
const vol = document.getElementById('vol');
const pan = document.getElementById('pan');
const ml = document.getElementById('ml');
const mr = document.getElementById('mr');
const joinedRow = document.getElementById('joinedRow');
const splitRow = document.getElementById('splitRow');
const l = document.getElementById('l');
const r = document.getElementById('r');

function send(op, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ op, data }));
  }
}

ws.onopen = () => (statusEl.textContent = 'connected');
ws.onclose = () => (statusEl.textContent = 'disconnected');
ws.onerror = () => (statusEl.textContent = 'error');

let lastMeter = 0;
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.type === 'snapshot') {
    const mix = msg.mixes['B'];
    if (!mix) return;

    join.checked = mix.joined;
    if (mix.joined) {
      joinedRow.style.display = 'flex';
      splitRow.style.display = 'none';
      vol.value = mix.volume;
      pan.value = mix.pan;
    } else {
      joinedRow.style.display = 'none';
      splitRow.style.display = 'flex';
      l.value = mix.gain_l;
      r.value = mix.gain_r;
    }

    const now = performance.now();
    if (now - lastMeter > 33) {
      ml.style.height = Math.round(100 * (mix.level_l || 0)) + '%';
      mr.style.height = Math.round(100 * (mix.level_r || 0)) + '%';
      lastMeter = now;
    }
  }
};

join.addEventListener('change', () => {
  send('set_join', { mix: 'B', joined: join.checked });
});

vol.addEventListener('input', () => send('set_gain', { mix: 'B', value: parseFloat(vol.value) }));
pan.addEventListener('input', () => send('set_pan', { mix: 'B', value: parseFloat(pan.value) }));
l.addEventListener('input', () => send('set_lr', { mix: 'B', l: parseFloat(l.value) }));
r.addEventListener('input', () => send('set_lr', { mix: 'B', r: parseFloat(r.value) }));
