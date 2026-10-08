import { test } from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import { fakeSql } from "./fake-sql.js";
import { initSchema, opEinfuegen, alleOpsVon, merkerLesen, merkerSchreiben } from "./raum-logic.js";
import * as gym from "./gym.js";
import { coachKontext, coachAntwort, coachMorgen, coachMorgenAn } from "./coach.js";
import { ANWEISUNG } from "./coach-anweisung.js";

const KATALOG = gym.katalogLaden(join(import.meta.dirname, "..", "Lovea", "Sources", "Health"));
const JETZT = Date.parse("2026-10-08T10:00:00Z"); // Donnerstag, 12:00 Berlin
const HEUTE = "2026-10-08";
const KEY = "sk-test-GEHEIMER-SCHLUESSEL-123";
const ENV = { OPENAI_API_KEY: KEY };
const LATZUG = "qdRxqCj"; // Latissimus (Rücken), neben Bizeps
const swift = (iso) => Date.parse(iso) / 1000 - 978307200;
const tag = (versatz) => gym.addTage(HEUTE, versatz);

function db() {
  const sql = fakeSql();
  initSchema(sql);
  return sql;
}

let zaehler = 0;
function schreibe(sql, art, d, { von = "ahmed", zeit = "2026-10-08T08:00:00.000Z", id = `t${++zaehler}` } = {}) {
  opEinfuegen(sql, { id, art, von, zeit, d });
}

function essen(sql, id, datum, kcal, { protein = 0, name = "Zeug", menge = 100, einheit = "g", lm = {}, geloescht = false } = {}, opts) {
  schreibe(
    sql,
    "essen.setzen",
    {
      id, datum, mahlzeit: "mittag", menge, einheit,
      lebensmittel: { id: `l-${id}`, name, fluessig: false, pro100: { kcal, protein, kohlenhydrate: 0, fett: 0 }, ...lm },
      ...(geloescht ? { geloescht: true } : {}),
    },
    opts
  );
}

const einstellung = (sql, schluessel, wert, opts) => schreibe(sql, "einstellung.setzen", { schluessel, wert }, opts);

function mitEssenTagen(sql, anzahl, kcal, opts) {
  for (let i = 1; i <= anzahl; i++) essen(sql, `tag${i}-${zaehler++}`, tag(-i), kcal, {}, opts);
}

function modellAntwort(text) {
  return {
    status: "completed",
    output: [
      { type: "reasoning", id: "rs_1", summary: [] }, // Reasoning-Item steht VOR der Nachricht
      { type: "message", role: "assistant", content: [{ type: "output_text", text }] },
    ],
  };
}

function fakeModell(text = "Weiter so, ruhig und regelmäßig.") {
  const calls = [];
  const fetchFn = async (url, init) => {
    calls.push({ url, init, body: JSON.parse(init.body) });
    return new Response(JSON.stringify(modellAntwort(text)), { status: 200 });
  };
  return { fetchFn, calls };
}

let idZaehler = 0;
const neueId = () => `coach-test-${++idZaehler}`;

function frage(sql, text, { person = "ahmed", env = ENV, fetchFn, jetztMs = JETZT, ...rest } = {}) {
  return coachAntwort({ sql, env, person, text, jetztMs, fetchFn, katalog: KATALOG, neueId, ...rest });
}

// --- Kontext: Essen ------------------------------------------------------------------------------

test("Essen: gleiche id = Bearbeitung (neueste gewinnt), gelöscht zählt nicht, Einheiten in Gramm", async () => {
  const sql = db();
  const gestern = tag(-1);
  // Die neueste Fassung kommt zuerst an, die ältere (höhere seq, ältere zeit) darf sie nicht überschreiben.
  essen(sql, "e1", gestern, 600, {}, { zeit: "2026-10-07T13:00:00.000Z" });
  essen(sql, "e1", gestern, 400, {}, { zeit: "2026-10-07T12:00:00.000Z" });
  essen(sql, "e2", gestern, 300, {}, { zeit: "2026-10-07T12:00:00.000Z" });
  essen(sql, "e2", gestern, 300, { geloescht: true }, { zeit: "2026-10-07T20:00:00.000Z" });
  essen(sql, "e3", gestern, 200, { menge: 2, einheit: "portion", lm: { portionMenge: 150 } }); // 300 g -> 600 kcal
  essen(sql, "e4", gestern, 100, { menge: 1, einheit: "packung", lm: { packungMenge: 250 } }); // 250 g -> 250 kcal
  essen(sql, "e5", gestern, 100, { menge: 1, einheit: "portion" }); // ohne portionMenge: 100 g -> 100 kcal
  for (let i = 2; i <= 10; i++) essen(sql, `fuell${i}`, tag(-i), 1000); // 10 Tage im Log, sonst zeigt der Kontext keine Mengen
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  const eintrag = k.essen.jeTag.find((t) => t.datum === gestern);
  assert.equal(eintrag.kcal, 600 + 600 + 250 + 100);
});

test("Essen: Schnitt nur über Tage mit Einträgen, Tage gezählt, heute getrennt", async () => {
  const sql = db();
  essen(sql, "a", tag(-1), 1400, { protein: 100 });
  essen(sql, "b", tag(-3), 1600, { protein: 80 });
  for (const i of [2, 4, 5, 6, 7, 8, 9, 10]) essen(sql, `fuell${i}`, tag(-i), 1500, { protein: 90 });
  essen(sql, "heute1", HEUTE, 500, { protein: 30, name: "Haferbrei" });
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  assert.equal(k.essen.letzte14Tage.tageMitEintraegen, 10);
  assert.equal(k.essen.letzte14Tage.tageGeprueft, 14);
  assert.equal(k.essen.letzte14Tage.schnittKcal, 1500, "nicht durch 14 geteilt");
  assert.equal(k.essen.letzte14Tage.schnittProtein, 90);
  assert.equal(k.essen.heute.kcal, 500, "heute zählt nicht in den Schnitt, steht aber getrennt da");
  assert.equal(k.essen.heute.eintraege[0].name, "Haferbrei");
});

test("Essen: ein Eintrag, der auf einen Tag außerhalb des Fensters verschoben wurde, zählt nicht mehr", async () => {
  const sql = db();
  essen(sql, "wandert", tag(-2), 900, {}, { zeit: "2026-10-06T12:00:00.000Z" });
  essen(sql, "wandert", tag(-40), 900, {}, { zeit: "2026-10-07T12:00:00.000Z" });
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  assert.equal(k.essen.letzte14Tage.tageMitEintraegen, 0);
});

test("Essen: nur Tage mit echten Kalorien zählen als geloggt (Wasser allein ist kein Essenstag)", async () => {
  const sql = db();
  essen(sql, "wasser", tag(-1), 0, { name: "Wasser" });
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  assert.equal(k.essen.letzte14Tage.tageMitEintraegen, 0);
});

test("Essen: lückiges Log (unter 10 von 14 Tagen) zeigt dem Modell keine Mengen, nur Tage und Hinweis", async () => {
  const sql = db();
  mitEssenTagen(sql, 9, 700);
  essen(sql, "heute1", HEUTE, 300, { protein: 12, name: "Haferbrei" });
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  assert.equal(k.sicherheit.essenLueckig, true);
  assert.equal(k.sicherheit.sehrWenigGegessen, false, "Teiltage sind keine Aufnahme");
  assert.deepEqual(k.essen.letzte14Tage, { tageGeprueft: 14, tageMitEintraegen: 9 });
  assert.match(k.essen.hinweis, /lückenhaft/);
  assert.equal(k.essen.jeTag, undefined);
  assert.equal(k.essen.gestern, undefined);
  assert.equal(k.essen.heute, undefined);
  assert.doesNotMatch(JSON.stringify(k.essen), /kcal|protein|Haferbrei/i);
});

// --- Kontext: Sicherheits-Merker -------------------------------------------------------------------

test("Sicherheit: kcalUntergrenze 1200 (Frau) / 1500 (Mann) aus ziel.ernaehrung.geschlecht, sonst nach Person", async () => {
  const sql = db();
  assert.equal((await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.kcalUntergrenze, 1500);
  assert.equal((await coachKontext(sql, "annika", JETZT, { katalog: KATALOG })).sicherheit.kcalUntergrenze, 1200);
  einstellung(sql, "ziel.ernaehrung.geschlecht", 1, { von: "ahmed" });
  assert.equal((await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.kcalUntergrenze, 1200);
  einstellung(sql, "ziel.ernaehrung.geschlecht", 0, { von: "ahmed" }); // neueste Einstellung gewinnt
  assert.equal((await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.kcalUntergrenze, 1500);
});

test("Sicherheit: essenLueckig bei weniger als 10 von 14 Tagen mit Einträgen", async () => {
  const neun = db();
  mitEssenTagen(neun, 9, 2000);
  const zehn = db();
  mitEssenTagen(zehn, 10, 2000);
  assert.equal((await coachKontext(neun, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.essenLueckig, true);
  assert.equal((await coachKontext(zehn, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.essenLueckig, false);
  const s = (await coachKontext(neun, "ahmed", JETZT, { katalog: KATALOG })).sicherheit;
  assert.equal(s.essenTageMitEintraegen, 9);
});

test("Sicherheit: sehrWenigGegessen = Schnitt unter der Untergrenze, aber nur bei brauchbarem Log (mindestens 10 von 14 Tagen)", async () => {
  const fuenfNiedrig = db();
  mitEssenTagen(fuenfNiedrig, 10, 1000);
  const vierNiedrig = db();
  mitEssenTagen(vierNiedrig, 9, 1000);
  const fuenfOk = db();
  mitEssenTagen(fuenfOk, 10, 1600);
  assert.equal((await coachKontext(fuenfNiedrig, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.sehrWenigGegessen, true);
  assert.equal((await coachKontext(vierNiedrig, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.sehrWenigGegessen, false);
  assert.equal((await coachKontext(fuenfOk, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.sehrWenigGegessen, false);
});

test("Sicherheit: die Untergrenze der Frau (1200) gilt für den Vergleich, nicht die des Mannes", async () => {
  const sql = db();
  mitEssenTagen(sql, 10, 1300, { von: "annika" });
  assert.equal((await coachKontext(sql, "annika", JETZT, { katalog: KATALOG })).sicherheit.sehrWenigGegessen, false);
  const sql2 = db();
  mitEssenTagen(sql2, 10, 1300, { von: "ahmed" });
  assert.equal((await coachKontext(sql2, "ahmed", JETZT, { katalog: KATALOG })).sicherheit.sehrWenigGegessen, true);
});

// --- Kontext: Ziele, Gewicht, Schritte, Schlaf ---------------------------------------------------------

test("Ziele: richtung, tempo, kcal, Protein aus ziel.ernaehrung.*; Schritte und Schlaf", async () => {
  const sql = db();
  einstellung(sql, "ziel.ernaehrung.richtung", 0);
  einstellung(sql, "ziel.ernaehrung.tempo", 250);
  einstellung(sql, "ziel.ernaehrung.kcal", 2300);
  einstellung(sql, "ziel.ernaehrung.protein", 160);
  einstellung(sql, "ziel.schritte", 9000);
  einstellung(sql, "ziel.schlaf.minuten", 450);
  const z = (await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).ziele;
  assert.equal(z.richtung, "abnehmen");
  assert.equal(z.tempoGProWoche, 250);
  assert.equal(z.kcal, 2300);
  assert.equal(z.protein, 160);
  assert.equal(z.schritte, 9000);
  assert.equal(z.schlafMinuten, 450);
});

test("Gewicht: habit gewicht in Zehnteln kg, neueste Op je Tag, 0 und andere Maße zählen nicht", async () => {
  const sql = db();
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: tag(-10), wert: 784 });
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: tag(-3), wert: 780 });
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: HEUTE, wert: 778 });
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: HEUTE, wert: 776 }); // spätere Op desselben Tages gewinnt
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: tag(-1), wert: 0 }); // 0 = kein Wert
  schreibe(sql, "habit.setzen", { art: "mass.taille", datum: tag(-2), wert: 850 }); // anderes Maß
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: tag(-5), wert: 999 }, { von: "annika" });
  const g = (await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).gewicht;
  assert.equal(g.aktuellKg, 77.6);
  assert.equal(g.datum, HEUTE);
  assert.deepEqual(g.verlauf.map((p) => p.kg), [78.4, 78.0, 77.6]);
});

test("Schritte: höchste seq je Tag, Schnitt nur über Tage mit Werten", async () => {
  const sql = db();
  schreibe(sql, "schritte.setzen", { datum: tag(-1), anzahl: 3000 });
  schreibe(sql, "schritte.setzen", { datum: tag(-1), anzahl: 8000 });
  schreibe(sql, "schritte.setzen", { datum: tag(-2), anzahl: 10000 });
  schreibe(sql, "schritte.setzen", { datum: HEUTE, anzahl: 1200 });
  const s = (await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).schritte;
  assert.equal(s.heute, 1200);
  assert.deepEqual(s.letzte7.map((x) => x.anzahl), [10000, 8000]);
  assert.equal(s.schnitt, 9000);
});

test("Schlaf: eigener Eintrag (schlaf.zeiten, Apple-Zeit, Berliner Uhr) schlägt Automatik, 0 sperrt sie", async () => {
  const sql = db();
  const nacht = (datum, minuten) => ({ datum, minuten, von: "2026-10-06T21:00:00Z", bis: "2026-10-07T05:00:00Z" });
  schreibe(sql, "schlaf.setzen", nacht(tag(-1), 400)); // 07.10.: Automatik 400
  schreibe(sql, "schlaf.zeiten", { datum: tag(-1), bett: swift("2026-10-06T21:00:00Z"), auf: swift("2026-10-07T04:30:00Z") }); // 23:00 -> 06:30 = 450
  schreibe(sql, "schlaf.setzen", nacht(tag(-2), 420)); // 06.10.: nur Automatik
  schreibe(sql, "schlaf.setzen", nacht(tag(-3), 380));
  schreibe(sql, "schlaf.zeiten", { datum: tag(-3), bett: swift("2026-10-04T21:00:00Z"), auf: swift("2026-10-04T21:00:00Z") }); // gleich = gelöscht
  const s = (await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).schlaf;
  assert.deepEqual(s.letzte7.map((x) => [x.datum, x.minuten]), [[tag(-2), 420], [tag(-1), 450]]);
  assert.equal(s.schnittMinuten, 435);
});

// --- Kontext: Training ---------------------------------------------------------------------------

function einheit(sql, id, tagIso, saetze) {
  const start = `${tagIso}T16:00:00.000Z`;
  const ende = `${tagIso}T17:00:00.000Z`;
  schreibe(sql, "gym.checkin", { session: id, tag: "T1", start: swift(start) }, { zeit: start });
  schreibe(sql, "gym.uebung", { session: id, plan: `p-${id}`, uebung: LATZUG, status: "satz", saetze }, { zeit: `${tagIso}T16:10:00.000Z` });
  schreibe(sql, "gym.checkout", { session: id, ende: swift(ende), status: "ende" }, { zeit: ende });
}
const arbeitssatz = (wdh, kg) => ({ wdh, kg, failure: false, ok: true });

test("Training: Wochensätze je Muskel, letzte Einheiten und Steigerungsvorschlag über gym.js", async () => {
  const sql = db();
  einheit(sql, "S1", "2026-10-06", [arbeitssatz(12, 60), arbeitssatz(12, 60), arbeitssatz(12, 60)]);
  einheit(sql, "S0", "2026-09-29", [arbeitssatz(10, 55), arbeitssatz(10, 55)]);
  const t = (await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG })).training;
  assert.equal(t.trainings8Wochen, 2);
  assert.equal(t.saetzeJeGruppe.ruecken.dieseWoche, 3);
  assert.equal(t.letzteEinheiten[0].datum, "2026-10-06");
  const latzug = t.uebungen.find((u) => u.id === LATZUG);
  assert.equal(latzug.einheiten, 2);
  assert.equal(latzug.naechstesMal, "62.5 kg × 8", "alle Sätze bei 12 -> +2,5 kg");
});

test("Training: nur eigene Einheiten, ohne Training kein Trainingsblock", async () => {
  const sql = db();
  einheit(sql, "FREMD", "2026-10-06", [arbeitssatz(10, 50)]);
  sql.exec(`UPDATE ops SET von = 'annika' WHERE art LIKE 'gym.%'`);
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  assert.equal(k.training, undefined);
  const annika = await coachKontext(sql, "annika", JETZT, { katalog: KATALOG });
  assert.equal(annika.training.trainings8Wochen, 1);
});

test("Kontext bleibt auch bei viel Material unter dem Größenlimit (rund 4.000 Token)", async () => {
  const sql = db();
  for (let i = 1; i <= 14; i++) {
    for (let m = 0; m < 8; m++) essen(sql, `viel-${i}-${m}`, tag(-i), 350, { protein: 20, name: `Ein sehr langer Name für ein Lebensmittel Nummer ${m}` });
  }
  for (let i = 0; i < 40; i++) {
    einheit(sql, `W${i}`, tag(-i * 2), [arbeitssatz(10, 50 + i), arbeitssatz(9, 50 + i), arbeitssatz(8, 50 + i)]);
    schreibe(sql, "schritte.setzen", { datum: tag(-i), anzahl: 5000 + i });
    schreibe(sql, "habit.setzen", { art: "gewicht", datum: tag(-i), wert: 800 - i });
  }
  const k = await coachKontext(sql, "ahmed", JETZT, { katalog: KATALOG });
  assert.ok(JSON.stringify(k).length <= 16_000, `Kontext zu groß: ${JSON.stringify(k).length}`);
});

// --- Datenschutz (Pflicht) -----------------------------------------------------------------------

test("Datenschutz: ans Modell geht nur Eigenes -- nie Chat, Zyklus, Standort, Galerie, Entwürfe, Partner-Daten", async () => {
  const sql = db();
  // Eigenes, erlaubtes Material.
  essen(sql, "e1", tag(-1), 1800, { name: "Haferbrei" });
  mitEssenTagen(sql, 10, 1500); // brauchbares Log, sonst bleiben die Mengen draußen
  schreibe(sql, "coach.nachricht", { rolle: "du", text: "Meine frühere Frage", tag: tag(-1) });
  // Alles, was nie ins Modell darf -- eigene und fremde Sentinels.
  schreibe(sql, "nachricht.neu", { id: "m1", text: "GEHEIM-CHAT-AHMED" });
  schreibe(sql, "nachricht.neu", { id: "m2", text: "GEHEIM-CHAT-ANNIKA" }, { von: "annika" });
  schreibe(sql, "zyklus.eintrag", { notiz: "GEHEIM-ZYKLUS" }, { von: "annika" });
  schreibe(sql, "zyklus.eintrag", { notiz: "GEHEIM-ZYKLUS-EIGEN" });
  schreibe(sql, "galerie.stand", { titel: "GEHEIM-GALERIE" });
  schreibe(sql, "geschenkbox.neu", { wunsch: "GEHEIM-GESCHENK" });
  schreibe(sql, "entwurf.setzen", { text: "GEHEIM-ENTWURF" });
  schreibe(sql, "termin.setzen", { titel: "GEHEIM-TERMIN" });
  schreibe(sql, "frage.antwort", { text: "GEHEIM-ANTWORT" });
  sql.exec(`INSERT INTO standort (person, d, zeit) VALUES ('ahmed', '{"lat":"GEHEIM-STANDORT"}', '2026-10-08T09:00:00Z')`);
  merkerSchreiben(sql, "spotify.token.ahmed", "GEHEIM-SPOTIFY");
  // Partner: Essen, Gewicht, Coach-Chat -- darf Ahmeds Coach nie erreichen.
  essen(sql, "p1", tag(-1), 999, { name: "GEHEIM-ESSEN-ANNIKA" }, { von: "annika" });
  schreibe(sql, "habit.setzen", { art: "gewicht", datum: HEUTE, wert: 555 }, { von: "annika" });
  schreibe(sql, "coach.nachricht", { rolle: "du", text: "GEHEIM-COACH-ANNIKA", tag: HEUTE }, { von: "annika" });
  einstellung(sql, "ziel.ernaehrung.kcal", 7777, { von: "annika" });
  // Training: eigene Einheit mit Tag T1; Annikas Plan nennt T1 anders, ihre Einheit hat eine Sentinel-Übung.
  einheit(sql, "S1", "2026-10-06", [arbeitssatz(10, 60)]);
  schreibe(sql, "gym.plan", { tage: [{ id: "T1", name: "GEHEIM-PLAN-ANNIKA" }] }, { von: "annika" });
  einheit(sql, "FREMD", "2026-10-07", [arbeitssatz(10, 4242)]);
  sql.exec(`UPDATE ops SET von = 'annika' WHERE art LIKE 'gym.%' AND d LIKE '%FREMD%'`);

  const { fetchFn, calls } = fakeModell();
  const r = await frage(sql, "Wie läuft mein Essen?", { fetchFn });
  assert.equal(r.status, 200);
  const alles = JSON.stringify(calls[0].body);
  assert.doesNotMatch(alles, /GEHEIM/, "kein Sentinel darf im Modell-Request stehen");
  assert.doesNotMatch(alles, /7777|555|4242/);
  assert.match(alles, /trainings8Wochen\\?":1,/, "das eigene Training kommt an");
  assert.match(alles, /Haferbrei/, "eigene Daten kommen an");
  assert.match(alles, /Meine frühere Frage/, "der eigene Coach-Verlauf kommt an");
  assert.equal(calls[0].init.body.includes(KEY), false, "der Schlüssel steht nicht im Body");
});

// --- Modell-Aufruf -----------------------------------------------------------------------------------

test("Aufruf: Responses-API, Bearer-Schlüssel, Standardmodell, niedriger Aufwand, nichts speichern", async () => {
  const sql = db();
  mitEssenTagen(sql, 3, 1800);
  const { fetchFn, calls } = fakeModell("Hallo Ahmed.");
  const r = await frage(sql, "Wie läuft's?", { fetchFn });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { text: "Hallo Ahmed." }, "Reasoning-Item vor der Nachricht wird übersprungen");
  assert.equal(calls.length, 1);
  const c = calls[0];
  assert.equal(c.url, "https://api.openai.com/v1/responses");
  assert.equal(c.init.method, "POST");
  assert.equal(c.init.headers.authorization, `Bearer ${KEY}`);
  assert.equal(c.init.headers["content-type"], "application/json");
  assert.ok(c.init.signal, "Zeitlimit hängt als Signal am Aufruf");
  assert.equal(c.body.model, "gpt-6-luna");
  assert.deepEqual(c.body.reasoning, { effort: "low" });
  assert.equal(c.body.store, false);
  assert.ok(c.body.max_output_tokens >= 700 && c.body.max_output_tokens <= 2000);
  assert.ok(c.body.instructions.startsWith(ANWEISUNG));
  assert.match(c.body.instructions, /"kcalUntergrenze":1500/);
  assert.deepEqual(c.body.input.at(-1), { role: "user", content: "Wie läuft's?" });
});

test("Aufruf: Modell kommt aus COACH_MODELL", async () => {
  const { fetchFn, calls } = fakeModell();
  await frage(db(), "Hi", { env: { ...ENV, COACH_MODELL: "gpt-6-terra" }, fetchFn });
  assert.equal(calls[0].body.model, "gpt-6-terra");
});

test("Verlauf: die letzten 20 Nachrichten der Person, nie die der anderen, beginnt mit der Frage des Nutzers", async () => {
  const sql = db();
  for (let i = 0; i < 25; i++) {
    schreibe(sql, "coach.nachricht", { rolle: i % 2 === 0 ? "du" : "coach", text: `nachricht-${i}`, tag: HEUTE });
  }
  schreibe(sql, "coach.nachricht", { rolle: "du", text: "FREMDE-NACHRICHT", tag: HEUTE }, { von: "annika" });
  const { fetchFn, calls } = fakeModell();
  await frage(sql, "neu", { fetchFn });
  const input = calls[0].body.input;
  // 25 gespeicherte: 5..24 sind die letzten 20; 5 ist "coach" (ungerade) und fällt vorn weg, weil der Verlauf mit "user" beginnt.
  assert.equal(input.at(-1).content, "neu");
  assert.equal(input[0].role, "user");
  assert.equal(input[0].content, "nachricht-6");
  assert.equal(input.at(-2).content, "nachricht-24");
  assert.ok(input.length <= 21);
  assert.ok(!JSON.stringify(input).includes("FREMDE-NACHRICHT"));
  assert.deepEqual([...new Set(input.map((m) => m.role))].sort(), ["assistant", "user"]);
});

test("Aufruf: Antwort wird als Op gespeichert (Frage und Antwort), nur für die Person, mit tag", async () => {
  const sql = db();
  const { fetchFn } = fakeModell("Antwort vom Coach.");
  const r = await frage(sql, "  Hallo Coach  ", { fetchFn });
  assert.equal(r.status, 200);
  const ops = alleOpsVon(sql, "ahmed", "coach.nachricht").reverse();
  assert.deepEqual(ops.map((o) => o.d), [
    { rolle: "du", text: "Hallo Coach", tag: HEUTE },
    { rolle: "coach", text: "Antwort vom Coach.", tag: HEUTE },
  ]);
  assert.equal(r.ops.length, 2, "zum Verteilen an die eigenen Geräte");
  assert.deepEqual(r.ops.map((o) => o.art), ["coach.nachricht", "coach.nachricht"]);
  assert.ok(r.ops.every((o) => o.von === "ahmed" && Number.isInteger(o.seq)));
  assert.equal(alleOpsVon(sql, "annika", "coach.nachricht").length, 0);
});

test("Aufruf: Schlüssel fehlt -> 503 nicht eingerichtet, kein Netzaufruf, nichts gespeichert, kein Zähler", async () => {
  const sql = db();
  const { fetchFn, calls } = fakeModell();
  for (const env of [{}, { OPENAI_API_KEY: "" }]) {
    const r = await frage(sql, "Hi", { env, fetchFn });
    assert.equal(r.status, 503);
    assert.deepEqual(r.body, { fehler: "nicht eingerichtet" });
  }
  assert.equal(calls.length, 0);
  assert.equal(alleOpsVon(sql, "ahmed", "coach.nachricht").length, 0);
  assert.equal(merkerLesen(sql, `coach.nutzung.ahmed.${HEUTE}`), null);
});

test("Aufruf: leere, falsche oder zu lange Frage -> 400 ohne Netzaufruf", async () => {
  const { fetchFn, calls } = fakeModell();
  for (const text of ["", "   ", undefined, 42, null, "x".repeat(2001)]) {
    const r = await frage(db(), text, { fetchFn });
    assert.equal(r.status, 400, String(text).slice(0, 10));
    assert.equal(typeof r.body.fehler, "string");
  }
  assert.equal(calls.length, 0);
});

// --- Deckel ------------------------------------------------------------------------------------------

test("Deckel: höchstens 30 Modell-Aufrufe je Person und Tag, danach 429; neuer Tag und Partner sind frei", async () => {
  const sql = db();
  const { fetchFn, calls } = fakeModell();
  await frage(sql, "eins", { fetchFn });
  assert.equal(merkerLesen(sql, `coach.nutzung.ahmed.${HEUTE}`), "1");
  merkerSchreiben(sql, `coach.nutzung.ahmed.${HEUTE}`, "29");
  assert.equal((await frage(sql, "dreißig", { fetchFn })).status, 200);
  const abgelehnt = await frage(sql, "einunddreißig", { fetchFn });
  assert.equal(abgelehnt.status, 429);
  assert.equal(typeof abgelehnt.body.fehler, "string");
  assert.equal(calls.length, 2, "der abgelehnte Aufruf geht nicht ans Modell");
  assert.equal(alleOpsVon(sql, "ahmed", "coach.nachricht").length, 4, "abgelehnte Frage wird nicht gespeichert");
  assert.equal((await frage(sql, "Annika", { person: "annika", fetchFn })).status, 200);
  assert.equal((await frage(sql, "morgen", { fetchFn, jetztMs: JETZT + 86_400_000 })).status, 200);
});

test("Deckel: auch fehlgeschlagene Modell-Aufrufe zählen (Schutz vor Wiederhol-Stürmen)", async () => {
  const sql = db();
  const kaputt = async () => new Response("RAW", { status: 500 });
  await frage(sql, "x", { fetchFn: kaputt });
  assert.equal(merkerLesen(sql, `coach.nutzung.ahmed.${HEUTE}`), "1");
});

// --- Fehler des Modells ------------------------------------------------------------------------------

test("Fehler: HTTP-Fehler des Modells -> 502 mit kurzer Meldung, ohne Roh-Antwort und ohne Schlüssel, nichts gespeichert", async () => {
  const sql = db();
  const fetchFn = async () => new Response(`RAW-FEHLER ${KEY} {"error":"kaputt"}`, { status: 500 });
  const r = await frage(sql, "Hi", { fetchFn });
  assert.equal(r.status, 502);
  assert.equal(typeof r.body.fehler, "string");
  const text = JSON.stringify(r);
  assert.ok(!text.includes("RAW-FEHLER") && !text.includes(KEY) && !text.includes("kaputt"));
  assert.equal(alleOpsVon(sql, "ahmed", "coach.nachricht").length, 0);
});

test("Fehler: Netzfehler und Fehlermeldung mit Schlüssel -> 502 ohne Schlüssel", async () => {
  const fetchFn = async () => {
    throw new Error(`connect failed bearer ${KEY}`);
  };
  const r = await frage(db(), "Hi", { fetchFn });
  assert.equal(r.status, 502);
  assert.ok(!JSON.stringify(r).includes(KEY));
});

test("Fehler: Zeitlimit -> 502", async () => {
  const fetchFn = (url, init) =>
    new Promise((_, reject) => init.signal.addEventListener("abort", () => reject(init.signal.reason ?? new Error("abgebrochen"))));
  // AbortSignal.timeout hält die Event-Loop nicht offen (Node 22: Test hängt "pending"); der Timer hält sie.
  const halten = setTimeout(() => {}, 2000);
  try {
    const r = await frage(db(), "Hi", { fetchFn, zeitlimitMs: 20 });
    assert.equal(r.status, 502);
    assert.equal(typeof r.body.fehler, "string");
  } finally {
    clearTimeout(halten);
  }
});

test("Fehler: Fehler beim Bauen des Kontexts (Katalog kaputt) -> 502 ohne Fehlertext und Schlüssel, kein Modellaufruf, nichts gespeichert", async () => {
  const sql = db();
  einheit(sql, "S1", "2026-10-06", [arbeitssatz(10, 60)]);
  const { fetchFn, calls } = fakeModell();
  const katalog = async () => {
    throw new Error(`Katalog kaputt ${KEY}`);
  };
  const r = await frage(sql, "Hi", { fetchFn, katalog });
  assert.equal(r.status, 502);
  assert.equal(typeof r.body.fehler, "string");
  assert.ok(!JSON.stringify(r).includes(KEY) && !JSON.stringify(r).includes("Katalog kaputt"));
  assert.equal(calls.length, 0);
  assert.equal(alleOpsVon(sql, "ahmed", "coach.nachricht").length, 0);

  einstellung(sql, "coach.morgen", "1");
  const m = await morgen(sql, { fetchFn, katalog });
  assert.equal(m.gesendet, false, "Morgen-Nachricht wirft nicht, der Tag ist markiert");
});

test("Fehler: unvollständige, leere oder verweigerte Antwort -> 502, nichts gespeichert", async () => {
  const antworten = [
    { status: "incomplete", incomplete_details: { reason: "max_output_tokens" }, output: [{ type: "reasoning", summary: [] }] },
    { status: "completed", output: [{ type: "message", role: "assistant", content: [{ type: "output_text", text: "   " }] }] },
    { status: "completed", output: [{ type: "message", role: "assistant", content: [{ type: "refusal", refusal: "nein" }] }] },
    { status: "failed", error: { message: "INTERN-DETAIL" }, output: [] },
    { status: "completed", output: [] },
  ];
  for (const antwort of antworten) {
    const sql = db();
    const fetchFn = async () => new Response(JSON.stringify(antwort), { status: 200 });
    const r = await frage(sql, "Hi", { fetchFn });
    assert.equal(r.status, 502, JSON.stringify(antwort).slice(0, 40));
    assert.ok(!JSON.stringify(r).includes("INTERN-DETAIL"));
    assert.equal(alleOpsVon(sql, "ahmed", "coach.nachricht").length, 0);
  }
});

test("Fehler: kein JSON vom Modell -> 502", async () => {
  const fetchFn = async () => new Response("<html>Gateway</html>", { status: 200 });
  assert.equal((await frage(db(), "Hi", { fetchFn })).status, 502);
});

test("Antwort: mehrere Textteile werden verbunden, auch nach Tool- oder Reasoning-Items", async () => {
  const antwort = {
    status: "completed",
    output: [
      { type: "reasoning", summary: [] },
      { type: "message", role: "assistant", content: [{ type: "output_text", text: "Teil eins." }, { type: "output_text", text: "Teil zwei." }] },
    ],
  };
  const fetchFn = async () => new Response(JSON.stringify(antwort), { status: 200 });
  const r = await frage(db(), "Hi", { fetchFn });
  assert.equal(r.body.text, "Teil eins.\nTeil zwei.");
});

// --- Anweisung ---------------------------------------------------------------------------------------

test("Anweisung: enthält die festen Sicherheitsregeln", () => {
  for (const muster of [/Untergrenze/, /nie .*gut.* oder .*schlecht/i, /Arzt/, /Diagnose/, /erfinden/, /Streak/i, /Druck/, /essenLueckig/, /sehrWenigGegessen/]) {
    assert.match(ANWEISUNG, muster);
  }
  assert.ok(ANWEISUNG.length < 4000, "kurz halten");
});

// --- Morgen-Nachricht ---------------------------------------------------------------------------------

const morgen = (sql, opts = {}) =>
  coachMorgen({ sql, env: ENV, person: "ahmed", jetztMs: JETZT - 3 * 3_600_000, katalog: KATALOG, neueId, ...opts }); // 09:00 Berlin

test("Morgen: coachMorgenAn nur bei coach.morgen = \"1\" (neueste Einstellung gewinnt)", () => {
  const sql = db();
  assert.equal(coachMorgenAn(sql, "ahmed"), false);
  einstellung(sql, "coach.morgen", "1");
  assert.equal(coachMorgenAn(sql, "ahmed"), true);
  assert.equal(coachMorgenAn(sql, "annika"), false);
  einstellung(sql, "coach.morgen", "0");
  assert.equal(coachMorgenAn(sql, "ahmed"), false);
});

test("Morgen: ohne Opt-in kein Aufruf; mit Opt-in genau eine Coach-Nachricht pro Person und Tag", async () => {
  const sql = db();
  const { fetchFn, calls } = fakeModell("Guten Morgen, hier dein Bericht.");
  assert.equal((await morgen(sql, { fetchFn })).gesendet, false);
  assert.equal(calls.length, 0);

  einstellung(sql, "coach.morgen", "1");
  const r = await morgen(sql, { fetchFn });
  assert.equal(r.gesendet, true);
  assert.equal(calls.length, 1);
  const ops = alleOpsVon(sql, "ahmed", "coach.nachricht");
  assert.equal(ops.length, 1, "keine Nutzer-Frage, nur die Nachricht des Coachs");
  assert.deepEqual(ops[0].d, { rolle: "coach", text: "Guten Morgen, hier dein Bericht.", tag: HEUTE });
  assert.equal(r.ops.length, 1);
  assert.equal(calls[0].body.input.at(-1).role, "user", "der Auslöser ist ein Nutzer-Eintrag, wird aber nicht gespeichert");

  assert.equal((await morgen(sql, { fetchFn })).gesendet, false, "zweites Mal am selben Tag nicht");
  assert.equal(calls.length, 1);
  assert.equal((await morgen(sql, { fetchFn, jetztMs: JETZT + 86_400_000 - 3 * 3_600_000 })).gesendet, true, "nächster Tag wieder");
});

test("Morgen: ohne Schlüssel nichts; Fehler des Modells markiert den Tag trotzdem (keine Alarm-Schleife)", async () => {
  const sql = db();
  einstellung(sql, "coach.morgen", "1");
  const { fetchFn, calls } = fakeModell();
  assert.equal((await morgen(sql, { fetchFn, env: {} })).gesendet, false);
  assert.equal(calls.length, 0);

  const kaputt = async () => new Response("x", { status: 500 });
  assert.equal((await morgen(sql, { fetchFn: kaputt })).gesendet, false);
  assert.equal(alleOpsVon(sql, "ahmed", "coach.nachricht").length, 0);
  assert.equal((await morgen(sql, { fetchFn })).gesendet, false, "heute schon versucht");
  assert.equal(calls.length, 0);
});

test("Morgen: zählt zum Tageslimit und hält es ein", async () => {
  const sql = db();
  einstellung(sql, "coach.morgen", "1");
  merkerSchreiben(sql, `coach.nutzung.ahmed.${HEUTE}`, "30");
  const { fetchFn, calls } = fakeModell();
  assert.equal((await morgen(sql, { fetchFn })).gesendet, false);
  assert.equal(calls.length, 0);
});

test("Morgen: nach 12 Uhr Berlin keine verspätete Morgen-Nachricht, der Tag gilt als erledigt", async () => {
  const sql = db();
  einstellung(sql, "coach.morgen", "1");
  const { fetchFn, calls } = fakeModell();
  const r = await morgen(sql, { fetchFn, jetztMs: Date.parse("2026-10-08T14:00:00Z") }); // 16:00 Berlin
  assert.equal(r.gesendet, false);
  assert.equal(calls.length, 0);
  assert.equal((await morgen(sql, { fetchFn })).gesendet, false);
});
