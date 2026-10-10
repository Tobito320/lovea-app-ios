// Tests für das Kostenbuch der KI-Funktionen (Preise aus Config, Monatsbudget,
// Wächter für die Tagesberichte) und für die Zyklusfelder im Kontext.
import test from "node:test";
import assert from "node:assert/strict";
import { fakeSql } from "./fake-sql.js";
import { initSchema } from "./raum-logic.js";
import { kiIntern } from "./ki-raum.js";
import { BERICHT_STOP_USD, BUDGET_USD, PREISE_STANDARD, kostenBuchen, kostenRechnen, kostenStand, monatVon, preiseLesen } from "./ki-kosten.js";
import { handleKi, kontextText, profilBereinigen } from "./ki.js";

const JETZT = Date.parse("2026-10-08T10:00:00Z");

function raum() {
  const sql = fakeSql();
  initSchema(sql);
  return sql;
}

function fakeRaum(sql) {
  return { sql, idFromName: (n) => n, get: () => ({ fetch: (req) => kiIntern(sql, req, req.headers.get("X-Lovea-Person")) }) };
}

const ENV = (sql, extra = {}) => ({ OPENAI_API_KEY: "sk-test", RAUM: fakeRaum(sql), ...extra });

const req = (pfad, body, methode = "POST") =>
  new Request(`https://x${pfad}`, {
    method: methode,
    headers: { "Content-Type": "application/json" },
    body: methode === "GET" ? undefined : JSON.stringify(body),
  });

function antwortJson(obj, usage) {
  return { status: "completed", usage, output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(obj) }] }] };
}

function fakeFetch(antwort, status = 200) {
  const f = async (url, init) => {
    f.aufrufe.push({ url, init, body: JSON.parse(init.body) });
    return new Response(JSON.stringify(antwort), { status, headers: { "Content-Type": "application/json" } });
  };
  f.aufrufe = [];
  return f;
}

const BERICHT = { titel: "Guter Tag", kurzfassung: "Passt.", was_gut: ["Eiweiß"], was_besser: ["Mehr Schlaf"], morgen: ["Wasser"] };
const INTERN = (pfad, body) =>
  new Request(`https://raum${pfad}`, { method: "POST", headers: { "Content-Type": "application/json", "X-Lovea-Person": "ahmed" }, body: JSON.stringify(body) });

// --- Rechnen -------------------------------------------------------------------

test("kostenRechnen: Cache-Tokens zählen günstiger", () => {
  const r = kostenRechnen(PREISE_STANDARD, "gpt-6-luna", { input_tokens: 1_000_000, output_tokens: 100_000, input_tokens_details: { cached_tokens: 600_000 } });
  assert.equal(r.ein, 400_000);
  assert.equal(r.cache, 600_000);
  assert.equal(r.aus, 100_000);
  // 0,4 Mio * 1,25 + 0,6 Mio * 0,125 + 0,1 Mio * 10 = 0,5 + 0,075 + 1,0
  assert.equal(r.usd, 1.575);
});

test("kostenRechnen: kaputtes usage ergibt 0", () => {
  assert.deepEqual(kostenRechnen(PREISE_STANDARD, "gpt-6-luna", undefined), { ein: 0, cache: 0, aus: 0, usd: 0 });
  assert.equal(kostenRechnen(PREISE_STANDARD, "gpt-6-luna", { input_tokens: -5, output_tokens: "x" }).usd, 0);
});

test("preiseLesen: Config schlägt Standard, Müll fällt zurück", () => {
  const p = preiseLesen({ KI_PREISE: JSON.stringify({ "gpt-6-luna": { ein: 2, ein_cache: 0.2, aus: 20 } }) });
  assert.equal(p["gpt-6-luna"].aus, 20);
  assert.deepEqual(preiseLesen({ KI_PREISE: "{kaputt" }), PREISE_STANDARD);
  assert.deepEqual(preiseLesen({}), PREISE_STANDARD);
});

test("monatVon schneidet den Tag ab", () => {
  assert.equal(monatVon("2026-10-08"), "2026-10");
});

// --- Buchen und Stand ----------------------------------------------------------

test("kostenBuchen summiert je Feature und je Monat", () => {
  const sql = raum();
  kostenBuchen(sql, { monat: "2026-10", feature: "bericht", ein: 1000, cache: 0, aus: 500, usd: 1.5 });
  const r = kostenBuchen(sql, { monat: "2026-10", feature: "essen", ein: 10, cache: 0, aus: 5, usd: 0.25 });
  assert.equal(r.usd_monat, 1.75);
  const stand = kostenStand(sql, "2026-10");
  assert.equal(stand.usd, 1.75);
  assert.equal(stand.je_feature.bericht.usd, 1.5);
  assert.equal(stand.je_feature.bericht.n, 1);
  assert.equal(stand.bericht_erlaubt, true);
  assert.equal(stand.budget, BUDGET_USD);
});

test("kostenBuchen: ab 9 $ sind Tagesberichte gesperrt, Fotos nicht", () => {
  const sql = raum();
  const r = kostenBuchen(sql, { monat: "2026-10", feature: "bericht", ein: 0, cache: 0, aus: 0, usd: BERICHT_STOP_USD });
  assert.equal(r.bericht_erlaubt, false);
  assert.equal(r.warnen, true, "erste Überschreitung warnt");
  const r2 = kostenBuchen(sql, { monat: "2026-10", feature: "essen", ein: 0, cache: 0, aus: 0, usd: 0.1 });
  assert.equal(r2.warnen, false, "nur eine Warnung pro Monat");
  assert.equal(kostenStand(sql, "2026-10").bericht_erlaubt, false);
  assert.equal(kostenStand(sql, "2026-11").bericht_erlaubt, true, "neuer Monat ist frei");
});

test("kostenBuchen prüft Eingaben und räumt alte Monate weg", () => {
  const sql = raum();
  assert.equal(kostenBuchen(sql, { monat: "quatsch", feature: "bericht", usd: 1 }), null);
  assert.equal(kostenBuchen(sql, { monat: "2026-10", feature: "hacken", usd: 1 }), null);
  kostenBuchen(sql, { monat: "2026-06", feature: "bericht", ein: 0, cache: 0, aus: 0, usd: 5 });
  kostenBuchen(sql, { monat: "2026-10", feature: "bericht", ein: 0, cache: 0, aus: 0, usd: 1 });
  assert.equal(kostenStand(sql, "2026-06").usd, 0, "Monate älter als 3 sind weg");
});

// --- Route im Durable Object ---------------------------------------------------

test("/ki-intern/kosten bucht und meldet die Warnung im Header", async () => {
  const sql = raum();
  const r1 = await kiIntern(sql, INTERN("/ki-intern/kosten", { monat: "2026-10", feature: "bericht", ein: 1, cache: 0, aus: 1, usd: 2 }), "ahmed");
  assert.equal(r1.status, 200);
  assert.equal(r1.headers.get("X-Ki-Warnung"), null);
  assert.equal((await r1.json()).usd_monat, 2);

  const r2 = await kiIntern(sql, INTERN("/ki-intern/kosten", { monat: "2026-10", feature: "bericht", ein: 1, cache: 0, aus: 1, usd: 8 }), "ahmed");
  assert.equal(r2.headers.get("X-Ki-Warnung"), "1");
  const stand = await kiIntern(sql, INTERN("/ki-intern/kosten-stand", { monat: "2026-10" }), "ahmed");
  const s = await stand.json();
  assert.equal(s.usd, 10);
  assert.equal(s.bericht_erlaubt, false);
});

// --- Zusammenspiel mit ki.js ---------------------------------------------------

const PROFIL = { ziel: "cut", kcal: 2000, protein: 160, gewicht: 80 };
const TAG = { kcal_gegessen: 1500, protein: 120 };

test("Bericht bucht die Kosten des Aufrufs", async () => {
  const sql = raum();
  const f = fakeFetch(antwortJson(BERICHT, { input_tokens: 2000, output_tokens: 1000, input_tokens_details: { cached_tokens: 1000 } }));
  const res = await handleKi(req("/ki/bericht", { profil: PROFIL, tag: TAG }), ENV(sql), "ahmed", { jetzt: JETZT, fetch: f });
  assert.equal(res.status, 200);
  const stand = kostenStand(sql, "2026-10");
  // 1000 * 1,25 + 1000 * 0,125 + 1000 * 10 pro Mio
  assert.equal(stand.je_feature.bericht.usd, 0.011375);
  assert.equal(stand.je_feature.bericht.n, 1);
});

test("Bericht sperrt über Budget, Essen läuft weiter", async () => {
  const sql = raum();
  kostenBuchen(sql, { monat: "2026-10", feature: "bericht", ein: 0, cache: 0, aus: 0, usd: 9.5 });
  const f = fakeFetch(antwortJson(BERICHT, { input_tokens: 10, output_tokens: 10 }));
  const res = await handleKi(req("/ki/bericht", { profil: PROFIL, tag: TAG }), ENV(sql), "ahmed", { jetzt: JETZT, fetch: f });
  assert.equal(res.status, 429);
  assert.equal((await res.json()).fehler, "budget");
  assert.equal(f.aufrufe.length, 0, "kein Aufruf bei OpenAI");

  const bild = "A".repeat(2000);
  const f2 = fakeFetch(
    antwortJson(
      { ist_essen: true, items: [{ name: "Reis", menge_g: 200, kcal: 260, protein_g: 5, kohlenhydrate_g: 56, fett_g: 1, sicherheit: "mittel" }], versteckt: [], frage: null, bemerkung: "" },
      { input_tokens: 10, output_tokens: 10 }
    )
  );
  const res2 = await handleKi(req("/ki/essen", { bild, mime: "image/jpeg" }), ENV(sql), "ahmed", { jetzt: JETZT, fetch: f2 });
  assert.equal(res2.status, 200);
  assert.equal(f2.aufrufe.length, 1);
});

test("/ki/status zeigt den Monatsstand", async () => {
  const sql = raum();
  kostenBuchen(sql, { monat: "2026-10", feature: "coach", ein: 0, cache: 0, aus: 0, usd: 3 });
  const res = await handleKi(req("/ki/status", null, "GET"), ENV(sql), "ahmed", { jetzt: JETZT });
  const j = await res.json();
  assert.equal(j.kosten.usd, 3);
  assert.equal(j.kosten.bericht_erlaubt, true);
});

// --- Zyklus --------------------------------------------------------------------

test("profilBereinigen nimmt Zyklustag und Phase, prüft Grenzen", () => {
  const p = profilBereinigen({ ...PROFIL, zyklus_tag: 12, zyklus_phase: "follikel" });
  assert.equal(p.zyklus_tag, 12);
  assert.equal(p.zyklus_phase, "follikel");
  assert.equal(profilBereinigen({ zyklus_tag: 99, zyklus_phase: "quatsch" }).zyklus_tag, null);
  assert.equal(profilBereinigen({ zyklus_tag: 99, zyklus_phase: "quatsch" }).zyklus_phase, null);
  assert.equal(profilBereinigen({}).zyklus_tag, null);
});

test("Zyklus steht nur bei Annika im Kontext", () => {
  const p = profilBereinigen({ ...PROFIL, zyklus_tag: 12, zyklus_phase: "luteal" });
  const tag = { kcal: null, protein: null, schritte: null, schlaf: null, training: "", notiz: "", mahlzeiten: [] };
  assert.match(kontextText("annika", p, tag), /Zyklus: Tag 12/);
  assert.doesNotMatch(kontextText("ahmed", p, tag), /Zyklus/);
});
