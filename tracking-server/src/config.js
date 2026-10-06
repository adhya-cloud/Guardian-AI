require('dotenv').config();

function loadConfig(env = process.env) {
  return {
    port: Number(env.PORT || 4000),
    production: env.NODE_ENV === 'production',
    // Empty MONGO_URI selects the in-memory store (single instance only).
    mongoUri: env.MONGO_URI || '',
    // Public base URL used in share links, e.g. https://track.example.org.
    // When empty, links are built from the incoming request's host.
    publicUrl: (env.PUBLIC_URL || '').replace(/\/+$/, ''),
    trustProxyHops: Number(env.TRUST_PROXY_HOPS || 0),
    maxSessionMinutes: 12 * 60,
    maxPointsPerSession: 1000,
    // Ended/expired sessions stay viewable (as "ended") for this long.
    retainAfterEndMs: 60 * 60 * 1000,
  };
}

module.exports = { loadConfig };
