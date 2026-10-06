// Integration test for the MongoDB store.  Skipped unless MONGO_TEST_URI is
// set, e.g.  MONGO_TEST_URI=mongodb://localhost:27017/guardian_tracking_test npm test
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { MongoStore } = require('../src/store/mongoStore');

const uri = process.env.MONGO_TEST_URI;

test('mongo store: create, append, trim, update, remove', { skip: !uri && 'MONGO_TEST_URI not set' }, async () => {
  const store = new MongoStore({ uri, maxPointsPerSession: 3 });
  await store.connect();
  try {
    await store.Session.deleteMany({});
    await store.Point.deleteMany({});
    const now = Date.now();
    const session = {
      id: 'sess-1',
      viewToken: 'view-token-abcdefghijkl',
      ownerKeyHash: 'hash',
      name: 'Asha',
      reason: 'live',
      status: 'active',
      createdAt: new Date(now),
      updatedAt: new Date(now),
      expiresAt: new Date(now + 60_000),
      purgeAt: new Date(now + 3_600_000),
    };
    await store.create(session);
    assert.equal((await store.getByViewToken(session.viewToken)).id, 'sess-1');

    await store.appendPoints('sess-1', [1, 2, 3, 4, 5].map((i) => ({ lat: i, lng: 70, t: now + i })));
    const points = await store.listPoints('sess-1', 10);
    assert.deepEqual(points.map((p) => p.lat), [3, 4, 5], 'keeps the newest, oldest first');

    const updated = await store.update('sess-1', { reason: 'sos', status: 'ended' });
    assert.equal(updated.reason, 'sos');
    assert.equal(updated.status, 'ended');

    assert.equal(await store.remove('sess-1'), true);
    assert.equal(await store.get('sess-1'), null);
    assert.equal((await store.listPoints('sess-1', 10)).length, 0);
  } finally {
    await store.close();
  }
});
