// Lovea-Coach (Health-Tab): baut aus den EIGENEN Ops einer Person einen kurzen Kontext, fragt das Modell
// (OpenAI Responses API) und speichert Frage und Antwort als `coach.nachricht` (nur für den Absender).
// Rein: ohne Cloudflare-Import, `fetch` und Zeit kommen von außen. Der Schlüssel steht nur im
// Authorization-Header und wird nie geloggt, gespeichert oder in eine Antwort geschrieben.
//
// Datenschutz: gelesen werden NUR essen.setzen, habit.setzen (gewicht), schritte.setzen, schlaf.*, gym.*,
// einstellung.setzen und coach.nachricht -- jeweils mit `von = Person`. Nie Chat (nachricht.*), Zyklus,
// Standort, Galerie, Entwürfe oder Daten des Partners.
// Ausnahme `gesundheit`: Apple-Health- und Tracker-Zahlen kommen im Body der Frage von der App der Person selbst (nie aus
// Ops, nie vom Partner), nur aus festen Schlüsseln und nur als Zahlen (`gesundheitBereinigen`).
import * as gym from "./gym.js";
import { anweisungBauen } from "./coach-anweisung.js";
import { opEinfuegen, merkerLesen, merkerSchreiben, einstellung, alarmErledigt, alarmAlsErledigtMarkieren, zeileZuOp } from "./raum-logic.js";

const API_URL = "https://api.openai.com/v1/responses";
const STANDARD_MODELL = "gpt-6-luna";
const MAX_AUSGABE_TOKEN = 1200; // zählt Reasoning-Token mit
const MARKER_EXTRA_TOKEN = 300; // nur mit Marker-Flag: die Marker-Zeilen kosten Ausgabe-Token aus demselben Budget
const MAX_ZIEL = 200; // Zeichen des eigenen Ziel-Texts (coach.ziel) im Kontext
const ZEITLIMIT_MS = 25_000;
const TAGESLIMIT = 30; // Modell-Aufrufe je Person und Tag
const VERLAUF = 20; // letzte Nachrichten ans Modell
const MAX_FRAGE = 2000;
const MIN_TAGE_IM_LOG = 10; // von 14 Tagen: darunter ist das Essens-Log lückenhaft
const KONTEXT_MAX = 16_000; // Zeichen, rund 4.000 Token
const MORGEN_BIS_STUNDE = 12; // danach keine verspätete Morgen-Nachricht mehr
const PERSON_NAME = { ahmed: "Ahmed", annika: "Annika" };

const MORGEN_AUSLOESER = "Schreib mir meinen Tagesbericht für heute Morgen: kurz, was zuletzt gut lief, und höchstens ein kleiner Schritt für heute.";

const berlinUhr = new Intl.DateTimeFormat("en-GB", { timeZone: "Europe/Berlin", hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
const berlinWochentag = new Intl.DateTimeFormat("de-DE", { timeZone: "Europe/Berlin", weekday: "long" });

const datumVon = (ms) => gym.datumText(new Date(ms));
const runden = (x, n = 0) => Math.round(x * 10 ** n) / 10 ** n;
const mittel = (liste) => (liste.length ? liste.reduce((a, b) => a + b, 0) / liste.length : null);
const zahl = (x) => (typeof x === "number" && Number.isFinite(x) ? x : null);

function minuteImTag(ms) {
  const [h, m] = berlinUhr.format(new Date(ms)).split(":").map(Number);
  return h * 60 + m;
}

// --- Lesen (alles mit von = Person, begrenzt über den Index ops_art_von_zeit) ------------------------

/** Ops einer Art ab einem Datum (nach `zeit`), älteste zuerst. */
function opsAb(sql, person, art, abDatum, nur = "") {
  return sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE art = ? AND von = ? AND zeit >= ? ${nur} ORDER BY seq ASC`, art, person, abDatum)
    .toArray()
    .map(zeileZuOp);
}

/** Je Tag gewinnt die Op mit der höchsten seq (habit.setzen, schritte.setzen, schlaf.*). */
function jeTagLetzte(ops) {
  const nachTag = new Map();
  for (const op of ops) if (typeof op.d?.datum === "string") nachTag.set(op.d.datum, op);
  return nachTag;
}

// --- Essen -------------------------------------------------------------------------------------------

function gramm(e) {
  const menge = zahl(e.menge) ?? 0;
  const lm = e.lebensmittel ?? {};
  if (e.einheit === "portion") return menge * (lm.portionMenge ?? 100);
  if (e.einheit === "packung") return menge * (lm.packungMenge ?? lm.portionMenge ?? 100);
  return menge; // g und ml 1:1
}

/** Essen wie die App faltet: je id gewinnt die Op mit der neuesten `zeit` (Gleichstand: die später angekommene). */
function essenFalten(ops) {
  const nachId = new Map();
  for (const op of ops) {
    const d = op.d;
    if (!d?.id || typeof d.datum !== "string") continue;
    const alt = nachId.get(d.id);
    const zeit = Date.parse(op.zeit);
    if (!alt || zeit >= alt.zeit) nachId.set(d.id, { zeit, d });
  }
  return [...nachId.values()].map((x) => x.d).filter((d) => d.geloescht !== true);
}

function essenTag(eintraege) {
  let kcal = 0;
  let protein = 0;
  const liste = eintraege.map((e) => {
    const g = gramm(e);
    const p100 = e.lebensmittel?.pro100 ?? {};
    const k = ((zahl(p100.kcal) ?? 0) * g) / 100;
    const p = ((zahl(p100.protein) ?? 0) * g) / 100;
    kcal += k;
    protein += p;
    return { name: String(e.lebensmittel?.name ?? "").slice(0, 40), mahlzeit: e.mahlzeit, gramm: runden(g), kcal: runden(k), protein: runden(p) };
  });
  return { kcal: runden(kcal), protein: runden(protein), eintraege: liste.slice(0, 12) };
}

function essenKontext(sql, person, heute) {
  const eintraege = essenFalten(opsAb(sql, person, "essen.setzen", gym.addTage(heute, -32)));
  const nachTag = new Map();
  for (const e of eintraege) nachTag.set(e.datum, [...(nachTag.get(e.datum) ?? []), e]);
  const jeTag = [];
  for (let i = 14; i >= 1; i--) {
    const datum = gym.addTage(heute, -i);
    const t = essenTag(nachTag.get(datum) ?? []);
    if (t.kcal > 0) jeTag.push({ datum, kcal: t.kcal, protein: t.protein }); // nur Tage mit echten Kalorien zählen als geloggt
  }
  const gestern = gym.addTage(heute, -1);
  const tageMitEintraegen = jeTag.length;
  const schnittKcal = tageMitEintraegen ? runden(mittel(jeTag.map((t) => t.kcal))) : null;
  if (tageMitEintraegen < MIN_TAGE_IM_LOG) {
    // Wer selten trackt, isst nicht wenig: Teiltage würden als Aufnahme gelesen. Dem Modell keine Mengen zeigen.
    return {
      tageMitEintraegen,
      schnittKcal,
      essen: {
        letzte14Tage: { tageGeprueft: 14, tageMitEintraegen },
        hinweis: "Essens-Log lückenhaft: Die Person trackt nur selten. Mengen sind keine Aufnahme und werden deshalb nicht gezeigt. Nichts daraus schließen.",
      },
    };
  }
  return {
    tageMitEintraegen,
    schnittKcal,
    essen: {
      letzte14Tage: {
        tageGeprueft: 14,
        tageMitEintraegen,
        schnittKcal,
        schnittProtein: runden(mittel(jeTag.map((t) => t.protein))),
      },
      jeTag,
      gestern: { datum: gestern, ...essenTag(nachTag.get(gestern) ?? []) },
      heute: { datum: heute, ...essenTag(nachTag.get(heute) ?? []) },
    },
  };
}

// --- Ziele, Gewicht, Schritte, Schlaf ------------------------------------------------------------------

function einstellungenLesen(sql, person) {
  const werte = {};
  // neueste zuerst: der erste Treffer je Schlüssel gilt
  for (const op of sql.exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE art = 'einstellung.setzen' AND von = ? ORDER BY seq DESC`, person).toArray().map(zeileZuOp)) {
    const k = op.d?.schluessel;
    if (typeof k === "string" && !(k in werte)) werte[k] = op.d.wert;
  }
  return werte;
}

const RICHTUNG = ["abnehmen", "halten", "zunehmen"];

function zieleKontext(werte) {
  const z = {
    richtung: RICHTUNG[werte["ziel.ernaehrung.richtung"]],
    tempoGProWoche: zahl(werte["ziel.ernaehrung.tempo"]) ?? undefined,
    kcal: zahl(werte["ziel.ernaehrung.kcal"]) ?? undefined,
    protein: zahl(werte["ziel.ernaehrung.protein"]) ?? undefined,
    alter: zahl(werte["ziel.ernaehrung.alter"]) ?? undefined,
    groesseCm: zahl(werte["ziel.ernaehrung.groesseCm"]) ?? undefined,
    aktivitaet: zahl(werte["ziel.ernaehrung.aktivitaet"]) ?? undefined,
    schritte: zahl(werte["ziel.schritte"]) ?? undefined,
    schlafMinuten: zahl(werte["ziel.schlaf.minuten"]) ?? undefined,
  };
  return Object.fromEntries(Object.entries(z).filter(([, v]) => v !== undefined));
}

function gewichtKontext(sql, person, heute) {
  const ab = gym.addTage(heute, -60);
  const ops = opsAb(sql, person, "habit.setzen", gym.addTage(heute, -90), `AND d LIKE '%"gewicht"%'`).filter((op) => op.d.art === "gewicht" && op.d.datum >= ab && op.d.datum <= heute);
  const verlauf = [...jeTagLetzte(ops)]
    .filter(([, op]) => zahl(op.d.wert) > 0) // 0 = kein Wert; Zehntel kg
    .map(([datum, op]) => ({ datum, kg: op.d.wert / 10 }))
    .sort((a, b) => a.datum.localeCompare(b.datum));
  if (!verlauf.length) return undefined;
  const letzte = verlauf.at(-1);
  return { aktuellKg: letzte.kg, datum: letzte.datum, verlauf: verlauf.slice(-14) };
}

function schritteKontext(sql, person, heute) {
  const tage = jeTagLetzte(opsAb(sql, person, "schritte.setzen", gym.addTage(heute, -14)));
  const wert = (datum) => (zahl(tage.get(datum)?.d.anzahl) > 0 ? tage.get(datum).d.anzahl : null);
  const letzte7 = [];
  for (let i = 7; i >= 1; i--) {
    const datum = gym.addTage(heute, -i);
    if (wert(datum) !== null) letzte7.push({ datum, anzahl: wert(datum) });
  }
  const heuteWert = wert(heute);
  if (!letzte7.length && heuteWert === null) return undefined;
  return { heute: heuteWert, letzte7, schnitt: letzte7.length ? runden(mittel(letzte7.map((x) => x.anzahl))) : null };
}

/** Schlafminuten wie die App: eigener Eintrag (schlaf.zeiten, Apple-Zeit, Berliner Uhr) schlägt die Automatik, 0 = gelöscht. */
function schlafKontext(sql, person, heute) {
  const ab = gym.addTage(heute, -14);
  const auto = jeTagLetzte(opsAb(sql, person, "schlaf.setzen", ab));
  const eigen = jeTagLetzte(opsAb(sql, person, "schlaf.zeiten", ab));
  const letzte7 = [];
  for (let i = 6; i >= 0; i--) {
    const datum = gym.addTage(heute, -i);
    let minuten = zahl(auto.get(datum)?.d.minuten);
    const z = eigen.get(datum)?.d;
    if (z && zahl(z.bett) !== null && zahl(z.auf) !== null) {
      const ms = (s) => (s + 978307200) * 1000;
      const diff = (((minuteImTag(ms(z.auf)) - minuteImTag(ms(z.bett))) % 1440) + 1440) % 1440;
      minuten = diff; // 0 sperrt auch die Automatik
    }
    if (minuten > 0) letzte7.push({ datum, minuten });
  }
  if (!letzte7.length) return undefined;
  return { letzte7, schnittMinuten: runden(mittel(letzte7.map((x) => x.minuten))) };
}

// --- Training (gym.js) ------------------------------------------------------------------------------------

async function trainingKontext(sql, person, jetztMs, heute, werte, katalog) {
  const fenster = sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE art >= 'gym.' AND art < 'gym/' AND von = ? AND zeit >= ? ORDER BY seq ASC`, person, gym.addTage(heute, -70))
    .toArray()
    .map(zeileZuOp);
  if (!fenster.some((op) => op.art !== "gym.plan")) return undefined; // kein Training, kein Block
  const plaene = sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE art = 'gym.plan' AND von = ? ORDER BY seq DESC LIMIT 20`, person)
    .toArray()
    .map(zeileZuOp);
  const gesehen = new Set(fenster.map((op) => op.seq));
  const ops = [...plaene.filter((op) => !gesehen.has(op.seq)).reverse(), ...fenster];
  const stand = gym.falten(ops);
  if (!stand.sessions.length) return undefined;
  const kat = typeof katalog === "function" ? await katalog() : katalog;
  const zahlen = {};
  for (const [k, v] of Object.entries(werte)) if (k.startsWith("ziel.") && typeof v === "number") zahlen[k] = v;
  const a = gym.auswerten(stand, kat, { jetzt: new Date(jetztMs), wochen: 8, ziel: gym.ziele(zahlen, person) });
  const erholung = Object.fromEntries(Object.entries(a.erholung).filter(([, e]) => e.tageSeitTraining != null).map(([g, e]) => [g, { stufe: e.stufe, tageSeitTraining: e.tageSeitTraining }]));
  return {
    trainings8Wochen: a.trainings,
    saetzeJeGruppe: a.saetzeJeGruppe,
    erholung,
    planTage: a.planTreue.map((t) => ({ tag: t.tag, wochentage: t.wochentage })),
    letzteEinheiten: stand.sessions.slice(0, 4).map((x) => gym.sessionLesbar(x, kat, stand.tagNamen)),
    uebungen: a.uebungen.slice(0, 8).map((u) => ({ id: u.id, name: u.name, muskel: u.muskel, einheiten: u.einheiten, zuletzt: u.zuletzt[0], plateau: u.plateau, naechstesMal: u.naechstesMal })),
  };
}

// --- Gesundheit (Apple Health + Tracker, aus dem Body der Frage) ----------------------------------------------

const G_TAG = ["schritteHealth", "km", "etagen", "aktivKcal", "ruheKcal", "trainingMin", "stehMin", "pulsSchnitt", "pulsMin", "pulsMax", "ruhepuls", "gehpuls", "hrv", "spo2", "atemfrequenz", "vo2max", "gewichtKg", "koerperfett", "schlafMin"];
const G_BAND_TAG = ["schritte", "meter", "slots", "letzteMinute"];
const G_BAND = ["akku", "pulsIntervallMin", "letzteAbfrageVorMin"];
const G_BAND_FLAGS = ["laedt", "pulsDauermessung"];
const G_TAGE = 8; // heute und die 7 Tage davor
const G_WORKOUT_TAGE = 14;
const G_WORKOUTS = 10;
const DATUM_FORM = /^\d{4}-\d{2}-\d{2}$/;
const WORKOUT_ART = /^\p{L}[\p{L} -]{0,29}$/u;

const gZahl = (x) => (zahl(x) !== null && Math.abs(x) < 1e7 ? runden(x, 2) : null);

function nurZahlen(roh, schluessel) {
  const aus = {};
  if (roh && typeof roh === "object") for (const s of schluessel) if (gZahl(roh[s]) !== null) aus[s] = gZahl(roh[s]);
  return aus;
}

/** Zahlen je Tag aus festen Schlüsseln; Tage außerhalb von [ab, heute] und Schlüssel außerhalb der Liste fallen weg. */
function tageBereinigen(roh, schluessel, ab, heute) {
  const aus = {};
  for (const [datum, werte] of Object.entries(roh && typeof roh === "object" ? roh : {})) {
    if (!DATUM_FORM.test(datum) || datum < ab || datum > heute) continue;
    const w = nurZahlen(werte, schluessel);
    if (Object.keys(w).length) aus[datum] = w;
  }
  return aus;
}

/**
 * Macht aus dem Body-Feld `gesundheit` der App einen kleinen, sicheren Kontext-Block: nur Zahlen aus festen Schlüsseln,
 * Daten im Fenster, Workout-Namen nur als kurzes Wort. Freier Text kommt nie durch. `undefined`, wenn nichts übrig bleibt.
 */
export function gesundheitBereinigen(roh, heute) {
  if (!roh || typeof roh !== "object" || Array.isArray(roh)) return undefined;
  const g = {};
  const ab = gym.addTage(heute, -(G_TAGE - 1));
  const tage = tageBereinigen(roh.tage, G_TAG, ab, heute);
  if (Object.keys(tage).length) g.tage = tage;
  const abWorkout = gym.addTage(heute, -(G_WORKOUT_TAGE - 1));
  const workouts = (Array.isArray(roh.workouts) ? roh.workouts : [])
    .filter((w) => w && typeof w === "object" && typeof w.art === "string" && WORKOUT_ART.test(w.art) && typeof w.datum === "string" && DATUM_FORM.test(w.datum) && w.datum >= abWorkout && w.datum <= heute)
    .map((w) => ({ art: w.art, datum: w.datum, ...nurZahlen(w, ["minuten", "kcal", "km"]) }))
    .sort((a, b) => (a.datum < b.datum ? 1 : -1))
    .slice(0, G_WORKOUTS);
  if (workouts.length) g.workouts = workouts;
  const band = roh.band && typeof roh.band === "object" && !Array.isArray(roh.band) ? roh.band : null;
  if (band) {
    const b = nurZahlen(band, G_BAND);
    for (const f of G_BAND_FLAGS) if (typeof band[f] === "boolean") b[f] = band[f];
    const bandTage = tageBereinigen(band.tage, G_BAND_TAG, ab, heute);
    if (Object.keys(bandTage).length) b.tage = bandTage;
    if (Object.keys(b).length) g.band = b;
  }
  return Object.keys(g).length ? g : undefined;
}

// --- Kontext ------------------------------------------------------------------------------------------------

/** Kürzt in fester Reihenfolge, bis der Kontext unter dem Limit liegt. */
function begrenzen(k) {
  const stufen = [
    () => k.training?.letzteEinheiten.length > 1 && k.training.letzteEinheiten.pop(),
    () => k.training?.uebungen.length > 3 && k.training.uebungen.pop(),
    () => k.essen.gestern?.eintraege.length > 4 && k.essen.gestern.eintraege.pop(),
    () => k.essen.heute?.eintraege.length > 6 && k.essen.heute.eintraege.pop(),
    () => k.gewicht?.verlauf.length > 4 && k.gewicht.verlauf.shift(),
    () => k.essen.jeTag?.length > 7 && k.essen.jeTag.shift(),
    () => k.gesundheit?.workouts?.length > 3 && k.gesundheit.workouts.pop(),
    () => k.gesundheit?.tage && Object.keys(k.gesundheit.tage).length > 3 && delete k.gesundheit.tage[Object.keys(k.gesundheit.tage).sort()[0]],
  ];
  for (const stufe of stufen) while (JSON.stringify(k).length > KONTEXT_MAX && stufe()) ;
  return k;
}

/** Eigene Daten der Person als kurzes JSON für das Modell. Sicherheits-Merker rechnet der Code, nicht das Modell. */
export async function coachKontext(sql, person, jetztMs, { katalog, gesundheit } = {}) {
  const heute = datumVon(jetztMs);
  const werte = einstellungenLesen(sql, person);
  const { tageMitEintraegen, schnittKcal, essen } = essenKontext(sql, person, heute);
  const geschlecht = werte["ziel.ernaehrung.geschlecht"];
  const frau = geschlecht === 1 || (geschlecht !== 0 && person === "annika");
  const kcalUntergrenze = frau ? 1200 : 1500;
  const k = {
    heute,
    wochentag: berlinWochentag.format(new Date(jetztMs)),
    person: PERSON_NAME[person] ?? person,
    sicherheit: {
      kcalUntergrenze,
      essenLueckig: tageMitEintraegen < MIN_TAGE_IM_LOG,
      essenTageMitEintraegen: tageMitEintraegen,
      // Nur bei brauchbarem Log: wer selten trackt, hat keine Aufnahme, die man bewerten könnte.
      sehrWenigGegessen: tageMitEintraegen >= MIN_TAGE_IM_LOG && schnittKcal < kcalUntergrenze,
    },
    ziele: zieleKontext(werte),
    essen,
    gewicht: gewichtKontext(sql, person, heute),
    schritte: schritteKontext(sql, person, heute),
    schlaf: schlafKontext(sql, person, heute),
    training: await trainingKontext(sql, person, jetztMs, heute, werte, katalog),
  };
  const g = gesundheitBereinigen(gesundheit, heute);
  if (g) k.gesundheit = g;
  return begrenzen(k);
}

// --- Zusätze: Marker-Flag, Ton, eigenes Ziel --------------------------------------------------------------------

/** Opt-in der neuen App: Body-Feld `marker` = true, 1 oder "1". Alles andere (auch "0", false, fehlt) = aus. */
export const markerAn = (flag) => flag === true || flag === 1 || flag === "1";

/** Eigenes Ziel (`coach.ziel`) als sichere Einzeile: Umbrüche zu Leerzeichen, nie `[[`/`]]` (sonst könnte es einen Marker fälschen), höchstens 200 Zeichen. */
export function zielBereinigen(wert) {
  if (typeof wert !== "string") return "";
  let t = wert;
  while (/\[\[|\]\]/.test(t)) t = t.replace(/\[\[|\]\]/g, ""); // Schleife: das Entfernen kann aus "[[[]][" ein neues "[[" machen
  return [...t.replace(/\s+/g, " ").trim()].slice(0, MAX_ZIEL).join("").trim();
}

/** Mit Marker-Flag: ein am Ende offener Marker (`[[` ohne `]]` danach) ist halb und fliegt raus. Vollständige Marker bleiben unberührt. */
export const halbeMarkerEntfernen = (text) => text.replace(/\[\[(?:(?!\]\]).)*$/s, "").trim();

// --- Verlauf, Zähler, Modell -----------------------------------------------------------------------------

function verlauf(sql, person) {
  const nachrichten = sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE art = 'coach.nachricht' AND von = ? ORDER BY seq DESC LIMIT ?`, person, VERLAUF)
    .toArray()
    .map(zeileZuOp)
    .reverse()
    .filter((op) => typeof op.d?.text === "string" && (op.d.rolle === "du" || op.d.rolle === "coach"))
    .map((op) => ({ role: op.d.rolle === "du" ? "user" : "assistant", content: op.d.text.slice(0, MAX_FRAGE) }));
  while (nachrichten.length && nachrichten[0].role !== "user") nachrichten.shift(); // der Verlauf beginnt mit einer Frage
  return nachrichten;
}

const nutzungsSchluessel = (person, datum) => `coach.nutzung.${person}.${datum}`;

/** Zählt einen Modell-Aufruf mit. false = Tageslimit erreicht. Gezählt wird vor dem Aufruf, auch Fehlschläge. */
function aufrufZaehlen(sql, person, datum) {
  const schluessel = nutzungsSchluessel(person, datum);
  const bisher = Number(merkerLesen(sql, schluessel) ?? 0) || 0;
  if (bisher >= TAGESLIMIT) return false;
  merkerSchreiben(sql, schluessel, String(bisher + 1));
  return true;
}

const fehler = (status, meldung, grund) => ({ status, body: { fehler: meldung }, grund });
const NICHT_ERREICHBAR = "Der Coach ist gerade nicht erreichbar.";

/** Antworttext der Responses API: alle output_text-Teile aller message-Items (Reasoning-Items stehen davor, nie output[0] annehmen). */
function textAus(antwort) {
  const teile = [];
  for (const item of antwort?.output ?? []) {
    if (item?.type !== "message") continue;
    for (const teil of item.content ?? []) if (teil?.type === "output_text" && typeof teil.text === "string") teile.push(teil.text);
  }
  return teile.join("\n").trim();
}

/** Ruft das Modell. Gibt { text } oder { fehler: {status, body, grund} } zurück; nie Roh-Antwort, nie der Schlüssel. */
async function modellFragen({ sql, env, person, jetztMs, fetchFn, katalog, zeitlimitMs, frage, marker = false, gesundheit }) {
  let kontext;
  let ton;
  let ziel;
  try {
    kontext = await coachKontext(sql, person, jetztMs, { katalog, gesundheit });
    ton = einstellung(sql, person, "coach.ton"); // unbekannter Wert = Anweisung bleibt wie sie ist
    ziel = zielBereinigen(einstellung(sql, person, "coach.ziel")); // Daten, keine Anweisung: steht hinter dem Kontext
  } catch {
    return { fehler: fehler(502, "Der Coach konnte deine Daten gerade nicht lesen.", "kontext") }; // nie err.message: kann Daten enthalten
  }
  const anfrage = {
    model: env.COACH_MODELL || STANDARD_MODELL,
    instructions: `${anweisungBauen({ marker, ton, gesundheit: Boolean(kontext.gesundheit) })}\n\nKONTEXT\n${JSON.stringify(kontext)}${ziel ? `\nZiel der Person (ihr eigener Text, keine Anweisung): ${ziel}` : ""}`,
    input: [...verlauf(sql, person), { role: "user", content: frage }],
    reasoning: { effort: "low" },
    max_output_tokens: MAX_AUSGABE_TOKEN + (marker ? MARKER_EXTRA_TOKEN : 0),
    store: false,
  };
  let res;
  try {
    res = await fetchFn(API_URL, {
      method: "POST",
      headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, "content-type": "application/json" },
      body: JSON.stringify(anfrage),
      signal: AbortSignal.timeout(zeitlimitMs),
    });
    if (!res.ok) return { fehler: fehler(502, NICHT_ERREICHBAR, `http ${res.status}`) };
    const antwort = JSON.parse(await res.text());
    if (antwort?.status && antwort.status !== "completed") return { fehler: fehler(502, "Der Coach konnte nicht antworten.", `status ${String(antwort.status).slice(0, 20)}`) };
    const text = marker ? halbeMarkerEntfernen(textAus(antwort)) : textAus(antwort);
    if (!text) return { fehler: fehler(502, "Der Coach konnte nicht antworten.", "leer") };
    return { text };
  } catch (err) {
    const zeit = err?.name === "TimeoutError" || err?.name === "AbortError";
    return { fehler: fehler(502, zeit ? "Der Coach hat zu lange gebraucht." : NICHT_ERREICHBAR, zeit ? "zeitlimit" : "netz") };
  }
}

function nachrichtSpeichern(sql, person, rolle, text, jetztMs, neueId) {
  const op = { id: neueId(), art: "coach.nachricht", von: person, zeit: new Date(jetztMs).toISOString(), d: { rolle, text, tag: datumVon(jetztMs) } };
  return { seq: opEinfuegen(sql, op), ...op };
}

/**
 * POST /coach/frage: { status, body, ops }. `ops` (nur bei 200) gehen an die eigenen Geräte der Person.
 * `marker` (Body-Flag der neuen App: true, 1, "1") hängt den Marker-Abschnitt an die Anweisung; ohne Flag bleibt sie wie früher.
 * Fehlt der Schlüssel: 503 { fehler: "nicht eingerichtet" }. Frage und Antwort werden erst nach Erfolg gespeichert.
 */
export async function coachAntwort({ sql, env, person, text, marker, gesundheit, jetztMs, fetchFn = fetch, katalog, neueId = () => crypto.randomUUID(), zeitlimitMs = ZEITLIMIT_MS }) {
  if (!env?.OPENAI_API_KEY) return { status: 503, body: { fehler: "nicht eingerichtet" } };
  const frage = typeof text === "string" ? text.trim() : "";
  if (!frage || frage.length > MAX_FRAGE) return { status: 400, body: { fehler: `Frage fehlt oder ist zu lang (höchstens ${MAX_FRAGE} Zeichen)` } };
  if (!aufrufZaehlen(sql, person, datumVon(jetztMs))) return { status: 429, body: { fehler: "Tageslimit des Coachs erreicht, morgen geht es weiter." } };
  const r = await modellFragen({ sql, env, person, jetztMs, fetchFn, katalog, zeitlimitMs, frage, marker: markerAn(marker), gesundheit });
  if (r.fehler) return r.fehler;
  const ops = [nachrichtSpeichern(sql, person, "du", frage, jetztMs, neueId), nachrichtSpeichern(sql, person, "coach", r.text, jetztMs + 1, neueId)];
  return { status: 200, body: { text: r.text }, ops };
}

// --- Morgen-Nachricht (Opt-in) -------------------------------------------------------------------------------

/** Opt-in: `einstellung.setzen` `coach.morgen` = "1" (neueste Einstellung gewinnt). */
export const coachMorgenAn = (sql, person) => einstellung(sql, person, "coach.morgen") === "1";

/**
 * Schreibt die Morgen-Nachricht des Coachs (nur die Antwort, keine gespeicherte Frage). Einmal je Person und Tag:
 * der Tag wird VOR der Arbeit markiert, ein Fehler löst also keine Alarm-Schleife aus. Nach 12 Uhr Berlin
 * kommt keine verspätete Nachricht mehr. { gesendet, ops }.
 */
export async function coachMorgen({ sql, env, person, jetztMs, fetchFn = fetch, katalog, neueId = () => crypto.randomUUID(), zeitlimitMs = ZEITLIMIT_MS }) {
  if (!env?.OPENAI_API_KEY || !coachMorgenAn(sql, person)) return { gesendet: false };
  const datum = datumVon(jetztMs);
  const schluessel = `${person}.${datum}`;
  if (alarmErledigt(sql, "coachMorgen", schluessel)) return { gesendet: false };
  alarmAlsErledigtMarkieren(sql, "coachMorgen", schluessel, new Date(jetztMs).toISOString());
  if (minuteImTag(jetztMs) >= MORGEN_BIS_STUNDE * 60) return { gesendet: false };
  if (!aufrufZaehlen(sql, person, datum)) return { gesendet: false };
  const r = await modellFragen({ sql, env, person, jetztMs, fetchFn, katalog, zeitlimitMs, frage: MORGEN_AUSLOESER });
  if (r.fehler) return { gesendet: false, grund: r.fehler.grund };
  return { gesendet: true, ops: [nachrichtSpeichern(sql, person, "coach", r.text, jetztMs, neueId)] };
}
