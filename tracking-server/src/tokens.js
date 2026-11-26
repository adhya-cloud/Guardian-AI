const crypto = require('crypto');

const randomToken = (bytes) => crypto.randomBytes(bytes).toString('base64url');

const hashKey = (key) => crypto.createHash('sha256').update(String(key)).digest('hex');

/** Constant-time comparison of a presented owner key against its stored hash. */
function ownerKeyMatches(presentedKey, storedHash) {
  if (!presentedKey || !storedHash) return false;
  const a = Buffer.from(hashKey(presentedKey), 'hex');
  const b = Buffer.from(storedHash, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

module.exports = { randomToken, hashKey, ownerKeyMatches, TOKEN_PATTERN };
