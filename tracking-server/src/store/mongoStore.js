// MongoDB-backed session store.  TTL indexes on `purgeAt` remove sessions
// and their points automatically once they are no longer viewable.
const mongoose = require('mongoose');

const SessionSchema = new mongoose.Schema(
  {
    _id: { type: String },
    viewToken: { type: String, required: true, unique: true },
    ownerKeyHash: { type: String, required: true },
    name: { type: String, required: true, maxlength: 60 },
    reason: { type: String, enum: ['sos', 'journey', 'live'], required: true },
    status: { type: String, enum: ['active', 'ended'], required: true },
    createdAt: { type: Date, required: true },
    updatedAt: { type: Date, required: true },
    expiresAt: { type: Date, required: true },
    purgeAt: { type: Date, required: true },
    note: { type: String, maxlength: 140 },
  },
  { versionKey: false }
);
SessionSchema.index({ purgeAt: 1 }, { expireAfterSeconds: 0 });

const PointSchema = new mongoose.Schema(
  {
    sessionId: { type: String, required: true },
    lat: Number,
    lng: Number,
    accuracy: Number,
    speed: Number,
    heading: Number,
    battery: Number,
    t: { type: Number, required: true },
    purgeAt: { type: Date, required: true },
  },
  { versionKey: false }
);
PointSchema.index({ sessionId: 1, t: -1 });
PointSchema.index({ purgeAt: 1 }, { expireAfterSeconds: 0 });

const toSession = (doc) => {
  if (!doc) return null;
  const { _id, ...rest } = doc;
  return { id: _id, ...rest };
};

const toPoint = ({ lat, lng, accuracy, speed, heading, battery, t }) =>
  Object.fromEntries(
    Object.entries({ lat, lng, accuracy, speed, heading, battery, t }).filter(([, v]) => v !== undefined && v !== null)
  );

class MongoStore {
  constructor({ uri, maxPointsPerSession }) {
    this.kind = 'mongo';
    this.uri = uri;
    this.maxPoints = maxPointsPerSession;
    this.connection = mongoose.createConnection();
    this.Session = this.connection.model('TrackingSession', SessionSchema);
    this.Point = this.connection.model('TrackingPoint', PointSchema);
  }

  async connect() {
    await this.connection.openUri(this.uri, { serverSelectionTimeoutMS: 5000 });
    await Promise.all([this.Session.syncIndexes(), this.Point.syncIndexes()]);
  }

  async create(session) {
    const { id, ...rest } = session;
    await this.Session.create({ _id: id, ...rest });
    return { ...session };
  }

  async get(id) {
    return toSession(await this.Session.findById(id).lean());
  }

  async getByViewToken(viewToken) {
    return toSession(await this.Session.findOne({ viewToken }).lean());
  }

  async update(id, patch) {
    const doc = await this.Session.findByIdAndUpdate(id, patch, { new: true }).lean();
    if (doc && patch.purgeAt) {
      await this.Point.updateMany({ sessionId: id }, { purgeAt: patch.purgeAt });
    }
    return toSession(doc);
  }

  async appendPoints(id, points) {
    const session = await this.Session.findById(id, { purgeAt: 1 }).lean();
    if (!session) return 0;
    await this.Point.insertMany(points.map((p) => ({ ...p, sessionId: id, purgeAt: session.purgeAt })));
    // Trim to the most recent maxPoints.
    const overflow = await this.Point.find({ sessionId: id }, { _id: 1 })
      .sort({ t: -1 })
      .skip(this.maxPoints)
      .lean();
    if (overflow.length) await this.Point.deleteMany({ _id: { $in: overflow.map((p) => p._id) } });
    return points.length;
  }

  async listPoints(id, limit) {
    const docs = await this.Point.find({ sessionId: id }).sort({ t: -1 }).limit(limit).lean();
    return docs.reverse().map(toPoint);
  }

  async remove(id) {
    const result = await this.Session.deleteOne({ _id: id });
    await this.Point.deleteMany({ sessionId: id });
    return result.deletedCount > 0;
  }

  async close() {
    await this.connection.close();
  }
}

module.exports = { MongoStore };
