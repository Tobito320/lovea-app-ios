import { test } from "node:test";
import assert from "node:assert/strict";
import { apnsJwt, apnsPayload, push } from "./push.js";

async function testEnv() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", pair.privateKey);
  const b64 = Buffer.from(pkcs8).toString("base64");
  const pem = `-----BEGIN PRIVATE KEY-----\n${b64.match(/.{1,64}/g).join("\n")}\n-----END PRIVATE KEY-----\n`;
  return {
    env: { APNS_KEY_P8: pem, APNS_KEY_ID: "TESTKEY123", APNS_TEAM_ID: "TESTTEAM99" },
    publicKey: pair.publicKey,
  };
}

function decodeJwtPart(part) {
  return JSON.parse(Buffer.from(part.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString());
}

test("apnsJwt: gültiger, prüfbarer ES256-Header und -Signatur, 1h gecacht", async () => {
  const { env, publicKey } = await testEnv();
  const jwt = await apnsJwt(env, 1_000_000);
  const [h, c, s] = jwt.split(".");
  assert.deepEqual(decodeJwtPart(h), { alg: "ES256", kid: "TESTKEY123" });
  assert.deepEqual(decodeJwtPart(c), { iss: "TESTTEAM99", iat: 1_000 });

  const sig = Uint8Array.from(Buffer.from(s.replace(/-/g, "+").replace(/_/g, "/"), "base64"));
  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    sig,
    new TextEncoder().encode(`${h}.${c}`)
  );
  assert.equal(ok, true);

  // Innerhalb einer Stunde: gleicher Token aus dem Cache.
  const jwt2 = await apnsJwt(env, 1_000_000 + 60_000);
  assert.equal(jwt2, jwt);

  // Nach einer Stunde: neuer Token (andere iat).
  const jwt3 = await apnsJwt(env, 1_000_000 + 3_600_001);
  assert.notEqual(jwt3, jwt);
});

test("apnsPayload: laut mit Ton, leise ohne Ton, still ohne Text", () => {
  const laut = apnsPayload({ stufe: "laut", titel: "Lovea", text: "Annika denkt gerade an dich", ton: "herzschlag.caf" });
  assert.equal(laut.aps["interruption-level"], "active");
  assert.equal(laut.aps.sound, "herzschlag.caf");
  assert.equal(laut.aps.alert.body, "Annika denkt gerade an dich");
  assert.equal(laut.aps["thread-id"], "wir");

  const leise = apnsPayload({ stufe: "leise", titel: "Lovea", text: "Annika hat reagiert" });
  assert.equal(leise.aps["interruption-level"], "passive");
  assert.equal(leise.aps.sound, undefined);

  const still = apnsPayload({ stufe: "still" });
  assert.deepEqual(still, { aps: { "content-available": 1 } });
});

// Z-32.1: `daten` landet oben neben `aps` (die App liest `userInfo["nachrichtId"]`).
test("apnsPayload: daten stehen oben neben aps", () => {
  const payload = apnsPayload({ stufe: "laut", titel: "Lovea", text: "Annika: hi", daten: { art: "nachricht.neu", nachrichtId: "m1" } });
  assert.deepEqual(payload, {
    art: "nachricht.neu",
    nachrichtId: "m1",
    aps: { alert: { title: "Lovea", body: "Annika: hi" }, "interruption-level": "active", "thread-id": "wir" },
  });
});

test("push: schickt an api.push.apple.com mit apns-topic und passendem push-type", async () => {
  const { env } = await testEnv();
  const calls = [];
  const fakeFetch = async (url, init) => {
    calls.push({ url, init });
    return new Response(null, { status: 200 });
  };

  await push(env, "devicetoken123", { stufe: "laut", titel: "Lovea", text: "hi" }, fakeFetch);
  const laut = calls[0];
  assert.equal(laut.url, "https://api.push.apple.com/3/device/devicetoken123");
  assert.equal(laut.init.headers["apns-topic"], "com.onlyus.lovea");
  assert.equal(laut.init.headers["apns-push-type"], "alert");
  assert.match(laut.init.headers.authorization, /^bearer /);

  await push(env, "devicetoken123", { stufe: "still" }, fakeFetch);
  const still = calls[1];
  assert.equal(still.init.headers["apns-push-type"], "background");
  assert.deepEqual(JSON.parse(still.init.body), { aps: { "content-available": 1 } });
});

test("push: 410 wird als expired gemeldet", async () => {
  const { env } = await testEnv();
  const fakeFetch = async () => new Response(null, { status: 410 });
  const res = await push(env, "totes-token", { stufe: "leise", titel: "Lovea", text: "x" }, fakeFetch);
  assert.equal(res.expired, true);
});
