// In-memory session store.  Suitable for a single server instance: data is
// lost on restart, which is acceptable for short-lived live-location shares.

class MemoryStore {
  constructor({ maxPointsPerSession }) {
    this.kind = 'memory';
    this.maxPoints = maxPointsPerSession;
    this.sessions = new Map(); // id -> session
    this.byViewToken = new Map(); // viewToken -> id
    this.points = new Map(); // id -> point[]
    this.sweeper = setInterval(() => this.sweep(), 60 * 1000);
    this.sweeper.unref();
  }

  async create(session) {
    this.sessions.set(session.id, { ...session });
    this.byViewToken.set(session.viewToken, session.id);
    this.points.set(session.id, []);
    return { ...session };
  }

  async get(id) {
    const session = this.sessions.get(id);
    return session ? { ...session } : null;
  }

  async getByViewToken(viewToken) {
    const id = this.byViewToken.get(viewToken);
    return id ? this.get(id) : null;
  }

  async update(id, patch) {
    const session = this.sessions.get(id);
    if (!session) return null;
    Object.assign(session, patch);
    return { ...session };
  }

  async appendPoints(id, points) {
    const list = this.points.get(id);
    if (!list) return 0;
    list.push(...points);
    list.sort((a, b) => a.t - b.t);
    if (list.length > this.maxPoints) list.splice(0, list.length - this.maxPoints);
    return points.length;
  }

  async listPoints(id, limit) {
    const list = this.points.get(id) || [];
    return list.slice(-limit).map((p) => ({ ...p }));
  }

  async remove(id) {
    const session = this.sessions.get(id);
    if (!session) return false;
    this.sessions.delete(id);
    this.byViewToken.delete(session.viewToken);
    this.points.delete(id);
    return true;
  }

  sweep(now = Date.now()) {
    for (const session of this.sessions.values()) {
      if (session.purgeAt.getTime() <= now) this.remove(session.id);
    }
  }

  async close() {
    clearInterval(this.sweeper);
  }
}

module.exports = { MemoryStore };
