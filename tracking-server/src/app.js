const path = require('path');
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { randomToken, hashKey, ownerKeyMatches, TOKEN_PATTERN } = require('./tokens');

const REASONS = ['sos', 'journey', 'live'];
const MAX_POINTS_PER_REQUEST = 100;
const VIEW_POINT_LIMIT = 300;

class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

const isNum = (v) => typeof v === 'number' && Number.isFinite(v);

function parseCreate(body) {
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (!name || name.length > 60) throw new HttpError(400, 'INVALID_NAME', 'name must be 1-60 characters');
  if (!REASONS.includes(body.reason)) throw new HttpError(400, 'INVALID_REASON', `reason must be one of ${REASONS.join(', ')}`);
  const minutes = body.durationMinutes;
  if (!Number.isInteger(minutes) || minutes < 5) throw new HttpError(400, 'INVALID_DURATION', 'durationMinutes must be an integer >= 5');
  const note = typeof body.note === 'string' ? body.note.trim().slice(0, 140) : undefined;
  return { name, reason: body.reason, minutes, note };
}

function parsePoints(body, now) {
  if (!Array.isArray(body.points) || body.points.length === 0) {
    throw new HttpError(400, 'INVALID_POINTS', 'points must be a non-empty array');
  }
  if (body.points.length > MAX_POINTS_PER_REQUEST) {
    throw new HttpError(400, 'TOO_MANY_POINTS', `at most ${MAX_POINTS_PER_REQUEST} points per request`);
  }
  return body.points.map((p, i) => {
    const bad = (msg) => new HttpError(400, 'INVALID_POINT', `points[${i}]: ${msg}`);
    if (!p || typeof p !== 'object') throw bad('must be an object');
    if (!isNum(p.lat) || p.lat < -90 || p.lat > 90) throw bad('lat must be between -90 and 90');
    if (!isNum(p.lng) || p.lng < -180 || p.lng > 180) throw bad('lng must be between -180 and 180');
    const t = isNum(p.t) ? p.t : Date.parse(p.t);
    if (!Number.isFinite(t) || t > now + 5 * 60 * 1000 || t < now - 24 * 60 * 60 * 1000) {
      throw bad('t must be a timestamp within the last 24 hours');
    }
    const point = { lat: p.lat, lng: p.lng, t: Math.round(t) };
    if (isNum(p.accuracy) && p.accuracy >= 0) point.accuracy = Math.min(p.accuracy, 100000);
    if (isNum(p.speed) && p.speed >= 0) point.speed = p.speed;
    if (isNum(p.heading) && p.heading >= 0 && p.heading <= 360) point.heading = p.heading;
    if (Number.isInteger(p.battery) && p.battery >= 0 && p.battery <= 100) point.battery = p.battery;
    return point;
  });
}

function effectiveStatus(session, now) {
  if (session.status === 'ended') return 'ended';
  return session.expiresAt.getTime() <= now ? 'expired' : 'active';
}

function publicView(session, points, now) {
  return {
    name: session.name,
    reason: session.reason,
    status: effectiveStatus(session, now),
    note: session.note || null,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    expiresAt: session.expiresAt,
    points,
  };
}

function createApp({ store, config, now = () => Date.now() }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxyHops);

  if (config.production) {
    app.use((req, res, next) => {
      if (req.secure) return next();
      if (req.method === 'GET') return res.redirect(301, `https://${req.get('host')}${req.originalUrl}`);
      return res.status(426).json({ error: { code: 'HTTPS_REQUIRED', message: 'Use HTTPS.' } });
    });
  }

  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'"],
          imgSrc: ["'self'", 'data:', 'https://*.tile.openstreetmap.org', 'https://tile.openstreetmap.org'],
          connectSrc: ["'self'"],
          upgradeInsecureRequests: config.production ? [] : null,
        },
      },
      referrerPolicy: { policy: 'no-referrer' },
    })
  );
  app.use(express.json({ limit: '64kb' }));

  const limiter = (windowMs, limit) =>
    rateLimit({ windowMs, limit, standardHeaders: 'draft-7', legacyHeaders: false,
      message: { error: { code: 'RATE_LIMITED', message: 'Too many requests, slow down.' } } });

  const baseUrl = (req) => config.publicUrl || `${req.protocol}://${req.get('host')}`;

  // Loads the session named in the URL and checks the owner key.
  const requireOwner = async (req) => {
    const session = await store.get(req.params.id);
    const auth = req.get('authorization') || '';
    const key = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (!session || !ownerKeyMatches(key, session.ownerKeyHash)) {
      throw new HttpError(404, 'NOT_FOUND', 'Session not found');
    }
    return session;
  };

  const wrap = (fn) => (req, res, next) => fn(req, res).catch(next);

  app.get('/health', (_req, res) => res.json({ status: 'ok', store: store.kind }));

  // ── Owner API (the phone) ──────────────────────────────────────────────
  app.post('/api/v1/sessions', limiter(60 * 60 * 1000, 30), wrap(async (req, res) => {
    const input = parseCreate(req.body || {});
    const t = now();
    const minutes = Math.min(input.minutes, config.maxSessionMinutes);
    const ownerKey = randomToken(32);
    const expiresAt = new Date(t + minutes * 60 * 1000);
    const session = await store.create({
      id: randomToken(12),
      viewToken: randomToken(18),
      ownerKeyHash: hashKey(ownerKey),
      name: input.name,
      reason: input.reason,
      note: input.note,
      status: 'active',
      createdAt: new Date(t),
      updatedAt: new Date(t),
      expiresAt,
      purgeAt: new Date(expiresAt.getTime() + config.retainAfterEndMs),
    });
    res.status(201).json({
      id: session.id,
      ownerKey,
      viewToken: session.viewToken,
      viewUrl: `${baseUrl(req)}/t/${session.viewToken}`,
      expiresAt: session.expiresAt,
    });
  }));

  app.post('/api/v1/sessions/:id/points', limiter(10 * 60 * 1000, 1200), wrap(async (req, res) => {
    const session = await requireOwner(req);
    const t = now();
    if (effectiveStatus(session, t) !== 'active') {
      throw new HttpError(409, 'SESSION_CLOSED', 'Session has ended or expired');
    }
    const points = parsePoints(req.body || {}, t);
    const accepted = await store.appendPoints(session.id, points);
    await store.update(session.id, { updatedAt: new Date(t) });
    res.status(202).json({ accepted });
  }));

  app.patch('/api/v1/sessions/:id', limiter(10 * 60 * 1000, 300), wrap(async (req, res) => {
    const session = await requireOwner(req);
    const body = req.body || {};
    const t = now();
    const patch = { updatedAt: new Date(t) };
    if (body.reason !== undefined) {
      if (!REASONS.includes(body.reason)) throw new HttpError(400, 'INVALID_REASON', 'invalid reason');
      patch.reason = body.reason;
    }
    if (body.note !== undefined) patch.note = String(body.note).trim().slice(0, 140);
    if (body.extendMinutes !== undefined) {
      if (!Number.isInteger(body.extendMinutes) || body.extendMinutes < 1) {
        throw new HttpError(400, 'INVALID_EXTEND', 'extendMinutes must be a positive integer');
      }
      const base = Math.max(session.expiresAt.getTime(), t);
      const cap = session.createdAt.getTime() + config.maxSessionMinutes * 60 * 1000;
      patch.expiresAt = new Date(Math.min(base + body.extendMinutes * 60 * 1000, cap));
      patch.purgeAt = new Date(patch.expiresAt.getTime() + config.retainAfterEndMs);
    }
    if (body.status !== undefined) {
      if (body.status !== 'ended') throw new HttpError(400, 'INVALID_STATUS', 'status can only be set to "ended"');
      patch.status = 'ended';
      patch.expiresAt = new Date(Math.min(session.expiresAt.getTime(), t));
      patch.purgeAt = new Date(t + config.retainAfterEndMs);
    }
    const updated = await store.update(session.id, patch);
    res.json(publicView(updated, [], t));
  }));

  app.delete('/api/v1/sessions/:id', limiter(10 * 60 * 1000, 300), wrap(async (req, res) => {
    const session = await requireOwner(req);
    await store.remove(session.id);
    res.status(204).end();
  }));

  // ── Viewer (trusted contacts) ──────────────────────────────────────────
  app.get('/api/v1/view/:token', limiter(60 * 1000, 120), wrap(async (req, res) => {
    const { token } = req.params;
    const session = TOKEN_PATTERN.test(token) ? await store.getByViewToken(token) : null;
    if (!session) throw new HttpError(404, 'NOT_FOUND', 'This link is invalid or has expired.');
    const points = await store.listPoints(session.id, VIEW_POINT_LIMIT);
    res.set('Cache-Control', 'no-store');
    res.json(publicView(session, points, now()));
  }));

  const publicDir = path.join(__dirname, '..', 'public');
  const leafletDir = path.dirname(require.resolve('leaflet/dist/leaflet.js'));
  app.use('/vendor/leaflet', express.static(leafletDir, { maxAge: '7d' }));
  app.use('/static', express.static(publicDir, { maxAge: '1h', index: false }));

  app.get('/t/:token', (req, res) => {
    res.set('X-Robots-Tag', 'noindex, nofollow');
    res.set('Cache-Control', 'no-store');
    res.sendFile(path.join(publicDir, 'viewer.html'));
  });

  app.get('/', (_req, res) => res.type('text').send('Guardian tracking server. Open a shared /t/<link> to view a live location.'));

  app.use((_req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Not found' } }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err.type === 'entity.parse.failed') err = new HttpError(400, 'INVALID_JSON', 'Body must be valid JSON');
    const status = err.status || 500;
    if (status >= 500) console.error('[error]', err);
    res.status(status).json({
      error: { code: err.code || 'INTERNAL_ERROR', message: status >= 500 ? 'Something went wrong.' : err.message },
    });
  });

  return app;
}

module.exports = { createApp };
