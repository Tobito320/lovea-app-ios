// Integrationsartiger Test für raum.js selbst: eine kleine, in-memory
// Nachbildung der Hibernation-API (ctx.acceptWebSocket/getWebSockets/getTags,
// ctx.storage.sql, ctx.storage.setAlarm), damit die echte Verdrahtung ohne
// die Workers-Runtime geprüft werden kann.
import { test } from "node:test";
import assert from "node:assert/strict";
import { Raum } from "./raum.js";
import { fakeSql } from "./fake-sql.js";

class FakeWs {
  constructor() {
    this.gesendet = [];
  }
  send(data) {
    this.gesendet.push(JSON.parse(data));
  }
}

function fakeCtx() {
  const sql = fakeSql();
  const sockets = []; // {ws, tags}
  const alarms = { zeitpunkt: null, gesetzt: [] };
  return {
    storage: {
      sql,
      setAlarm: async (ms) => {
        alarms.zeitpunkt = ms;
        alarms.gesetzt.push(ms);
      },
      deleteAlarm: async () => {
        alarms.zeitpunkt = null;
      },
    },
    blockConcurrencyWhile: async (fn) => fn(),
    acceptWebSocket: (ws, tags) => sockets.push({ ws, tags }),
    getWebSockets: (tag) => sockets.filter((s) => !tag || s.tags.includes(tag)).map((s) => s.ws),
    getTags: (ws) => sockets.find((s) => s.ws === ws)?.tags ?? [],
    // Reale Hibernation-API entfernt einen geschlossenen Socket automatisch
    // aus getWebSockets(); das bildet die Fake hier für Tests nach.
    _trennen: (ws) => {
      const i = sockets.findIndex((s) => s.ws === ws);
      if (i !== -1) sockets.splice(i, 1);
    },
    _alarms: alarms,
  };
}

function fakeEnv() {
  return { APNS_KEY_ID: "k", APNS_TEAM_ID: "t", APNS_KEY_P8: null }; // Push wird in diesen Tests nicht ausgelöst (niemand hat ein Token)
}

function raumMitVerbindung(personen = []) {
  const ctx = fakeCtx();
  const raum = new Raum(ctx, fakeEnv());
  const websockets = {};
  for (const person of personen) {
    const ws = new FakeWs();
    ctx.acceptWebSocket(ws, [person]);
    websockets[person] = ws;
  }
  return { raum, ctx, websockets };
}

test("op über WebSocket: Echo an Absender, Broadcast an Partner, seq stabil bei Wiederholung", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  const op = { id: "m1", art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: { text: "hi" } };

  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "op", op }));
  assert.equal(websockets.ahmed.gesendet.at(-1).ops[0].seq, 1);
  assert.equal(websockets.annika.gesendet.at(-1).ops[0].seq, 1);

  // Wiederholung (z. B. nach Funkloch): gleiche seq, kein zweiter Eintrag beim Partner.
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "op", op }));
  assert.equal(websockets.ahmed.gesendet.at(-1).ops[0].seq, 1);
  assert.equal(websockets.annika.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.id === "m1").length, 1);
});

test("nachholen über offenen Socket liefert Seite wie beim Verbinden", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed"]);
  for (let i = 0; i < 3; i++) {
    await raum.webSocketMessage(
      websockets.ahmed,
      JSON.stringify({ t: "op", op: { id: `x${i}`, art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: {} } })
    );
  }
  websockets.ahmed.gesendet = [];
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "nachholen", seit: 0 }));
  const antwort = websockets.ahmed.gesendet.at(-1);
  assert.equal(antwort.t, "ops");
  assert.equal(antwort.ops.length, 3);
  assert.equal(antwort.mehr, false);
});

test("Präsenz: da geht bei Verbinden und Trennen an beide raus", async () => {
  const { raum, ctx, websockets } = raumMitVerbindung(["ahmed"]);
  const annikaWs = new FakeWs();
  ctx.acceptWebSocket(annikaWs, ["annika"]);
  ctx._trennen(annikaWs);
  raum.webSocketClose(annikaWs);
  const letztePraesenzAhmed = websockets.ahmed.gesendet.filter((m) => m.t === "da").at(-1);
  assert.deepEqual(letztePraesenzAhmed, { t: "da", ahmed: true, annika: false });
});

test("fl (außer standort) geht nur an den Partner, nie an einen selbst, wird nie gespeichert", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "tippt", d: { an: true } }));
  assert.equal(websockets.annika.gesendet.at(-1).t, "fl");
  assert.equal(websockets.annika.gesendet.at(-1).von, "ahmed");
  assert.ok(!websockets.ahmed.gesendet.some((m) => m.t === "fl"));
});

test("Medien: PUT Teile, fertig erst wenn alle da, GET liefert Bytes, fehlend meldet Lücken", async () => {
  const { raum } = raumMitVerbindung([]);
  const put = (teil, bytes) => raum.fetch(new Request(`https://x/medien/m1/original/${teil}`, { method: "PUT", body: bytes, headers: { "X-Lovea-Person": "ahmed" } }));

  await put(0, new Uint8Array([1, 2]));
  await put(2, new Uint8Array([5, 6]));

  const fertigVersuch = await raum.fetch(
    new Request("https://x/medien/m1/original/fertig", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ teile: 3, typ: "image/jpeg", bytes: 6 }),
    })
  );
  assert.equal(fertigVersuch.status, 409);

  const nichtGefunden = await raum.fetch(new Request("https://x/medien/m1", { headers: { "X-Lovea-Person": "annika" } }));
  assert.equal(nichtGefunden.status, 404);

  const fehlend = await raum.fetch(new Request("https://x/medien/m1/fehlend?rolle=original", { headers: { "X-Lovea-Person": "ahmed" } }));
  assert.deepEqual(await fehlend.json(), { vorhanden: [0, 2], fehlend: [1] });

  await put(1, new Uint8Array([3, 4]));
  const fertigOk = await raum.fetch(
    new Request("https://x/medien/m1/original/fertig", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ teile: 3, typ: "image/jpeg", bytes: 6 }),
    })
  );
  assert.equal(fertigOk.status, 200);

  const gefunden = await raum.fetch(new Request("https://x/medien/m1", { headers: { "X-Lovea-Person": "annika" } }));
  assert.equal(gefunden.status, 200);
  assert.equal(gefunden.headers.get("X-Lovea-Rolle"), "original");
  const buf = new Uint8Array(await gefunden.arrayBuffer());
  assert.deepEqual([...buf], [1, 2, 3, 4, 5, 6]);
});

test("POST /ops: Batch wird gespeichert, Antwort ist die letzte seq", async () => {
  const { raum } = raumMitVerbindung([]);
  const res = await raum.fetch(
    new Request("https://x/ops", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({
        ops: [
          { id: "b1", art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: {} },
          { id: "b2", art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:01:00.000Z", d: {} },
        ],
      }),
    })
  );
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { seq: 2 });
});

test("alarm(): setzt einen zukünftigen Alarm, wenn ein Treffen ansteht", async () => {
  const { raum, ctx } = raumMitVerbindung([]);
  await raum.fetch(
    new Request("https://x/ops", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ ops: [{ id: "t1", art: "treffen.setzen", von: "ahmed", zeit: new Date().toISOString(), d: { datum: "2099-01-01", uhrzeit: "18:00" } }] }),
    })
  );
  assert.ok(ctx._alarms.zeitpunkt > Date.now());
});
