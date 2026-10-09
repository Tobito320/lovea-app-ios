import { test } from "node:test";
import assert from "node:assert/strict";
import { fakeSql } from "./fake-sql.js";
import { initSchema } from "./raum-logic.js";
import { eintragPruefen, eintraegePruefen, eintraegeLesen, SCHEMA } from "./eintraege.js";
import { tagesformRegel, begrenzen, tagesformBerechnen, schlafGrenze } from "./tagesform.js";

const HEUTE = "2026-10-08";
const JETZT = Date.parse("2026-10-08T10:00:00Z");
const ENV = { OPENAI_API_KEY: "sk-test-GEHEIM-1" };

function db() {
  const sql = fakeSql();
  initSchema(sql);
  return sql;
}

const modell = (inhalt, { ok = true, status = "completed" } = {}) => {
  const aufrufe = [];
  const fn = async (url, init) => {
    aufrufe.push({ url, init, body: JSON.parse(init.body) });
    return { ok, status: ok ? 200 : 500, text: async () => JSON.stringify({ status, output: [{ type: "reasoning" }, { type: "message", content: [{ type: "output_text", text: typeof inhalt === "string" ? inhalt : JSON.stringify(inhalt) }] }] }) };
  };
  fn.aufrufe = aufrufe;
  return fn;
};

const leer = { datum: null, name: null, mahlzeit: null, menge: null, einheit: null, kcal: null, protein: null, kohlenhydrate: null, fett: null, ml: null, minuten: null, bett: null, auf: null, stimmung: null };

test("Schema: strikt, jede Eigenschaft ist required", () => {
  const item = SCHEMA.properties.eintraege.items;
  assert.equal(item.additionalProperties, false);
  assert.deepEqual([...item.required].sort(), Object.keys(item.properties).sort());
});

test("essen: gültig, gerundet, Mahlzeit-Standard snack", () => {
  const e = eintragPruefen({ typ: "essen", name: " Banane ", menge: 120.4, einheit: "g", kcal: 105.6, protein: 1.3, kohlenhydrate: 27, fett: 0.4, mahlzeit: "unsinn" }, HEUTE);
  assert.deepEqual(e, { typ: "essen", datum: HEUTE, name: "Banane", menge: 120, einheit: "g", mahlzeit: "snack", kcal: 106, protein: 1.3, kohlenhydrate: 27, fett: 0.4 });
});

test("essen: unmögliche Werte fliegen raus", () => {
  assert.equal(eintragPruefen({ typ: "essen", name: "x", menge: 100, kcal: 99999 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "essen", name: "x", menge: 0, kcal: 10 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "essen", name: "", menge: 10, kcal: 10 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "essen", name: "x", menge: 10, kcal: -5 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "essen", name: "x", menge: 10, kcal: 10, protein: 9999 }, HEUTE), null);
});

test("wasser, training, stimmung: Bereiche", () => {
  assert.deepEqual(eintragPruefen({ typ: "wasser", ml: 500 }, HEUTE), { typ: "wasser", datum: HEUTE, ml: 500 });
  assert.equal(eintragPruefen({ typ: "wasser", ml: 20000 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "wasser", ml: 0 }, HEUTE), null);
  assert.deepEqual(eintragPruefen({ typ: "training", name: "Laufen", minuten: 30 }, HEUTE), { typ: "training", datum: HEUTE, name: "Laufen", minuten: 30 });
  assert.equal(eintragPruefen({ typ: "training", name: "Laufen", minuten: 5000 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "stimmung", stimmung: 6 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "stimmung", stimmung: 2.5 }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "stimmung", stimmung: 4 }, HEUTE).stimmung, 4);
});

test("schlaf: über Mitternacht, zu kurz, zu lang, Format", () => {
  assert.deepEqual(eintragPruefen({ typ: "schlaf", bett: "23:30", auf: "06:45" }, HEUTE), { typ: "schlaf", datum: HEUTE, bett: "23:30", auf: "06:45" });
  assert.equal(eintragPruefen({ typ: "schlaf", bett: "23:30", auf: "23:50" }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "schlaf", bett: "01:00", auf: "20:00" }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "schlaf", bett: "25:00", auf: "06:00" }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "schlaf", bett: "23:00", auf: null }, HEUTE), null);
});

test("datum: Zukunft und älter als 7 Tage verworfen, fehlendes = heute", () => {
  assert.equal(eintragPruefen({ typ: "wasser", ml: 250, datum: "2026-10-09" }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "wasser", ml: 250, datum: "2026-09-30" }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "wasser", ml: 250, datum: "2026-10-01" }, HEUTE).datum, "2026-10-01");
  assert.equal(eintragPruefen({ typ: "wasser", ml: 250, datum: "gestern" }, HEUTE), null);
  assert.equal(eintragPruefen({ typ: "wasser", ml: 250, datum: null }, HEUTE).datum, HEUTE);
});

test("unbekannter Typ, Müll, zu viele Einträge", () => {
  assert.equal(eintragPruefen({ typ: "kuendigung" }, HEUTE), null);
  assert.equal(eintragPruefen(null, HEUTE), null);
  assert.deepEqual(eintraegePruefen("x", HEUTE), []);
  const viele = Array.from({ length: 30 }, () => ({ typ: "wasser", ml: 250 }));
  assert.equal(eintraegePruefen(viele, HEUTE).length, 12);
});

test("eintraegeLesen: ohne Schlüssel 503, ohne Text 400", async () => {
  const sql = db();
  assert.equal((await eintraegeLesen({ sql, env: {}, person: "ahmed", text: "x", jetztMs: JETZT })).status, 503);
  assert.equal((await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "  ", jetztMs: JETZT })).status, 400);
  assert.equal((await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "x".repeat(1501), jetztMs: JETZT })).status, 400);
});

test("eintraegeLesen: gültige Antwort wird geprüft, Schlüssel nur im Header, Schema gesendet", async () => {
  const sql = db();
  const fetchFn = modell({ eintraege: [{ ...leer, typ: "essen", name: "Haferflocken", menge: 80, einheit: "g", kcal: 300, protein: 10, kohlenhydrate: 50, fett: 6, mahlzeit: "fruehstueck" }, { ...leer, typ: "wasser", ml: 99999 }, { ...leer, typ: "wasser", ml: 500 }] });
  const r = await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "Haferflocken und 0,5 l Wasser", jetztMs: JETZT, fetchFn });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.eintraege.map((e) => e.typ), ["essen", "wasser"]);
  const a = fetchFn.aufrufe[0];
  assert.equal(a.init.headers.authorization, `Bearer ${ENV.OPENAI_API_KEY}`);
  assert.ok(!a.init.body.includes(ENV.OPENAI_API_KEY));
  assert.equal(a.body.text.format.type, "json_schema");
  assert.equal(a.body.text.format.strict, true);
  assert.ok(!JSON.stringify(r).includes(ENV.OPENAI_API_KEY));
});

test("eintraegeLesen: kaputte Modellantwort und HTTP-Fehler = 502 ohne Details", async () => {
  const sql = db();
  const r1 = await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "x", jetztMs: JETZT, fetchFn: modell("kein json") });
  assert.equal(r1.status, 502);
  const r2 = await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "x", jetztMs: JETZT, fetchFn: modell({}, { ok: false }) });
  assert.equal(r2.status, 502);
  assert.deepEqual(Object.keys(r2.body), ["fehler"]);
});

test("eintraegeLesen: Tageslimit 40, danach 429", async () => {
  const sql = db();
  const fetchFn = modell({ eintraege: [] });
  for (let i = 0; i < 40; i++) assert.equal((await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "x", jetztMs: JETZT, fetchFn })).status, 200);
  assert.equal((await eintraegeLesen({ sql, env: ENV, person: "ahmed", text: "x", jetztMs: JETZT, fetchFn })).status, 429);
  assert.equal((await eintraegeLesen({ sql, env: ENV, person: "annika", text: "x", jetztMs: JETZT, fetchFn })).status, 200);
});

// --- Tagesform ---------------------------------------------------------------------------------------------

const ZIELE = { schlafZiel: 480, wasserZiel: 8, schritteZiel: 8000 };

test("Tagesform: wenig Schlaf plus viel Wasser, Schritte, Erholung bleibt niedrig", () => {
  const r = tagesformRegel({ ...ZIELE, schlafMinuten: 120, wasser: 12, schritte: 12000, erholung: 1 });
  assert.equal(r.grenze, schlafGrenze(120, 480));
  assert.ok(r.akku <= r.grenze && r.akku <= 40, `akku ${r.akku}`);
});

test("Tagesform: ohne Schlaf kein Wert, Wasser ändert nichts", () => {
  const a = tagesformRegel({ ...ZIELE, schlafMinuten: null, wasser: 0, schritte: 0, erholung: 1 });
  const b = tagesformRegel({ ...ZIELE, schlafMinuten: null, wasser: 20, schritte: 20000, erholung: 1 });
  assert.equal(a.akku, null);
  assert.deepEqual(a, b);
});

test("Tagesform: Wasser hebt nur klein innerhalb der Grenze, nie über sie", () => {
  const ohne = tagesformRegel({ ...ZIELE, schlafMinuten: 300, wasser: 0, schritte: 0, erholung: 0 });
  const mit = tagesformRegel({ ...ZIELE, schlafMinuten: 300, wasser: 8, schritte: 0, erholung: 0 });
  assert.ok(mit.akku > ohne.akku);
  assert.ok(mit.akku - ohne.akku <= 12);
  assert.ok(mit.akku <= mit.grenze);
});

test("Tagesform: Schlaf wächst, Wert wächst; voller Schlaf plus alles = 100", () => {
  let letzter = -1;
  for (let m = 0; m <= 480; m += 60) {
    const r = tagesformRegel({ ...ZIELE, schlafMinuten: m, wasser: 4, schritte: 4000, erholung: 0.5 });
    assert.ok(r.akku >= letzter);
    letzter = r.akku;
  }
  assert.equal(tagesformRegel({ ...ZIELE, schlafMinuten: 600, wasser: 8, schritte: 8000, erholung: 1 }).akku, 100);
});

test("Tagesform: Modellwert über der Grenze wird gekappt, Müll wird Regelwert", () => {
  const regel = tagesformRegel({ ...ZIELE, schlafMinuten: 120, wasser: 8, schritte: 0, erholung: 1 });
  assert.equal(begrenzen(95, regel), regel.grenze);
  assert.equal(begrenzen(-10, regel), 0);
  assert.equal(begrenzen("viel", regel), regel.akku);
  assert.equal(begrenzen(50, { akku: null, grenze: null }), null);
});

test("tagesformBerechnen: ohne Schlüssel Regelwert; mit Modell gekappt und mit Satz; Limit 12", async () => {
  const sql = db();
  const body = { ...ZIELE, schlafMinuten: 120, wasser: 12, schritte: 9000, erholung: 1 };
  const ohne = await tagesformBerechnen({ sql, env: {}, person: "ahmed", body, jetztMs: JETZT });
  assert.equal(ohne.body.quelle, "regel");
  const fetchFn = modell({ akku: 90, satz: "Nur 2 Stunden Schlaf." });
  const mit = await tagesformBerechnen({ sql, env: ENV, person: "ahmed", body, jetztMs: JETZT, fetchFn });
  assert.equal(mit.body.quelle, "coach");
  assert.equal(mit.body.akku, schlafGrenze(120, 480));
  assert.equal(mit.body.satz, "Nur 2 Stunden Schlaf.");
  for (let i = 0; i < 11; i++) await tagesformBerechnen({ sql, env: ENV, person: "ahmed", body, jetztMs: JETZT, fetchFn });
  const danach = await tagesformBerechnen({ sql, env: ENV, person: "ahmed", body, jetztMs: JETZT, fetchFn });
  assert.equal(danach.body.quelle, "regel");
  assert.equal(fetchFn.aufrufe.length, 12);
});

test("tagesformBerechnen: ohne Schlaf kein Modellaufruf; Modellfehler = Regelwert; Müll im Body", async () => {
  const sql = db();
  const fetchFn = modell({ akku: 90, satz: "x" });
  const r = await tagesformBerechnen({ sql, env: ENV, person: "ahmed", body: { ...ZIELE, schlafMinuten: null, wasser: 9 }, jetztMs: JETZT, fetchFn });
  assert.equal(r.body.akku, null);
  assert.equal(fetchFn.aufrufe.length, 0);
  const fehl = await tagesformBerechnen({ sql, env: ENV, person: "ahmed", body: { ...ZIELE, schlafMinuten: 300 }, jetztMs: JETZT, fetchFn: modell("kein json") });
  assert.equal(fehl.body.quelle, "regel");
  const muell = await tagesformBerechnen({ sql, env: {}, person: "ahmed", body: { schlafMinuten: "viel", schlafZiel: {} }, jetztMs: JETZT });
  assert.equal(muell.body.akku, null);
});
