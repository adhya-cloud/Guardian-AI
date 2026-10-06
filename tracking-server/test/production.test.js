// Production mode: HTTPS is enforced, and links use the proxy's public host.
const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const { createApp } = require('../src/app');
const { MemoryStore } = require('../src/store/memoryStore');
const { loadConfig } = require('../src/config');

let server;
let base;
const store = new MemoryStore({ maxPointsPerSession: 10 });

before(async () => {
  const config = loadConfig({ NODE_ENV: 'production', TRUST_PROXY_HOPS: '1' });
  const app = createApp({ store, config });
  await new Promise((resolve) => {
    server = app.listen(0, resolve);
  });
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await store.close();
  await new Promise((resolve) => server.close(resolve));
});

const create = (headers = {}) =>
  fetch(`${base}/api/v1/sessions`, {
    method: 'POST',
    redirect: 'manual',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify({ name: 'Asha', reason: 'live', durationMinutes: 15 }),
  });

test('rejects plain-HTTP API calls', async () => {
  const res = await create();
  assert.equal(res.status, 426);
});

test('redirects plain-HTTP page views to HTTPS', async () => {
  const res = await fetch(`${base}/health`, { redirect: 'manual' });
  assert.equal(res.status, 301);
  assert.match(res.headers.get('location'), /^https:\/\//);
});

test('works behind an HTTPS proxy and builds https links', async () => {
  // (fetch cannot override Host; real proxies forward the public host.)
  const res = await create({ 'x-forwarded-proto': 'https' });
  assert.equal(res.status, 201);
  const body = await res.json();
  assert.match(body.viewUrl, /^https:\/\/[^/]+\/t\/[A-Za-z0-9_-]+$/);
});
