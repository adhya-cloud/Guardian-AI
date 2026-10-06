const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const { createApp } = require('../src/app');
const { MemoryStore } = require('../src/store/memoryStore');
const { loadConfig } = require('../src/config');

let server;
let base;
let clock = Date.parse('2026-09-30T10:00:00Z');
const store = new MemoryStore({ maxPointsPerSession: 5 });

before(async () => {
  const config = { ...loadConfig({}), publicUrl: 'https://track.example.org' };
  const app = createApp({ store, config, now: () => clock });
  await new Promise((resolve) => {
    server = app.listen(0, resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await store.close();
  await new Promise((resolve) => server.close(resolve));
});

const api = (path, { method = 'GET', body, key } = {}) =>
  fetch(base + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(key ? { authorization: `Bearer ${key}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

async function createSession(overrides = {}) {
  const res = await api('/api/v1/sessions', {
    method: 'POST',
    body: { name: 'Asha', reason: 'live', durationMinutes: 30, ...overrides },
  });
  assert.equal(res.status, 201);
  return res.json();
}

test('health reports the store kind', async () => {
  const res = await api('/health');
  assert.deepEqual(await res.json(), { status: 'ok', store: 'memory' });
});

test('creating a session returns an owner key and a public view link', async () => {
  const s = await createSession();
  assert.match(s.ownerKey, /^[A-Za-z0-9_-]{40,}$/);
  assert.equal(s.viewUrl, `https://track.example.org/t/${s.viewToken}`);
  assert.equal(new Date(s.expiresAt).getTime(), clock + 30 * 60 * 1000);
});

test('rejects invalid session input', async () => {
  for (const body of [
    { reason: 'live', durationMinutes: 30 },
    { name: 'A', reason: 'party', durationMinutes: 30 },
    { name: 'A', reason: 'sos', durationMinutes: 2 },
  ]) {
    const res = await api('/api/v1/sessions', { method: 'POST', body });
    assert.equal(res.status, 400, JSON.stringify(body));
  }
});

test('points require the owner key and appear in the viewer feed', async () => {
  const s = await createSession({ reason: 'sos' });
  const points = [{ lat: 19.076, lng: 72.8777, accuracy: 12, battery: 64, t: clock - 1000 }];

  let res = await api(`/api/v1/sessions/${s.id}/points`, { method: 'POST', body: { points } });
  assert.equal(res.status, 404, 'no key');
  res = await api(`/api/v1/sessions/${s.id}/points`, { method: 'POST', body: { points }, key: 'wrong-key' });
  assert.equal(res.status, 404, 'wrong key');
  res = await api(`/api/v1/sessions/${s.id}/points`, { method: 'POST', body: { points }, key: s.ownerKey });
  assert.equal(res.status, 202);

  res = await api(`/api/v1/view/${s.viewToken}`);
  const view = await res.json();
  assert.equal(view.status, 'active');
  assert.equal(view.reason, 'sos');
  assert.equal(view.name, 'Asha');
  assert.deepEqual(view.points, points);
  assert.equal(view.ownerKeyHash, undefined, 'never leaks the key hash');
});

test('validates individual points', async () => {
  const s = await createSession();
  for (const p of [
    { lat: 91, lng: 0, t: clock },
    { lat: 0, lng: 181, t: clock },
    { lat: 0, lng: 0, t: clock - 2 * 24 * 60 * 60 * 1000 },
  ]) {
    const res = await api(`/api/v1/sessions/${s.id}/points`, { method: 'POST', body: { points: [p] }, key: s.ownerKey });
    assert.equal(res.status, 400, JSON.stringify(p));
  }
});

test('keeps only the most recent points', async () => {
  const s = await createSession();
  const points = Array.from({ length: 8 }, (_, i) => ({ lat: 10 + i, lng: 70, t: clock - (8 - i) * 1000 }));
  await api(`/api/v1/sessions/${s.id}/points`, { method: 'POST', body: { points }, key: s.ownerKey });
  const view = await (await api(`/api/v1/view/${s.viewToken}`)).json();
  assert.equal(view.points.length, 5);
  assert.equal(view.points.at(-1).lat, 17);
});

test('owner can escalate, extend and end a session', async () => {
  const s = await createSession({ reason: 'journey', durationMinutes: 10 });
  let res = await api(`/api/v1/sessions/${s.id}`, { method: 'PATCH', body: { reason: 'sos', extendMinutes: 20 }, key: s.ownerKey });
  let body = await res.json();
  assert.equal(body.reason, 'sos');
  assert.equal(new Date(body.expiresAt).getTime(), clock + 30 * 60 * 1000);

  res = await api(`/api/v1/sessions/${s.id}`, { method: 'PATCH', body: { status: 'ended' }, key: s.ownerKey });
  body = await res.json();
  assert.equal(body.status, 'ended');

  res = await api(`/api/v1/sessions/${s.id}/points`, { method: 'POST', body: { points: [{ lat: 1, lng: 1, t: clock }] }, key: s.ownerKey });
  assert.equal(res.status, 409, 'no points after end');
  const view = await (await api(`/api/v1/view/${s.viewToken}`)).json();
  assert.equal(view.status, 'ended');
});

test('sessions report expired after their end time and are purged later', async () => {
  const s = await createSession({ durationMinutes: 5 });
  clock += 6 * 60 * 1000;
  let view = await (await api(`/api/v1/view/${s.viewToken}`)).json();
  assert.equal(view.status, 'expired');

  clock += 2 * 60 * 60 * 1000;
  store.sweep(clock);
  const res = await api(`/api/v1/view/${s.viewToken}`);
  assert.equal(res.status, 404);
});

test('owner can delete a session immediately', async () => {
  const s = await createSession();
  const res = await api(`/api/v1/sessions/${s.id}`, { method: 'DELETE', key: s.ownerKey });
  assert.equal(res.status, 204);
  assert.equal((await api(`/api/v1/view/${s.viewToken}`)).status, 404);
});

test('serves the viewer page and bundled Leaflet', async () => {
  const s = await createSession();
  let res = await api(`/t/${s.viewToken}`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /Live location/);
  assert.match(res.headers.get('content-security-policy'), /script-src 'self'/);
  res = await api('/vendor/leaflet/leaflet.js');
  assert.equal(res.status, 200);
});

test('invalid view tokens are 404', async () => {
  assert.equal((await api('/api/v1/view/short')).status, 404);
  assert.equal((await api('/api/v1/view/AAAAAAAAAAAAAAAAAAAAAAAA')).status, 404);
});
