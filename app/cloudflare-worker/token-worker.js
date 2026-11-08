// Wasl Agora RTC token server — Cloudflare Worker (free tier).
//
// Why this exists: Agora creates every new project in token mode and the
// console offers no App-ID-only choice at creation, and a project's mode
// cannot be changed afterwards. The Wasl app therefore cannot join a call
// with just the App ID — it needs a fresh RTC token per call. This Worker
// mints one. The App Certificate never leaves Cloudflare: it is stored as
// an encrypted Worker secret (AGORA_APP_CERTIFICATE), never in this code,
// never in the app.
//
// Token algorithm: Agora "006" RTC token, mirrored exactly from the
// official builder (AgoraIO/Tools, DynamicKey/AgoraDynamicKey/nodejs,
// src/AccessToken.js + src/RtcTokenBuilder.js — vendored under vendor/ for
// reference). Verified byte-for-byte against the official Node builder
// (see test-token.mjs).
//
// Env bindings (set in the Cloudflare dashboard, Worker -> Settings ->
// Variables): AGORA_APP_ID (plain text variable), AGORA_APP_CERTIFICATE
// (secret / encrypted variable).
//
// Endpoints:
//   GET /token?channel=<deliveryId>&uid=<number>  -> {"token","appId","channel","uid","expiresAt"}
//   GET /                                         -> health check ("ok")

const VERSION = "006";
const TOKEN_TTL_SECONDS = 3600; // privileges expire 1h after issue
const TOKEN_TS_OFFSET = 24 * 3600; // official builder: token ts = now + 24h

// ---- CRC-32 (IEEE, same as the `crc-32` npm package's crc32.str) ----
const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(str) {
  const bytes = new TextEncoder().encode(str);
  let crc = 0xffffffff;
  for (const b of bytes) crc = CRC_TABLE[(crc ^ b) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

// ---- little-endian packing (mirrors AccessToken.js ByteBuf) ----
function u16(v) {
  const b = new Uint8Array(2);
  new DataView(b.buffer).setUint16(0, v, true);
  return b;
}
function u32(v) {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setUint32(0, v >>> 0, true);
  return b;
}
function concat(...parts) {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let off = 0;
  for (const p of parts) {
    out.set(p, off);
    off += p.length;
  }
  return out;
}
function putString(bytes) {
  return concat(u16(bytes.length), bytes);
}
function b64encode(bytes) {
  let s = "";
  const CHUNK = 0x8000;
  for (let i = 0; i < bytes.length; i += CHUNK) {
    s += String.fromCharCode.apply(null, bytes.subarray(i, i + CHUNK));
  }
  return btoa(s);
}

// ---- RTC token (version 006), publisher role ----
// opts { salt, nowSec, ttlSec } exist only so the local test can pin them.
export async function buildRtcToken(appId, appCertificate, channel, uid, opts = {}) {
  const now = opts.nowSec ?? Math.floor(Date.now() / 1000);
  const ts = now + TOKEN_TS_OFFSET;
  const privilegeExpiredTs = now + (opts.ttlSec ?? TOKEN_TTL_SECONDS);
  const salt = opts.salt ?? crypto.getRandomValues(new Uint32Array(1))[0];
  const uidStr = uid === 0 ? "" : String(uid);
  const enc = new TextEncoder();

  // Message m: salt, ts, privilege map {1,2,3,4: privilegeExpiredTs}
  const m = concat(
    u32(salt),
    u32(ts),
    u16(4),
    u16(1),
    u32(privilegeExpiredTs),
    u16(2),
    u32(privilegeExpiredTs),
    u16(3),
    u32(privilegeExpiredTs),
    u16(4),
    u32(privilegeExpiredTs),
  );

  const toSign = concat(enc.encode(appId), enc.encode(channel), enc.encode(uidStr), m);
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(appCertificate),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, toSign));

  const content = concat(
    putString(signature),
    u32(crc32(channel)),
    u32(crc32(uidStr)),
    putString(m),
  );
  return VERSION + appId + b64encode(content);
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/") {
      return new Response("wasl-agora-token ok", { status: 200 });
    }

    if (url.pathname !== "/token") {
      return json({ error: "not found" }, 404);
    }

    const channel = url.searchParams.get("channel") || "";
    const uidRaw = url.searchParams.get("uid") || "0";
    const uid = Number(uidRaw);

    if (!channel || channel.length > 64 || !/^[A-Za-z0-9 _!#$%&()+\-:;<=>.?@[\]^_{|}~,\s]+$/.test(channel)) {
      return json({ error: "invalid channel" }, 400);
    }
    if (!Number.isInteger(uid) || uid < 0 || uid > 4294967295) {
      return json({ error: "invalid uid" }, 400);
    }
    if (!env.AGORA_APP_ID || !env.AGORA_APP_CERTIFICATE) {
      return json({ error: "server not configured" }, 500);
    }

    const now = Math.floor(Date.now() / 1000);
    const token = await buildRtcToken(env.AGORA_APP_ID, env.AGORA_APP_CERTIFICATE, channel, uid);
    return json({
      token,
      appId: env.AGORA_APP_ID,
      channel,
      uid,
      expiresAt: now + TOKEN_TTL_SECONDS,
    });
  },
};
