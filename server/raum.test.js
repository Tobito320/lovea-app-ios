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
    this._attachment = null;
  }
  send(data) {
    this.gesendet.push(JSON.parse(data));
  }
  // Nachbildung der echten Hibernation-API: pro Socket angehängte, JSON-
  // serialisierbare Daten, die einen DO-Neustart überleben (hier: einfach im
  // Objekt gehalten, weil dieser Test-Prozess ohnehin nicht neu startet).
  serializeAttachment(data) {
    this._attachment = data;
  }
  deserializeAttachment() {
    return this._attachment;
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

// Ein echtes (aber wegwerfbares) EC-Schlüsselpaar, damit push.js einen
// gültigen ES256-JWT bauen kann, falls ein Test wirklich pusht (die meisten
// tun das nicht, weil niemand ein Geräte-Token registriert).
const TEST_APNS_KEY_P8 = await (async () => {
  const paar = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", paar.privateKey);
  const b64 = Buffer.from(pkcs8).toString("base64");
  return `-----BEGIN PRIVATE KEY-----\n${b64.match(/.{1,64}/g).join("\n")}\n-----END PRIVATE KEY-----\n`;
})();

function fakeEnv() {
  return { APNS_KEY_ID: "k", APNS_TEAM_ID: "t", APNS_KEY_P8: TEST_APNS_KEY_P8 };
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

// I-3/M-3/M-4: eine ungültige Op (fehlende id, oder `von` stimmt nicht mit
// dem Socket überein) wird abgelehnt, nicht gespeichert, kein Broadcast.
test("op über WebSocket: ungültige Op wird mit fehler abgelehnt und nicht gespeichert", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);

  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "op", op: { art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: {} } }));
  assert.equal(websockets.ahmed.gesendet.at(-1).t, "fehler");

  await raum.webSocketMessage(
    websockets.ahmed,
    JSON.stringify({ t: "op", op: { id: "gefaelscht", art: "nachricht.neu", von: "annika", zeit: "2026-09-23T10:00:00.000Z", d: {} } })
  );
  assert.equal(websockets.ahmed.gesendet.at(-1).t, "fehler");
  assert.equal(websockets.ahmed.gesendet.at(-1).opId, "gefaelscht");

  // Weder Ops noch Broadcasts durch die abgelehnten Versuche.
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "nachholen", seit: 0 }));
  assert.equal(websockets.ahmed.gesendet.at(-1).ops.length, 0);
  assert.ok(!websockets.annika.gesendet.some((m) => m.t === "ops" && m.ops.some((o) => o.id === "gefaelscht")));
});

// I-5: Ping/Pong plus Kontakt-Tracking.
test("ping/pong: Server antwortet, und jede Nachricht aktualisiert den Kontakt-Zeitstempel", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed"]);
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "ping" }));
  const pong = websockets.ahmed.gesendet.at(-1);
  assert.equal(pong.t, "pong");
  assert.ok(typeof pong.zeit === "string");
  assert.ok(typeof websockets.ahmed.deserializeAttachment().letzterKontakt === "number");
});

// I-5: ein seit > 60s stiller Socket zählt für Push-Entscheidungen als
// getrennt, auch wenn er noch in getWebSockets() auftaucht (z. B. eine im
// Hintergrund suspendierte App, deren Close-Frame nie rausging).
test("Push geht raus, sobald der Empfänger-Socket seit über 60s still ist, trotz offener Verbindung", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  await raum.webSocketMessage(websockets.annika, JSON.stringify({ t: "geraet", token: "0".repeat(64) }));
  // annikas letzter Kontakt liegt weit in der Vergangenheit -- Socket ist
  // technisch noch da (getWebSockets() liefert ihn), aber "tot".
  websockets.annika.serializeAttachment({ letzterKontakt: Date.now() - 61_000 });

  const calls = [];
  const echterFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    return new Response(null, { status: 200 });
  };
  try {
    await raum.webSocketMessage(
      websockets.ahmed,
      JSON.stringify({ t: "op", op: { id: "n1", art: "nachricht.neu", von: "ahmed", zeit: new Date().toISOString(), d: { text: "hi" } } })
    );
  } finally {
    globalThis.fetch = echterFetch;
  }
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /api\.push\.apple\.com/);
});

// Z-32.1: Antippen einer Chat-Mitteilung springt zur Nachricht -- `art` und `nachrichtId` stehen oben
// neben `aps`, nur bei `nachricht.*`-Ops mit `d.id`.
test("Push für nachricht.neu und nachricht.reaktion trägt art und nachrichtId, eine Geste nicht", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  await raum.webSocketMessage(websockets.annika, JSON.stringify({ t: "geraet", token: "0".repeat(64) }));
  websockets.annika.serializeAttachment({ letzterKontakt: Date.now() - 61_000 });

  const bodies = [];
  const echterFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    bodies.push(JSON.parse(init.body));
    return new Response(null, { status: 200 });
  };
  try {
    const zeit = new Date().toISOString();
    await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "op", op: { id: "op-1", art: "nachricht.neu", von: "ahmed", zeit, d: { id: "msg-1", text: "hi" } } }));
    await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "op", op: { id: "op-2", art: "nachricht.reaktion", von: "ahmed", zeit, d: { id: "msg-1", emoji: "figur:lacht" } } }));
    await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "op", op: { id: "op-3", art: "geste", von: "ahmed", zeit, d: { art: "herz" } } }));
  } finally {
    globalThis.fetch = echterFetch;
  }
  assert.equal(bodies.length, 3);
  assert.equal(bodies[0].art, "nachricht.neu");
  assert.equal(bodies[0].nachrichtId, "msg-1");
  assert.equal(bodies[0].aps.alert.body, "Ahmed: hi");
  assert.deepEqual([bodies[1].art, bodies[1].nachrichtId], ["nachricht.reaktion", "msg-1"]);
  assert.equal(bodies[2].nachrichtId, undefined);
  assert.equal(bodies[2].aps.alert.body, "Ahmed denkt gerade an dich");
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

// Regressionstest: standortSchreiben() drosselt nur das Wegschreiben in die
// Tabelle, nicht die Live-Weiterleitung an den Partner. Früher hat ein
// `return` bei geschrieben===false auch die Weiterleitung verschluckt -- die
// Live-Karte hätte dann nur einen Punkt pro Minute bekommen.
test("standort (fl): geht live bei jedem Update an den Partner, auch innerhalb der Schreib-Drossel", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 1, lon: 1 } }));
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 1.0001, lon: 1 } }));
  const empfangen = websockets.annika.gesendet.filter((m) => m.t === "standort");
  assert.equal(empfangen.length, 2);
});

// Hintergrund-Standort: der WebSocket ist nach ~30s Backgrounding zu, aber
// CLLocationManager liefert weiter. POST /fl ist der Ersatz-Eingang.
test("POST /fl: standort geht wie über den WebSocket an den Partner, wird gedrosselt geschrieben, prüft Zufällig nah", async () => {
  const { raum, websockets } = raumMitVerbindung(["annika"]);
  // annika ist schon ganz nah dran, per WebSocket gemeldet.
  await raum.webSocketMessage(websockets.annika, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0, lon: 7.0 } }));

  const res = await raum.fetch(
    new Request("https://x/fl", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ art: "standort", d: { lat: 51.0005, lon: 7.0 } }), // ~56 m von annika entfernt
    })
  );
  assert.equal(res.status, 204);

  // Live an den Partner weitergeleitet, genau wie über den WebSocket.
  const standortNachricht = websockets.annika.gesendet.find((m) => m.t === "standort" && m.person === "ahmed");
  assert.deepEqual(standortNachricht?.d, { lat: 51.0005, lon: 7.0 });

  // Zufällig-nah-Prüfung lief mit -- beide bekommen die System-Op.
  assert.ok(websockets.annika.gesendet.some((m) => m.t === "ops" && m.ops[0]?.d?.system === "nah"));
});

test("POST /fl: nicht-standort wird als generisches fl an den Partner weitergeleitet, nicht gespeichert", async () => {
  const { raum, websockets } = raumMitVerbindung(["annika"]);
  const res = await raum.fetch(
    new Request("https://x/fl", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ art: "tippt", d: { an: true } }),
    })
  );
  assert.equal(res.status, 204);
  const fl = websockets.annika.gesendet.find((m) => m.t === "fl");
  assert.deepEqual(fl, { t: "fl", von: "ahmed", art: "tippt", d: { an: true } });
});

test("POST /fl: ohne gültige Person 401, mit kaputtem Body 400", async () => {
  const { raum } = raumMitVerbindung(["annika"]);
  const ohnePerson = await raum.fetch(new Request("https://x/fl", { method: "POST", body: JSON.stringify({ art: "tippt", d: {} }) }));
  assert.equal(ohnePerson.status, 401);

  const kaputterBody = await raum.fetch(
    new Request("https://x/fl", { method: "POST", headers: { "X-Lovea-Person": "ahmed" }, body: "kein json" })
  );
  assert.equal(kaputterBody.status, 400);

  const fehlendesD = await raum.fetch(
    new Request("https://x/fl", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ art: "tippt" }),
    })
  );
  assert.equal(fehlendesD.status, 400);
});

// Review-Fokus / Z-1.8: "an beide eine Op", nicht zwei separate Bubbles.
test("Zufällig nah: genau eine Op an beide, laute Push nur einmal pro 6h", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  await raum.webSocketMessage(websockets.annika, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0, lon: 7.0 } }));
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0005, lon: 7.0 } })); // ~56 m entfernt

  const nahOpsAhmed = websockets.ahmed.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.d?.system === "nah");
  const nahOpsAnnika = websockets.annika.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.d?.system === "nah");
  assert.equal(nahOpsAhmed.length, 1);
  assert.equal(nahOpsAnnika.length, 1);
  assert.equal(nahOpsAhmed[0].ops[0].id, nahOpsAnnika[0].ops[0].id); // dieselbe Op, nicht zwei

  // Noch einmal ganz nah -> keine zweite Meldung innerhalb von 6h.
  await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0005, lon: 7.0001 } }));
  const nochmal = websockets.ahmed.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.d?.system === "nah");
  assert.equal(nochmal.length, 1);
});

// Z-27.4: Server erkennt "zusammen unterwegs" über zwei Standort-Meldungen, mindestens 30 min
// auseinander -- die Wartezeit hier über einen gemockten Date.now(), damit der Test nicht wirklich
// 30 Minuten läuft.
test("Unsere Orte: ort.gemeinsam erst nach 30 Minuten am Stück, danach nicht doppelt", async () => {
  const { raum, websockets } = raumMitVerbindung(["ahmed", "annika"]);
  const echtesDatumNow = Date.now;
  try {
    let jetzt = Date.parse("2026-09-23T10:00:00.000Z");
    Date.now = () => jetzt;

    await raum.webSocketMessage(websockets.annika, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0, lon: 7.0 } }));
    await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0005, lon: 7.0 } }));
    assert.equal(websockets.ahmed.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.art === "ort.gemeinsam").length, 0);

    jetzt += 31 * 60_000;
    await raum.webSocketMessage(websockets.annika, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0, lon: 7.0 } }));
    await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0005, lon: 7.0 } }));
    const gemeinsam = websockets.ahmed.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.art === "ort.gemeinsam");
    assert.equal(gemeinsam.length, 1);
    // annika sendet in diesem Block zuerst -- ihr Standort löst die Meldung aus, mit ihren Koordinaten.
    assert.deepEqual(gemeinsam[0].ops[0].d, { lat: 51.0, lon: 7.0, datum: "2026-09-23" });

    // Noch einmal nah -- dieselbe Streak, deterministische Op-id dedupt, kein zweiter Broadcast.
    jetzt += 60_000;
    await raum.webSocketMessage(websockets.ahmed, JSON.stringify({ t: "fl", art: "standort", d: { lat: 51.0005, lon: 7.0 } }));
    assert.equal(websockets.ahmed.gesendet.filter((m) => m.t === "ops" && m.ops[0]?.art === "ort.gemeinsam").length, 1);
  } finally {
    Date.now = echtesDatumNow;
  }
});

// Z-27.6: Verbinden ohne SPOTIFY_CLIENT_ID meldet "nicht eingerichtet" wie /gif ohne KLIPY_KEY.
test("POST /spotify/verbinden: ohne SPOTIFY_CLIENT_ID 503 nicht eingerichtet", async () => {
  const { raum } = raumMitVerbindung([]);
  const res = await raum.fetch(
    new Request("https://x/spotify/verbinden", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({ code: "c", verifier: "v", redirectUri: "lovea://spotify" }),
    })
  );
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { fehler: "nicht eingerichtet" });
});

test("Spotify verbinden + jetzt: Token-Tausch, currently-playing, 20s-Cache", async () => {
  const ctx = fakeCtx();
  const raum = new Raum(ctx, { ...fakeEnv(), SPOTIFY_CLIENT_ID: "test-client" });
  const aufrufe = [];
  const echterFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    aufrufe.push({ url: String(url), init });
    if (String(url).includes("accounts.spotify.com")) {
      return Response.json({ access_token: "AT", refresh_token: "RT", expires_in: 3600 });
    }
    return Response.json({ item: { name: "Song", artists: [{ name: "Band" }], album: { images: [{ url: "cover" }] }, external_urls: { spotify: "u" } } });
  };
  try {
    const verbinden = await raum.fetch(
      new Request("https://x/spotify/verbinden", {
        method: "POST",
        headers: { "content-type": "application/json", "X-Lovea-Person": "annika" },
        body: JSON.stringify({ code: "c", verifier: "v", redirectUri: "lovea://spotify" }),
      })
    );
    assert.equal(verbinden.status, 200);
    assert.deepEqual(await verbinden.json(), { ok: true });

    const jetzt1 = await raum.fetch(new Request("https://x/spotify/jetzt?person=annika", { headers: { "X-Lovea-Person": "ahmed" } }));
    assert.deepEqual(await jetzt1.json(), { musik: true, titel: "Song", kuenstler: "Band", cover: "cover", url: "u" });
    const anrufeNachErstemJetzt = aufrufe.length;

    // Zweiter Abruf sofort danach: aus dem 20s-Cache, kein weiterer fetch.
    const jetzt2 = await raum.fetch(new Request("https://x/spotify/jetzt?person=annika", { headers: { "X-Lovea-Person": "ahmed" } }));
    assert.deepEqual(await jetzt2.json(), { musik: true, titel: "Song", kuenstler: "Band", cover: "cover", url: "u" });
    assert.equal(aufrufe.length, anrufeNachErstemJetzt);

    // Niemand hat für ahmed verbunden -> {}.
    const ohneVerbindung = await raum.fetch(new Request("https://x/spotify/jetzt?person=ahmed", { headers: { "X-Lovea-Person": "ahmed" } }));
    assert.deepEqual(await ohneVerbindung.json(), {});
  } finally {
    globalThis.fetch = echterFetch;
  }
});

test("Spotify Freigabe: spotify.teilen der Zielperson filtert auf dem Server, trennen loescht den Token", async () => {
  const ctx = fakeCtx();
  const raum = new Raum(ctx, { ...fakeEnv(), SPOTIFY_CLIENT_ID: "test-client" });
  const annikaWs = new FakeWs();
  ctx.acceptWebSocket(annikaWs, ["annika"]);
  const echterFetch = globalThis.fetch;
  let spotifyAufrufe = 0;
  globalThis.fetch = async (url) => {
    if (String(url).includes("accounts.spotify.com")) return Response.json({ access_token: "AT", refresh_token: "RT", expires_in: 3600 });
    spotifyAufrufe += 1;
    return Response.json({ is_playing: true, item: { name: "Song", artists: [{ name: "Band" }], album: { images: [{ url: "cover" }] }, external_urls: { spotify: "u" } } });
  };
  const teilen = (id, wert) =>
    raum.webSocketMessage(annikaWs, JSON.stringify({ t: "op", op: { id, art: "einstellung.setzen", von: "annika", zeit: new Date().toISOString(), d: { schluessel: "spotify.teilen", wert } } }));
  const jetzt = async () => (await raum.fetch(new Request("https://x/spotify/jetzt?person=annika", { headers: { "X-Lovea-Person": "ahmed" } }))).json();
  try {
    await raum.fetch(
      new Request("https://x/spotify/verbinden", {
        method: "POST",
        headers: { "content-type": "application/json", "X-Lovea-Person": "annika" },
        body: JSON.stringify({ code: "c", verifier: "v", redirectUri: "lovea://spotify" }),
      })
    );
    await teilen("s1", "kuenstler");
    assert.deepEqual(await jetzt(), { musik: true, kuenstler: "Band" });
    await teilen("s2", "musik");
    assert.deepEqual(await jetzt(), { musik: true }); // aus dem Cache, trotzdem gefiltert
    await teilen("s3", "aus");
    const vorher = spotifyAufrufe;
    assert.deepEqual(await jetzt(), {});
    assert.equal(spotifyAufrufe, vorher);
    await teilen("s4", "song");
    assert.equal((await jetzt()).titel, "Song");

    // Ahmed kann Annikas Verbindung nicht trennen, nur Annika selbst.
    await raum.fetch(new Request("https://x/spotify/trennen", { method: "POST", headers: { "X-Lovea-Person": "ahmed" } }));
    assert.equal((await jetzt()).titel, "Song");
    const trennen = await raum.fetch(new Request("https://x/spotify/trennen", { method: "POST", headers: { "X-Lovea-Person": "annika" } }));
    assert.equal(trennen.status, 200);
    assert.deepEqual(await jetzt(), {});
  } finally {
    globalThis.fetch = echterFetch;
  }
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
  assert.deepEqual(await res.json(), { seq: 2, uebersprungen: 0 });
});

// I-3: eine kaputte Op im Batch (Umzugsskript) darf die gültigen nicht
// verhindern und muss gezählt werden, statt den ganzen Batch zu verwerfen.
test("POST /ops: ungültige Ops im Batch werden übersprungen und gezählt", async () => {
  const { raum } = raumMitVerbindung([]);
  const res = await raum.fetch(
    new Request("https://x/ops", {
      method: "POST",
      headers: { "content-type": "application/json", "X-Lovea-Person": "ahmed" },
      body: JSON.stringify({
        ops: [
          { id: "g1", art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: {} },
          { art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: {} }, // keine id
          { id: "g2", art: "nachricht.neu", von: "niemand", zeit: "2026-09-23T10:00:00.000Z", d: {} }, // unbekannte Person
          { id: "g3", art: "nachricht.neu", von: "ahmed", zeit: "2026-09-23T10:00:00.000Z", d: "kaputt" }, // d ist kein Objekt
        ],
      }),
    })
  );
  assert.deepEqual(await res.json(), { seq: 1, uebersprungen: 3 });
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
