import { test } from "node:test";
import assert from "node:assert/strict";
import { handleFetch, pruefeAuth } from "./index.js";

function env(extra = {}) {
  return { LOVEA_APP_KEY: "geheim-test-schluessel", ...extra };
}

// Z-1.1: falscher Schlüssel -> 401.
test("handleFetch: falscher Schlüssel gibt 401", async () => {
  const req = new Request("https://x/raum?seit=0", {
    headers: { "X-Lovea-Key": "falsch", "X-Lovea-Person": "ahmed" },
  });
  const res = await handleFetch(req, env());
  assert.equal(res.status, 401);
});

test("handleFetch: fehlender Schlüssel gibt 401", async () => {
  const req = new Request("https://x/raum", { headers: { "X-Lovea-Person": "ahmed" } });
  const res = await handleFetch(req, env());
  assert.equal(res.status, 401);
});

test("handleFetch: unbekannte Person gibt 401", async () => {
  const req = new Request("https://x/raum", {
    headers: { "X-Lovea-Key": "geheim-test-schluessel", "X-Lovea-Person": "sonstwer" },
  });
  const res = await handleFetch(req, env());
  assert.equal(res.status, 401);
});

test("handleFetch: richtiger Schlüssel leitet an RAUM weiter, mit locationHint weur", async () => {
  let weitergeleiteteRequest = null;
  let hint = null;
  const e = env({
    RAUM: {
      idFromName: (name) => `id-${name}`,
      get: (id, opts) => {
        hint = opts;
        return { fetch: async (r) => { weitergeleiteteRequest = r; return new Response("ok"); } };
      },
    },
  });
  const req = new Request("https://x/ops", { method: "POST", headers: { "X-Lovea-Key": "geheim-test-schluessel", "X-Lovea-Person": "annika" } });
  const res = await handleFetch(req, e);
  assert.equal(res.status, 200);
  assert.equal(weitergeleiteteRequest, req);
  assert.deepEqual(hint, { locationHint: "weur" });
});

test("handleFetch: /raum akzeptiert Query-Fallback ?key=&person= (für pruefen.mjs)", async () => {
  const req = new Request("https://x/raum?seit=0&key=geheim-test-schluessel&person=ahmed");
  const person = pruefeAuth(req, env(), new URL(req.url));
  assert.equal(person, "ahmed");
});

test("handleFetch: /gif ohne KLIPY_KEY -> 503 nicht eingerichtet", async () => {
  const req = new Request("https://x/gif?q=katze", { headers: { "X-Lovea-Key": "geheim-test-schluessel", "X-Lovea-Person": "ahmed" } });
  const res = await handleFetch(req, env());
  assert.equal(res.status, 503);
  const body = await res.json();
  assert.equal(body.fehler, "nicht eingerichtet");
});
