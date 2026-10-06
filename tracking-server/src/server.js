const { loadConfig } = require('./config');
const { createApp } = require('./app');
const { MemoryStore } = require('./store/memoryStore');
const { MongoStore } = require('./store/mongoStore');

async function main() {
  const config = loadConfig();
  let store;
  if (config.mongoUri) {
    store = new MongoStore({ uri: config.mongoUri, maxPointsPerSession: config.maxPointsPerSession });
    await store.connect();
  } else {
    store = new MemoryStore({ maxPointsPerSession: config.maxPointsPerSession });
  }

  const app = createApp({ store, config });
  const server = app.listen(config.port, () => {
    console.log(`[tracking] listening on :${config.port} (store: ${store.kind})`);
  });

  const shutdown = () => server.close(() => store.close().finally(() => process.exit(0)));
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('[tracking] failed to start:', err.message);
  process.exit(1);
});
