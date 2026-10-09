import { test } from "node:test";
import assert from "node:assert/strict";
import { handleFetch } from "./index.js";
import {
  handleKi,
  itemBerechnen,
  gesamtBerechnen,
  profilBereinigen,
  tagBereinigen,
  kontextText,
  textAusAntwort,
  coachAnweisung,
  ESSEN_SCHEMA,
  LIMITS,
  MIN_KCAL,
} from "./ki.js";
import { kiIntern, nameNormal, portionenKorrigieren, portionenLesen, nutzungZaehlen } from "./ki-raum.js";
import { initSchema } from "./raum-logic.js";
import { fakeSql } from "./fake-sql.js";

const JETZT = Date.parse("2026-10-08T10:00:00Z");

function fakeRaum() {
  const sql = fakeSql();
  initSchema(sql);
  return {
    sql,
    idFromName: (n) => n,
    get: () => ({ fetch: (req) => kiIntern(sql, req, req.headers.get("X-Lovea-Person")) }),
  };
}

function antwortJson(obj) {
  return { status: "completed", output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(obj) }] }] };
}

// Gibt ein fetch zurück, das Aufrufe sammelt und eine feste Antwort liefert.
function fakeFetch(antwort, status = 200) {
  const aufrufe = [];
  const f = async (url, init) => {
    aufrufe.push({ url, init, body: JSON.parse(init.body) });
    return antwort instanceof Response ? antwort : new Response(JSON.stringify(antwort), { status, headers: { "Content-Type": "application/json" } });
  };
  f.aufrufe = aufrufe;
  return f;
}

const ENV = (extra = {}) => ({ OPENAI_API_KEY: "sk-test", RAUM: fakeRaum(), ...extra });
const req = (pfad, body, methode = "POST") =>
  new Request(`https://x${pfad}`, { method: methode, headers: { "Content-Type": "application/json" }, body: methode === "GET" ? undefined : JSON.stringify(body) });

const ESSEN_ROH = {
  ist_essen: true,
  items: [
    { name: "Basmatireis, gekocht", gramm: 200, kcal_pro_100g: 130, protein_pro_100g: 2.7, kohlenhydrate_pro_100g: 28, fett_pro_100g: 0.3, sicherheit: "mittel" },
    { name: "Hähnchenbrust, gebraten", gramm: 150, kcal_pro_100g: 165, protein_pro_100g: 31, kohlenhydrate_pro_100g: 0, fett_pro_100g: 3.6, sicherheit: "hoch" },
  ],
  versteckt: [{ name: "Bratöl", gramm: 10, kcal_pro_100g: 880 }],
  frage: null,
  bemerkung: "Reis mit Hähnchen",
};
const BILD = Buffer.from("fake-jpeg-bytes").toString("base64");

// --- Berechnung -------------------------------------------------------------

test("itemBerechnen: rechnet Portion aus Gramm und Werten pro 100 g", () => {
  const i = itemBerechnen({ name: "Reis", gramm: 200, kcal_pro_100g: 130, protein_pro_100g: 2.7, kohlenhydrate_pro_100g: 28, fett_pro_100g: 0.3, sicherheit: "mittel" });
  assert.equal(i.kcal, 260);
  assert.equal(i.protein, 5.4);
  assert.equal(i.kohlenhydrate, 56);
  assert.equal(i.sicherheit, "mittel");
});

test("itemBerechnen: Makros korrigieren unplausible Kalorien (aber nicht bei Alkohol)", () => {
  const falsch = itemBerechnen({ name: "Nudeln", gramm: 100, kcal_pro_100g: 40, protein_pro_100g: 5, kohlenhydrate_pro_100g: 70, fett_pro_100g: 1, sicherheit: "hoch" });
  assert.equal(falsch.kcal_pro_100g, 309); // 4*5 + 4*70 + 9*1
  const bier = itemBerechnen({ name: "Bier", gramm: 500, kcal_pro_100g: 43, protein_pro_100g: 0.5, kohlenhydrate_pro_100g: 3.6, fett_pro_100g: 0, sicherheit: "hoch" });
  assert.equal(bier.kcal_pro_100g, 43);
});

test("itemBerechnen: begrenzt Unsinn und setzt Standardwerte", () => {
  const i = itemBerechnen({ name: "x".repeat(200), gramm: 99999, kcal_pro_100g: 5000, protein_pro_100g: -3, sicherheit: "komisch" });
  assert.equal(i.gramm, 2000);
  assert.equal(i.name.length, 60);
  assert.equal(i.kcal_pro_100g, 900);
  assert.equal(i.protein_pro_100g, 0);
  assert.equal(i.sicherheit, "mittel");
});

test("gesamtBerechnen: Summe, Bereich und versteckte Kalorien", () => {
  const items = [itemBerechnen(ESSEN_ROH.items[0]), itemBerechnen(ESSEN_ROH.items[1])];
  const g = gesamtBerechnen(items, [{ name: "Öl", gramm: 10, kcal: 88 }]);
  assert.equal(g.kcal, 260 + 248);
  assert.ok(g.kcal_min < g.kcal && g.kcal < g.kcal_max);
  assert.equal(g.versteckt_kcal, 88);
  assert.equal(g.kcal_mit_versteckt, g.kcal + 88);
  assert.ok(g.kcal_max >= g.kcal + 88);
});

test("profilBereinigen: Mindest-kcal, unbekanntes Ziel, Müll", () => {
  assert.equal(profilBereinigen({ kcal: 800 }).kcal, MIN_KCAL);
  assert.equal(profilBereinigen({ kcal: "abc" }).kcal, null);
  assert.equal(profilBereinigen({ ziel: "crash" }).ziel, null);
  assert.equal(profilBereinigen(null).kcal, null);
  assert.equal(profilBereinigen({ ziel: "cut", kcal: 2100, protein: 160 }).ziel, "cut");
});

test("kontextText: enthält nur vorhandene Angaben", () => {
  const t = kontextText("annika", profilBereinigen({ ziel: "cut", kcal: 1800 }), tagBereinigen({ kcal_gegessen: 900, schritte: 5000, mahlzeiten: [{ name: "Joghurt", kcal: 150 }] }));
  assert.match(t, /Annika/);
  assert.match(t, /1800 kcal/);
  assert.match(t, /Joghurt \(150 kcal\)/);
  assert.doesNotMatch(t, /Schlaf/);
});

test("coachAnweisung: nennt Mindestgrenze und Hilfehinweis", () => {
  const a = coachAnweisung("ahmed");
  assert.match(a, new RegExp(String(MIN_KCAL)));
  assert.match(a, /Essstörung/);
  assert.match(a, /112/);
});

test("textAusAntwort: liest output_text und message-Teile", () => {
  assert.equal(textAusAntwort({ output_text: "hi" }), "hi");
  assert.equal(textAusAntwort(antwortJson({ a: 1 })), '{"a":1}');
  assert.equal(textAusAntwort({}), "");
});

test("ESSEN_SCHEMA: strikt (alle Felder required, keine zusätzlichen)", () => {
  assert.equal(ESSEN_SCHEMA.additionalProperties, false);
  assert.deepEqual([...ESSEN_SCHEMA.required].sort(), Object.keys(ESSEN_SCHEMA.properties).sort());
  const k = ESSEN_SCHEMA.properties.items.items;
  assert.deepEqual([...k.required].sort(), Object.keys(k.properties).sort());
});

// --- ki-raum (Durable-Object-Zustand) ---------------------------------------

test("nutzungZaehlen: zählt bis zum Limit, dann erlaubt=false", () => {
  const sql = fakeSql();
  initSchema(sql);
  for (let i = 1; i <= 3; i++) assert.deepEqual(nutzungZaehlen(sql, "ahmed", { art: "essen", max: 3, tag: "2026-10-08" }), { erlaubt: true, n: i, max: 3 });
  assert.deepEqual(nutzungZaehlen(sql, "ahmed", { art: "essen", max: 3, tag: "2026-10-08" }), { erlaubt: false, n: 3, max: 3 });
  // andere Person und anderer Tag haben eigene Zähler
  assert.equal(nutzungZaehlen(sql, "annika", { art: "essen", max: 3, tag: "2026-10-08" }).n, 1);
  assert.equal(nutzungZaehlen(sql, "ahmed", { art: "essen", max: 3, tag: "2026-10-09" }).n, 1);
  assert.equal(nutzungZaehlen(sql, "ahmed", { art: "unbekannt", max: 3, tag: "2026-10-08" }), null);
});

test("nutzungZaehlen: räumt alte Tageszähler beim ersten Eintrag eines neuen Tags weg", () => {
  const sql = fakeSql();
  initSchema(sql);
  nutzungZaehlen(sql, "ahmed", { art: "coach", max: 10, tag: "2026-10-01" });
  nutzungZaehlen(sql, "ahmed", { art: "coach", max: 10, tag: "2026-10-07" });
  nutzungZaehlen(sql, "ahmed", { art: "essen", max: 10, tag: "2026-10-08" });
  const rest = sql.exec(`SELECT schluessel FROM merker WHERE schluessel LIKE 'ki:nutzung:%'`).toArray().map((r) => r.schluessel);
  assert.ok(!rest.some((s) => s.includes("2026-10-01")));
  assert.ok(rest.some((s) => s.includes("2026-10-07")));
  assert.ok(rest.some((s) => s.includes("2026-10-08")));
});

test("portionenKorrigieren: laufender Durchschnitt, sortiert nach Häufigkeit", () => {
  const sql = fakeSql();
  initSchema(sql);
  portionenKorrigieren(sql, "ahmed", [{ name: "Basmatireis (gekocht)", gramm: 200 }, { name: "Ei", gramm: 60 }]);
  portionenKorrigieren(sql, "ahmed", [{ name: "basmatireis", gramm: 100 }]);
  portionenKorrigieren(sql, "ahmed", [{ name: "Basmatireis", gramm: 150 }, { name: "  ", gramm: 10 }, { name: "Quark", gramm: -5 }]);
  const liste = portionenLesen(sql, "ahmed");
  assert.equal(liste[0].name, "basmatireis");
  assert.equal(liste[0].n, 3);
  assert.equal(liste[0].gramm, 150);
  assert.equal(liste.length, 2);
  assert.deepEqual(portionenLesen(sql, "annika"), []);
  assert.equal(nameNormal("Hähnchen (gebraten) 200g!"), "hähnchen 200g");
});

test("kiIntern: nur bekannte Personen, unbekannter Pfad 404", async () => {
  const sql = fakeSql();
  initSchema(sql);
  const r1 = await kiIntern(sql, new Request("https://raum/ki-intern/stand", { method: "POST", body: "{}" }), "fremd");
  assert.equal(r1.status, 401);
  const r2 = await kiIntern(sql, new Request("https://raum/ki-intern/gibtsnicht", { method: "POST", body: "{}" }), "ahmed");
  assert.equal(r2.status, 404);
});

// --- handleKi: Essen -----------------------------------------------------------

test("/ki/essen: baut OpenAI-Anfrage korrekt und rechnet das Ergebnis nach", async () => {
  const f = fakeFetch(antwortJson(ESSEN_ROH));
  const env = ENV();
  const res = await handleKi(req("/ki/essen", { bild: BILD, mime: "image/jpeg", hinweis: "Hähnchen 150 g", mahlzeit: "mittag" }), env, "ahmed", { fetch: f, jetzt: JETZT });
  assert.equal(res.status, 200);
  const j = await res.json();
  assert.equal(j.ist_essen, true);
  assert.equal(j.items.length, 2);
  assert.equal(j.items[0].kcal, 260);
  assert.equal(j.gesamt.kcal, 508);
  assert.equal(j.versteckt[0].kcal, 88);
  assert.equal(j.rest, LIMITS.essen - 1);

  const a = f.aufrufe[0];
  assert.equal(a.url, "https://api.openai.com/v1/responses");
  assert.equal(a.init.headers.Authorization, "Bearer sk-test");
  assert.equal(a.body.model, "gpt-6-luna");
  assert.equal(a.body.store, false);
  assert.deepEqual(a.body.reasoning, { effort: "low" });
  assert.equal(a.body.text.format.type, "json_schema");
  assert.equal(a.body.text.format.strict, true);
  assert.equal(a.body.prompt_cache_key, "lovea-essen-v1");
  const inhalt = a.body.input[0].content;
  assert.match(inhalt[0].text, /Hähnchen 150 g/);
  assert.match(inhalt[0].text, /Mittagessen/);
  assert.equal(inhalt[1].type, "input_image");
  assert.equal(inhalt[1].image_url, `data:image/jpeg;base64,${BILD}`);
});

test("/ki/essen: bekannte Portionen landen im Prompt (ab 2 Korrekturen)", async () => {
  const env = ENV();
  await handleKi(req("/ki/korrektur", { items: [{ name: "Basmatireis", gramm: 180 }] }), env, "ahmed", {});
  await handleKi(req("/ki/korrektur", { items: [{ name: "Basmatireis", gramm: 180 }] }), env, "ahmed", {});
  const f = fakeFetch(antwortJson(ESSEN_ROH));
  await handleKi(req("/ki/essen", { bild: BILD }), env, "ahmed", { fetch: f, jetzt: JETZT });
  assert.match(f.aufrufe[0].body.input[0].content[0].text, /basmatireis 180 g/);
  // Annika sieht Ahmeds Portionen nicht
  const f2 = fakeFetch(antwortJson(ESSEN_ROH));
  await handleKi(req("/ki/essen", { bild: BILD }), env, "annika", { fetch: f2, jetzt: JETZT });
  assert.doesNotMatch(f2.aufrufe[0].body.input[0].content[0].text, /basmatireis/);
});

test("/ki/essen: kein Essen auf dem Bild", async () => {
  const f = fakeFetch(antwortJson({ ist_essen: false, items: [], versteckt: [], frage: null, bemerkung: "Das ist eine Katze" }));
  const res = await handleKi(req("/ki/essen", { bild: BILD }), ENV(), "ahmed", { fetch: f, jetzt: JETZT });
  const j = await res.json();
  assert.equal(j.ist_essen, false);
  assert.equal(j.gesamt.kcal, 0);
});

test("/ki/essen: ungültige Eingaben kosten keine Nutzung und rufen OpenAI nicht auf", async () => {
  const f = fakeFetch(antwortJson(ESSEN_ROH));
  const env = ENV();
  assert.equal((await handleKi(req("/ki/essen", {}), env, "ahmed", { fetch: f })).status, 400);
  assert.equal((await handleKi(req("/ki/essen", { bild: "kein base64!!" }), env, "ahmed", { fetch: f })).status, 400);
  assert.equal((await handleKi(req("/ki/essen", { bild: BILD, mime: "image/gif" }), env, "ahmed", { fetch: f })).status, 400);
  assert.equal((await handleKi(req("/ki/essen", { bild: "A".repeat(1_500_000) }), env, "ahmed", { fetch: f })).status, 413);
  assert.equal((await handleKi(new Request("https://x/ki/essen", { method: "POST", body: "kein json" }), env, "ahmed", { fetch: f })).status, 400);
  assert.equal(f.aufrufe.length, 0);
  const stand = await (await handleKi(req("/ki/status", null, "GET"), env, "ahmed", { jetzt: JETZT })).json();
  assert.equal(stand.rest.essen, LIMITS.essen);
});

test("/ki/essen: Tageslimit gibt 429", async () => {
  const f = fakeFetch(antwortJson(ESSEN_ROH));
  const env = ENV();
  for (let i = 0; i < LIMITS.essen; i++) nutzungZaehlen(env.RAUM.sql, "ahmed", { art: "essen", max: LIMITS.essen, tag: "2026-10-08" });
  const res = await handleKi(req("/ki/essen", { bild: BILD }), env, "ahmed", { fetch: f, jetzt: JETZT });
  assert.equal(res.status, 429);
  assert.equal((await res.json()).fehler, "tageslimit");
  assert.equal(f.aufrufe.length, 0);
});

test("/ki/essen: OpenAI-Fehler werden übersetzt und die Nutzung zurückgegeben", async () => {
  const faelle = [
    [401, { error: { message: "Incorrect API key sk-geheim", code: "invalid_api_key" } }, 503, "schluessel"],
    [429, { error: { code: "insufficient_quota" } }, 503, "guthaben"],
    [429, { error: { code: "rate_limit_exceeded" } }, 429, "zu viele anfragen"],
    [500, { error: { message: "boom" } }, 502, "ki-fehler"],
  ];
  for (const [status, body, erwartet, fehler] of faelle) {
    const env = ENV();
    const res = await handleKi(req("/ki/essen", { bild: BILD }), env, "ahmed", { fetch: fakeFetch(body, status), jetzt: JETZT });
    assert.equal(res.status, erwartet);
    const j = await res.json();
    assert.equal(j.fehler, fehler);
    assert.ok(!JSON.stringify(j).includes("sk-geheim"), "kein OpenAI-Text durchreichen");
    const stand = await (await handleKi(req("/ki/status", null, "GET"), env, "ahmed", { jetzt: JETZT })).json();
    assert.equal(stand.rest.essen, LIMITS.essen, "Nutzung zurückgegeben");
  }
});

test("/ki/essen: unvollständige oder kaputte Antwort -> 502", async () => {
  const env = ENV();
  const unvollstaendig = await handleKi(req("/ki/essen", { bild: BILD }), env, "ahmed", { fetch: fakeFetch({ status: "incomplete", output: [] }), jetzt: JETZT });
  assert.equal(unvollstaendig.status, 502);
  const kaputt = await handleKi(req("/ki/essen", { bild: BILD }), env, "ahmed", {
    fetch: fakeFetch({ status: "completed", output: [{ type: "message", content: [{ type: "output_text", text: "{nicht json" }] }] }),
    jetzt: JETZT,
  });
  assert.equal(kaputt.status, 502);
});

test("/ki/*: ohne OPENAI_API_KEY -> 503 nicht eingerichtet; Status zeigt das", async () => {
  const env = ENV({ OPENAI_API_KEY: undefined });
  const res = await handleKi(req("/ki/essen", { bild: BILD }), env, "ahmed", {});
  assert.equal(res.status, 503);
  const s = await (await handleKi(req("/ki/status", null, "GET"), env, "ahmed", { jetzt: JETZT })).json();
  assert.equal(s.eingerichtet, false);
});

// --- handleKi: Coach ---------------------------------------------------------

const NACHRICHT = { nachrichten: [{ rolle: "nutzer", text: "Was esse ich heute Abend?" }], profil: { ziel: "cut", kcal: 2100, protein: 160 }, tag: { kcal_gegessen: 1200 } };

test("/ki/coach: Anfrage ohne Reasoning, mit Kontext und gekürztem Verlauf", async () => {
  const f = fakeFetch({ status: "completed", output: [{ type: "message", content: [{ type: "output_text", text: "Wie wäre es mit Quark und Beeren?" }] }] });
  const viele = Array.from({ length: 30 }, (_, i) => ({ rolle: i % 2 ? "coach" : "nutzer", text: `nachricht ${i}` }));
  viele.push({ rolle: "nutzer", text: "Letzte Frage" });
  const res = await handleKi(req("/ki/coach", { ...NACHRICHT, nachrichten: viele }), ENV(), "annika", { fetch: f, jetzt: JETZT });
  const j = await res.json();
  assert.equal(j.antwort, "Wie wäre es mit Quark und Beeren?");
  const b = f.aufrufe[0].body;
  assert.deepEqual(b.reasoning, { effort: "none" });
  assert.equal(b.max_output_tokens, 700);
  assert.match(b.instructions, /Annika/);
  assert.equal(b.input[0].role, "developer");
  assert.match(b.input[0].content, /2100 kcal/);
  assert.equal(b.input.length, 1 + 12);
  assert.equal(b.input[b.input.length - 1].content, "Letzte Frage");
  assert.equal(b.prompt_cache_key, "lovea-coach-annika-v1");
  assert.equal(b.stream, undefined);
});

test("/ki/coach: Mindest-kcal gilt auch bei falschem Client-Wert", async () => {
  const f = fakeFetch({ status: "completed", output_text: "ok" });
  await handleKi(req("/ki/coach", { ...NACHRICHT, profil: { ziel: "cut", kcal: 600 } }), ENV(), "ahmed", { fetch: f, jetzt: JETZT });
  assert.match(f.aufrufe[0].body.input[0].content, new RegExp(`${MIN_KCAL} kcal`));
  assert.doesNotMatch(f.aufrufe[0].body.input[0].content, /600 kcal/);
});

test("/ki/coach: letzte Nachricht muss vom Nutzer sein", async () => {
  const f = fakeFetch({ status: "completed", output_text: "ok" });
  const res = await handleKi(req("/ki/coach", { nachrichten: [{ rolle: "coach", text: "Hallo" }] }), ENV(), "ahmed", { fetch: f });
  assert.equal(res.status, 400);
  assert.equal((await handleKi(req("/ki/coach", { nachrichten: [] }), ENV(), "ahmed", { fetch: f })).status, 400);
  assert.equal(f.aufrufe.length, 0);
});

test("/ki/coach: Streaming wandelt Responses-Ereignisse in einfache Zeilen um", async () => {
  const sse =
    'event: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"Hal"}\n\n' +
    'event: response.output_text.delta\ndata: {"type":"response.output_text.delta","delta":"lo"}\n\n' +
    'event: response.completed\ndata: {"type":"response.completed","response":{}}\n\n';
  const upstream = new Response(new ReadableStream({ start(c) { c.enqueue(new TextEncoder().encode(sse)); c.close(); } }), { status: 200, headers: { "Content-Type": "text/event-stream" } });
  const f = fakeFetch(upstream);
  const res = await handleKi(req("/ki/coach", { ...NACHRICHT, stream: true }), ENV(), "ahmed", { fetch: f, jetzt: JETZT });
  assert.equal(res.headers.get("Content-Type"), "text/event-stream; charset=utf-8");
  assert.equal(f.aufrufe[0].body.stream, true);
  const t = await res.text();
  const ereignisse = t.split("\n\n").filter(Boolean).map((z) => JSON.parse(z.replace(/^data: /, "")));
  assert.deepEqual(ereignisse, [{ t: "delta", text: "Hal" }, { t: "delta", text: "lo" }, { t: "ende" }]);
});

test("/ki/coach: Stream-Fehler von OpenAI -> normale Fehlerantwort und Nutzung zurück", async () => {
  const env = ENV();
  const res = await handleKi(req("/ki/coach", { ...NACHRICHT, stream: true }), env, "ahmed", { fetch: fakeFetch({ error: { code: "x" } }, 500), jetzt: JETZT });
  assert.equal(res.status, 502);
  const s = await (await handleKi(req("/ki/status", null, "GET"), env, "ahmed", { jetzt: JETZT })).json();
  assert.equal(s.rest.coach, LIMITS.coach);
});

// --- handleKi: Bericht ---------------------------------------------------------

test("/ki/bericht: gibt bereinigte Listen zurück und braucht Daten", async () => {
  const roh = { titel: "Starker Tag mit etwas zu wenig Eiweiß, das ist ein sehr langer Titel", kurzfassung: "Gut gelaufen.", was_gut: ["a", "b", "c", "d"], was_besser: ["x"], morgen: [] };
  const f = fakeFetch(antwortJson(roh));
  const env = ENV();
  const kein = await handleKi(req("/ki/bericht", { profil: { ziel: "cut" }, tag: {} }), env, "ahmed", { fetch: f });
  assert.equal(kein.status, 400);
  const res = await handleKi(
    req("/ki/bericht", { profil: { ziel: "cut", kcal: 2100 }, tag: { kcal_gegessen: 2000, protein: 120, schritte: 9000 }, vortage: [{ datum: "2026-10-07", kcal_gegessen: 2300 }] }),
    env,
    "ahmed",
    { fetch: f, jetzt: JETZT }
  );
  const j = await res.json();
  assert.ok(j.titel.length <= 40);
  assert.equal(j.was_gut.length, 3);
  assert.deepEqual(j.morgen, []);
  const b = f.aufrufe[0].body;
  assert.equal(b.text.format.name, "bericht");
  assert.match(b.input[0].content, /2026-10-07: 2300 kcal/);
  assert.equal(j.rest, LIMITS.bericht - 1);
});

// --- Worker-Einstieg ---------------------------------------------------------------

const KEY = "geheim-test-schluessel";
const auth = { "X-Lovea-Key": KEY, "X-Lovea-Person": "ahmed" };

test("Worker: /ki-intern ist von außen gesperrt", async () => {
  const res = await handleFetch(new Request("https://x/ki-intern/nutzung", { method: "POST", headers: auth, body: "{}" }), { LOVEA_APP_KEY: KEY, RAUM: fakeRaum() });
  assert.equal(res.status, 404);
});

test("Worker: /ki/* braucht den App-Schlüssel", async () => {
  const res = await handleFetch(new Request("https://x/ki/status", { headers: { "X-Lovea-Person": "ahmed" } }), { LOVEA_APP_KEY: KEY, RAUM: fakeRaum() });
  assert.equal(res.status, 401);
});

test("Worker: /ki/status läuft über handleKi", async () => {
  const res = await handleFetch(new Request("https://x/ki/status", { headers: auth }), { LOVEA_APP_KEY: KEY, RAUM: fakeRaum() });
  assert.equal(res.status, 200);
  const j = await res.json();
  assert.equal(j.eingerichtet, false);
  assert.equal(j.modell, "gpt-6-luna");
});
