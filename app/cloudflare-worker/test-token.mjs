// Byte-for-byte check: our Worker token builder vs the official Agora
// Node builder (AgoraIO/Tools, vendored under vendor/). Run with:
//   cp ../token-worker.js ./token-worker.mjs && node test-token.mjs
import { createRequire } from "module";
import { buildRtcToken } from "./token-worker.mjs";

const require = createRequire(import.meta.url);
const { AccessToken, priviledges } = require("./vendor/AccessToken.js");

const APP_ID = "34565f71f84741db9505dc6650ba521b"; // format only; test cert is fake
const APP_CERT = "0123456789abcdef0123456789abcdef";
const NOW = 1794117600; // fixed, so both sides agree
const SALT = 0x12345678;

function official(channel, uid) {
  const t = new AccessToken(APP_ID, APP_CERT, channel, uid);
  t.salt = SALT;
  t.ts = NOW + 24 * 3600;
  const exp = NOW + 3600;
  t.addPriviledge(priviledges.kJoinChannel, exp);
  t.addPriviledge(priviledges.kPublishAudioStream, exp);
  t.addPriviledge(priviledges.kPublishVideoStream, exp);
  t.addPriviledge(priviledges.kPublishDataStream, exp);
  return t.build();
}

let failures = 0;
for (const [channel, uid] of [
  ["xv57PQXXVPcZXQsAFiAm", 12345],
  ["test-channel-1", 0],
  ["delivery-9180", 4294967295],
]) {
  const expected = official(channel, uid);
  const actual = await buildRtcToken(APP_ID, APP_CERT, channel, uid, {
    salt: SALT,
    nowSec: NOW,
    ttlSec: 3600,
  });
  const ok = expected === actual;
  if (!ok) failures++;
  console.log(`${ok ? "PASS" : "FAIL"} channel=${channel} uid=${uid}`);
  if (!ok) {
    console.log("  official:", expected);
    console.log("  worker:  ", actual);
  }
}
console.log(failures === 0 ? "ALL TOKEN TESTS PASSED" : `${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
