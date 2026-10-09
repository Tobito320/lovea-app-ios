// Gym-Auswertung für den MCP-Server (mcp.mjs): faltet gym.*-Ops zu Einheiten wie TrainingLogik.sessions
// (Lovea/Sources/Health/Training.swift), rechnet Sätze je Muskel, Erholung, e1RM, Plateaus, Plantreue
// und prüft Pläne vor dem Schreiben. Rein, ohne Netz: die Ops und Kataloge kommen von außen.
// Erholung und Sätze wie MuskelLogik (Koerper/Muskeln.swift), Abbau nach Pause und Kraftverhältnisse
// nach openGym (DuarteSantos8/openGym, recovery.js und structuralBalance.js).
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { randomUUID } from "node:crypto";

const SWIFT_EPOCHE = 978307200; // JSONEncoder-Standard: Sekunden seit 2001-01-01
const ARTEN = new Set(["gym.checkin", "gym.uebung", "gym.checkout", "gym.loeschen"]);
export const GRUPPEN = ["schulter", "unterarme", "nacken", "ruecken", "brust", "bizeps", "trizeps", "bauch", "beine"];
const STANDARD_PRIO = ["schulter", "unterarme", "nacken", "ruecken", "brust"];
const WOCHENTAG = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];

export function katalogLaden(health) {
  const uebungen = JSON.parse(readFileSync(join(health, "uebungen.json"), "utf8"));
  const splits = JSON.parse(readFileSync(join(health, "GymNeu", "splits.json"), "utf8"));
  return { uebungen, nachId: new Map(uebungen.map((u) => [u.id, u])), splits };
}

export const istCardio = (u) => u?.koerper === "Cardio";

// MARK: Datum (Europe/Berlin wie Datum.swift)

const berlin = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Berlin", year: "numeric", month: "2-digit", day: "2-digit" });
export const datumText = (d) => berlin.format(d);
const mittag = (t) => Date.parse(t + "T12:00:00Z");
export const wochentag = (t) => ((new Date(mittag(t)).getUTCDay() + 6) % 7) + 1;
export const addTage = (t, n) => new Date(mittag(t) + n * 864e5).toISOString().slice(0, 10);
export const montag = (t) => addTage(t, 1 - wochentag(t));
const ausSwift = (s) => (typeof s === "number" ? new Date((s + SWIFT_EPOCHE) * 1000) : null);
const tageText = (t) => [...new Set(t ?? [])].filter((w) => w >= 1 && w <= 7).sort().map((w) => WOCHENTAG[w - 1]).join(", ") || "kein Tag";
const runden = (x, n = 1) => Math.round(x * 10 ** n) / 10 ** n;

// MARK: Faltung

const zaehlt = (s) => s.ok === true && s.typ !== "w";

/** Ops einer Person (alle gym.*) -> aktueller Plan, Planverlauf, Einheiten (neueste zuerst). */
export function falten(ops) {
  let plan = null;
  let planZeit = -Infinity;
  const plaene = [];
  const tagNamen = {};
  const eintraege = new Map();
  for (const op of ops) {
    const zeit = Date.parse(op.zeit);
    if (op.art === "gym.plan") {
      plaene.push({ seq: op.seq, zeit: op.zeit, splitName: op.d?.splitName ?? null, tage: (op.d?.tage ?? []).map((t) => t.name) });
      for (const t of op.d?.tage ?? []) tagNamen[t.id] = t.name;
      if (zeit >= planZeit) [plan, planZeit] = [op.d, zeit];
    } else if (ARTEN.has(op.art) && op.d?.session) eintraege.set(op.id, { art: op.art, zeit, d: op.d });
  }
  plaene.sort((a, b) => b.seq - a.seq);
  return { plan, plaene, tagNamen, sessions: sessions([...eintraege.values()]) };
}

export function sessions(eintraege) {
  const nach = new Map();
  for (const e of [...eintraege].sort((a, b) => a.zeit - b.zeit)) {
    if (!nach.has(e.d.session)) nach.set(e.d.session, []);
    nach.get(e.d.session).push(e);
  }
  return [...nach].map(([id, l]) => session(id, l)).filter(Boolean).sort((a, b) => b.start - a.start);
}

function session(id, liste) {
  if (liste.some((e) => e.art === "gym.loeschen")) return null;
  const checkin = liste.findLast((e) => e.art === "gym.checkin" && e.d.start != null);
  if (!checkin) return null;
  const aus = liste.findLast((e) => e.art === "gym.checkout" && (e.d.ende != null || e.d.status === "wieder"))?.d;
  const s = { id, tag: checkin.d.tag ?? null, start: ausSwift(checkin.d.start), ende: ausSwift(aus?.ende), kcal: aus?.kcal ?? null, puls: aus?.puls ?? null, laeufe: [] };
  // ponytail: ohne Zeiten je Übung (TrainingLogik.Lauf.start/ende), die liest kein Werkzeug.
  const lauf = (e) => {
    let l = s.laeufe.findLast((x) => x.plan === e.d.plan);
    if (!l || e.d.status === "start") s.laeufe.push((l = { plan: e.d.plan, uebung: e.d.uebung ?? "", fertig: false, saetze: null, name: e.d.name }));
    return l;
  };
  for (const e of liste) {
    if (e.art !== "gym.uebung" || !e.d.plan) continue;
    const { plan, status } = e.d;
    if (status === "start") lauf(e);
    else if (status === "fertig") Object.assign(lauf(e), { fertig: true, saetze: e.d.saetze ?? null });
    else if (status === "offen") s.laeufe.forEach((l) => l.plan === plan && (l.fertig = false));
    else if (status === "weg") s.laeufe = s.laeufe.filter((l) => l.plan !== plan);
    else if (status === "satz") {
      const l = lauf(e);
      const gezaehlt = (e.d.saetze ?? []).filter(zaehlt);
      if (e.d.uebung) l.uebung = e.d.uebung;
      if (e.d.ersatzFuer) l.ersatzFuer = e.d.ersatzFuer;
      else if (l.ersatzFuer === l.uebung) l.ersatzFuer = undefined;
      Object.assign(l, { saetze: gezaehlt.length ? gezaehlt : null, fertig: gezaehlt.length > 0 });
    }
  }
  return s;
}

// MARK: Muskeln (MuskelLogik.teile, nur Gruppe und groß/klein)

const STANDARD = {
  Schultern: "sVorne", "hintere Schulter": "sHinten", Rotatorenmanschette: "sHinten",
  Unterarme: "uBeuger", Griffkraft: "uBeuger", Handgelenkbeuger: "uBeuger", Handgelenkstrecker: "uStrecker",
  Kopfwender: "nVorne", Schulterblattheber: "nHinten",
  Trapez: "rTrapezOben", "oberer Rücken": "rOben", Rautenmuskel: "rOben", Rücken: "rOben",
  Latissimus: "rLat", Rückenstrecker: "rUnten", "unterer Rücken": "rUnten",
  Brust: "bUnten", "obere Brust": "bOben",
  Bizeps: "biLang", Oberarmmuskel: "biLang", Trizeps: "triSeitlich",
  Bauch: "baGerade", Rumpf: "baGerade", "unterer Bauch": "baGerade", Hüftbeuger: "baGerade",
  "seitlicher Bauch": "baSeitlich", Sägemuskel: "baSeitlich",
  Quadrizeps: "beQuads", Adduktoren: "beAdd", Leiste: "beAdd", "Oberschenkel innen": "beAdd",
  Po: "bePo", Abduktoren: "bePo", Beinbeuger: "beBeuger",
  Waden: "beWaden", Schollenmuskel: "beWaden", Schienbein: "beWaden",
};
const GRUPPE_VON = { s: "schulter", u: "unterarme", n: "nacken", r: "ruecken", b: "brust", bi: "bizeps", tri: "trizeps", ba: "bauch", be: "beine" };
export const gruppeVon = (teil) => GRUPPE_VON[teil.match(/^[a-z]+/)[0]];
const GROSS = new Set(["beQuads", "beBeuger", "bePo", "rLat", "bUnten", "rUnten"]);

function direkt(muskel, text) {
  const hat = (...w) => w.some((x) => text.includes(x));
  switch (muskel) {
    case "Schultern": return hat("face pull", "reverse", "hintere", "vorgebeugt") ? "sHinten" : hat("seit") ? "sSeitlich" : "sVorne";
    case "Unterarme": return hat("hammer") ? "uSpeiche" : hat("reverse", "strecke") ? "uStrecker" : "uBeuger";
    case "Trapez": return hat("face pull", "rudern") ? "rTrapezUnten" : "rTrapezOben";
    case "Brust": return hat("schräg", "incline", "oben") ? "bOben" : "bUnten";
    case "Bizeps": return hat("preacher", "scott", "konzentration") ? "biKurz" : "biLang";
    case "Trizeps": return hat("über kopf", "überkopf", "overhead", "french") ? "triLang" : "triSeitlich";
    default: return STANDARD[muskel];
  }
}

/** [[teil, faktor]]: Hauptmuskel 1, Nebenmuskeln 0,5, jeder Teil einmal. Cardio und eigene: []. */
export function teile(u) {
  if (!u || istCardio(u)) return [];
  const liste = [];
  const t = direkt(u.muskel, `${u.name} ${u.en}`.toLowerCase());
  if (t) liste.push([t, 1]);
  for (const n of u.neben ?? []) if (STANDARD[n] && !liste.some(([x]) => x === STANDARD[n])) liste.push([STANDARD[n], 0.5]);
  return liste;
}

function teilSaetze(s, kat) {
  const summe = {};
  for (const l of s.laeufe) {
    const n = l.fertig ? (l.saetze?.length ?? 0) : 0;
    if (!n) continue;
    for (const [t, f] of teile(kat.nachId.get(l.uebung))) summe[t] = (summe[t] ?? 0) + f * n;
  }
  return summe;
}

const jeGruppe = (teilWerte) => {
  const g = {};
  for (const [t, n] of Object.entries(teilWerte)) g[gruppeVon(t)] = runden((g[gruppeVon(t)] ?? 0) + n);
  return g;
};

/** Wochenziele wie KoerperZiele.lesen + MuskelLogik.standardZiel; `werte` = Einstellungen der Person. */
export function ziele(werte, person) {
  const prio = GRUPPEN.filter((g) => (werte[`ziel.prio.${g}`] ?? 0) > 0).sort((a, b) => werte[`ziel.prio.${a}`] - werte[`ziel.prio.${b}`]);
  const gesetzt = GRUPPEN.filter((g) => werte[`ziel.saetze.${g}`] != null);
  if (person === "annika" && !prio.length && !gesetzt.length) return { prio: [], saetze: {} };
  const p = prio.length ? prio : STANDARD_PRIO;
  const saetze = Object.fromEntries(GRUPPEN.map((g) => [g, werte[`ziel.saetze.${g}`] ?? (p.includes(g) ? (g === "schulter" || g === "ruecken" ? 16 : 12) : 8)]));
  return { prio: p, saetze };
}

// MARK: Kraft

export const e1rm = (s) => (s.kg > 0 && s.wdh > 0 ? (s.wdh === 1 ? s.kg : s.kg * (1 + s.wdh / 30)) : null);
const satzText = (s) => (s.kg > 0 ? `${runden(s.kg)}×${s.wdh}` : `${s.wdh} Wdh`);

/** KoerperLogik.naechstesMal: doppelte Progression 8-12 Wdh, +2,5 kg wenn jeder Arbeitssatz oben ist. */
export function naechstesMal(saetze, oben = 12, start = 8) {
  if (!saetze?.length) return null;
  const kgs = saetze.map((s) => s.kg).filter((k) => k != null);
  const kg = kgs.length ? Math.max(...kgs) : null;
  const schwach = Math.min(...saetze.filter((s) => (s.kg ?? null) === kg).map((s) => s.wdh));
  if (schwach >= oben) return kg == null ? `Alle Sätze bei ${oben}: Zusatzgewicht` : `${runden(kg + 2.5)} kg × ${start}`;
  return kg == null ? `${schwach + 1} Wdh` : `${runden(kg)} kg × ${schwach + 1}`;
}

// Thibaudeau (openGym structuralBalanceTemplates): Kniebeuge 100, Bank 75, Kreuzheben 120, Schulterdrücken 45.
const HAUPTUEBUNGEN = [
  ["kniebeuge", /^barbell (full |high bar |low bar |back )?squat$/, 100],
  ["bankdruecken", /^barbell bench press$/, 75],
  ["kreuzheben", /^barbell (sumo )?deadlift$/, 120],
  ["schulterdruecken", /^barbell .*(military|overhead) press$/, 45],
];

function balance(bestJeUebung, kat) {
  const best = {};
  for (const [id, wert] of Object.entries(bestJeUebung)) {
    const en = kat.nachId.get(id)?.en ?? "";
    for (const [name, muster] of HAUPTUEBUNGEN) if (muster.test(en) && wert > (best[name] ?? 0)) best[name] = wert;
  }
  const basis = best.kniebeuge ? ["kniebeuge", 100] : best.bankdruecken ? ["bankdruecken", 75] : null;
  if (!basis || Object.keys(best).length < 2) return { hinweis: "Zu wenig Hauptübungen mit Gewicht (Kniebeuge, Bank, Kreuzheben, Schulterdrücken mit Langhantel)" };
  const [bName, bAnteil] = basis;
  const ergebnis = { basis: bName, modell: "Thibaudeau: Kniebeuge 100, Bank 75, Kreuzheben 120, Schulterdrücken 45" };
  for (const [name, , anteil] of HAUPTUEBUNGEN) {
    if (name === bName || !best[name]) continue;
    const soll = (best[bName] * anteil) / bAnteil;
    const quote = best[name] / soll;
    ergebnis[name] = { e1rm: runden(best[name]), soll: runden(soll), prozent: Math.round(quote * 100), stand: quote >= 0.95 ? "ausgewogen" : quote >= 0.9 ? "grenzwertig" : "schwach" };
  }
  return ergebnis;
}

// MARK: Auswertung

/** Alles, was ein Agent zum Anpassen des Plans braucht. `jetzt` als Date, `wochen` Rückblick. */
export function auswerten({ plan, sessions: alle }, kat, { jetzt = new Date(), wochen = 8, ziel = { saetze: {} } } = {}) {
  const heute = datumText(jetzt);
  const ab = addTage(montag(heute), -7 * (wochen - 1));
  const s = alle.filter((x) => datumText(x.start) >= ab);
  const name = (id) => kat.nachId.get(id)?.name ?? id;

  const wochenListe = [];
  for (let m = montag(heute); m >= ab; m = addTage(m, -7)) {
    const drin = s.filter((x) => montag(datumText(x.start)) === m);
    const teil = {};
    let saetze = 0;
    let volumen = 0;
    let minuten = 0;
    for (const x of drin) {
      for (const [t, n] of Object.entries(teilSaetze(x, kat))) teil[t] = (teil[t] ?? 0) + n;
      for (const l of x.laeufe) for (const st of l.fertig ? (l.saetze ?? []) : []) (saetze++, (volumen += (st.kg ?? 0) * st.wdh));
      if (x.ende) minuten += (x.ende - x.start) / 6e4;
    }
    wochenListe.push({ woche: m, trainings: drin.length, minuten: Math.round(minuten), saetze, volumenKg: Math.round(volumen), saetzeJeGruppe: jeGruppe(teil) });
  }

  const aktuell = wochenListe[0]?.saetzeJeGruppe ?? {};
  const schnitt = {};
  const volle = wochenListe.slice(1);
  for (const g of GRUPPEN) schnitt[g] = volle.length ? runden(volle.reduce((a, w) => a + (w.saetzeJeGruppe[g] ?? 0), 0) / volle.length) : 0;
  const ziele = Object.fromEntries(GRUPPEN.map((g) => [g, { dieseWoche: aktuell[g] ?? 0, schnittVorwochen: schnitt[g], ziel: ziel.saetze?.[g] ?? null }]));

  // Erholung wie MuskelLogik.erholung, Abbau nach Pause wie openGym (ab 14 Tagen, Halbwertszeit 28 Tage).
  const letzte = {};
  for (const x of alle) {
    const zeit = x.ende ?? x.start;
    for (const [t, n] of Object.entries(teilSaetze(x, kat))) if (!letzte[t] || zeit > letzte[t].zeit) letzte[t] = { zeit, n };
  }
  const erholung = {};
  for (const [t, { zeit, n }] of Object.entries(letzte)) {
    const g = gruppeVon(t);
    const stunden = Math.max(0, (jetzt - zeit) / 36e5);
    const prozent = Math.min(100, Math.floor((stunden * 100) / ((GROSS.has(t) ? 60 : 30) * (1 + 0.08 * Math.max(0, n - 3)))));
    const tage = Math.floor(stunden / 24);
    if (!erholung[g] || prozent < erholung[g].prozent) erholung[g] = { ...erholung[g], prozent, stufe: prozent >= 90 ? "erholt" : prozent >= 50 ? "fast" : "müde" };
    if (erholung[g].tageSeitTraining == null || tage < erholung[g].tageSeitTraining) erholung[g].tageSeitTraining = tage;
  }
  for (const g of GRUPPEN) {
    const e = (erholung[g] ??= { prozent: 100, stufe: "erholt", tageSeitTraining: null });
    const t = e.tageSeitTraining;
    e.formErhalt = t == null ? "nie trainiert" : t <= 14 ? 100 : Math.round(Math.max(0.5, 0.5 ** ((t - 14) / 28)) * 100);
  }

  // Übungen: Verlauf, bestes e1RM, Plateau, Vorschlag fürs nächste Mal.
  const proUebung = {};
  for (const x of [...alle].reverse()) {
    for (const l of x.laeufe) {
      const st = l.fertig ? (l.saetze ?? []) : [];
      if (!st.length) continue;
      (proUebung[l.uebung] ??= []).push({ datum: datumText(x.start), saetze: st, e1rm: Math.max(0, ...st.map((y) => e1rm(y) ?? 0)) });
    }
  }
  const best = {};
  const uebungen = [];
  for (const [id, liste] of Object.entries(proUebung)) {
    const werte = liste.map((v) => v.e1rm);
    best[id] = Math.max(...werte);
    if (!liste.some((v) => v.datum >= ab)) continue;
    const vorher = werte.slice(0, -3);
    const plateau = werte.length >= 4 && best[id] > 0 && Math.max(...werte.slice(-3)) <= Math.max(...vorher);
    const rekord = liste.find((v) => v.e1rm === best[id]);
    uebungen.push({
      id, name: name(id), muskel: kat.nachId.get(id)?.muskel ?? null, einheiten: liste.length,
      zuletzt: liste.slice(-3).reverse().map((v) => `${v.datum}: ${v.saetze.map(satzText).join(", ")}`),
      e1rmBest: best[id] ? runden(best[id]) : null, rekordAm: best[id] ? rekord.datum : null,
      e1rmVerlauf: best[id] ? liste.slice(-6).map((v) => [v.datum, runden(v.e1rm)]) : undefined,
      plateau, naechstesMal: naechstesMal(liste.at(-1).saetze),
    });
  }
  uebungen.sort((a, b) => b.einheiten - a.einheiten || a.name.localeCompare(b.name));

  // Plantreue: geplante Wochentage seit `ab` bis heute gegen Tage mit Training.
  const trainingsTage = new Set(s.map((x) => datumText(x.start)));
  const tage = plan?.tage ?? [];
  const planTreue = tage.map((t) => {
    let geplant = 0;
    let gemacht = 0;
    for (let d = ab; d <= heute; d = addTage(d, 1)) {
      if (!t.wochentage.includes(wochentag(d))) continue;
      geplant++;
      if (trainingsTage.has(d)) gemacht++;
    }
    return { tag: t.name, wochentage: tageText(t.wochentage), geplant, gemacht, alsTagGewaehlt: s.filter((x) => x.tag === t.id).length };
  });
  // geplant zählt nach dem aktuellen Plan rückwärts; ein frisch geänderter Plan macht ältere Wochen ungenau.

  let serie = 0;
  const wochenMit = new Set(alle.map((x) => montag(datumText(x.start))));
  for (let m = wochenMit.has(montag(heute)) ? montag(heute) : addTage(montag(heute), -7); wochenMit.has(m); m = addTage(m, -7)) serie++;

  return {
    zeitraum: { ab, bis: heute, wochen },
    trainings: s.length, serieWochen: serie,
    wochen: wochenListe,
    saetzeJeGruppe: ziele,
    erholung,
    uebungen,
    planTreue,
    kraftVerhaeltnis: balance(best, kat),
  };
}

// MARK: Lesbare Ausgaben

export function satzKurz(u) {
  if (u.minuten != null) return `${u.minuten} min`;
  const s = u.saetze ?? [];
  if (!s.length) return "keine Sätze";
  const teile = [new Set(s.map((x) => x.wdh)).size === 1 ? `${s.length} × ${s[0].wdh}` : `${s.length} Sätze (${s.map((x) => x.wdh).join("/")})`];
  const kg = s.map((x) => x.kg).filter((k) => k != null);
  if (kg.length) teile.push(Math.min(...kg) === Math.max(...kg) ? `${kg[0]} kg` : `${Math.min(...kg)}–${Math.max(...kg)} kg`);
  if (s.some((x) => x.failure)) teile.push("F");
  return teile.join(" · ");
}

export function planLesbar(plan, kat) {
  if (!plan) return null;
  return {
    splitName: plan.splitName ?? null,
    ruhetage: tageText(plan.ruhetage),
    tage: plan.tage.map((t) => ({
      id: t.id, name: t.name, wochentage: tageText(t.wochentage),
      uebungen: t.uebungen.map((u) => {
        const k = kat.nachId.get(u.uebung);
        return { id: u.id, uebung: u.uebung, name: u.name ?? k?.name ?? "Übung", muskel: k?.muskel ?? null, saetze: satzKurz(u), ...(u.notiz ? { notiz: u.notiz } : {}), ...(u.supersatz ? { supersatz: true } : {}) };
      }),
    })),
  };
}

/** `tagNamen`: Tag-id -> Name aus allen Plänen (`falten`), damit auch Tage alter Pläne einen Namen haben. */
export function sessionLesbar(x, kat, tagNamen = {}) {
  return {
    id: x.id, datum: datumText(x.start),
    tag: x.tag ? (tagNamen[x.tag] ?? "(unbekannter Tag)") : null,
    minuten: x.ende ? Math.round((x.ende - x.start) / 6e4) : null, laeuft: x.ende == null,
    ...(x.kcal ? { kcal: x.kcal } : {}), ...(x.puls ? { puls: x.puls } : {}),
    uebungen: x.laeufe.map((l) => ({
      name: l.name ?? kat.nachId.get(l.uebung)?.name ?? l.uebung, uebung: l.uebung,
      saetze: (l.fertig ? (l.saetze ?? []) : []).map(satzText).join(", ") || "nicht gemacht",
      ...(l.ersatzFuer ? { stattDessen: kat.nachId.get(l.ersatzFuer)?.name ?? l.ersatzFuer } : {}),
    })),
  };
}

// MARK: Katalogsuche

const klein = (t) => (t ?? "").toLocaleLowerCase("de");
export function uebungenSuchen(kat, { suche, muskel, geraet, limit = 30 }) {
  const w = klein(suche).split(/\s+/).filter(Boolean);
  const treffer = kat.uebungen.filter(
    (u) =>
      (!muskel || klein(u.muskel) === klein(muskel) || klein(u.koerper) === klein(muskel)) &&
      (!geraet || klein(u.geraet) === klein(geraet)) &&
      w.every((x) => klein(`${u.name} ${u.en}`).includes(x))
  );
  return { anzahl: treffer.length, uebungen: treffer.slice(0, Math.min(100, limit)) };
}

export function splitLesbar(sp, kat) {
  return {
    ...sp,
    einheiten: sp.einheiten.map((e) => ({
      name: e.name, wochentage: tageText(e.wochentage),
      uebungen: e.uebungen.map((z) => `${kat.nachId.get(z.uebung)?.name ?? z.uebung}: ${z.minuten ? `${z.minuten} min` : `${z.saetze} × ${z.von}-${z.bis}`}`),
    })),
  };
}

// MARK: Plan bauen und prüfen

const neueId = () => randomUUID().toUpperCase();

/** SplitLogik.alsPlan: neue ids, `von` als Wdh, kein Gewicht, Tage ohne Einheit werden Ruhetage. */
export function splitAlsPlan(sp) {
  const training = new Set(sp.einheiten.flatMap((e) => e.wochentage));
  return {
    tage: sp.einheiten.map((e) => ({
      id: neueId(), name: e.name, wochentage: [...e.wochentage].sort(),
      uebungen: e.uebungen.map((z) => ({
        id: neueId(), uebung: z.uebung,
        saetze: z.minuten != null ? [] : Array.from({ length: z.saetze }, () => ({ wdh: z.von, failure: false })),
        ...(z.minuten != null ? { minuten: z.minuten } : {}), ...(z.supersatz ? { supersatz: true } : {}),
      })),
    })),
    ruhetage: [1, 2, 3, 4, 5, 6, 7].filter((w) => !training.has(w)),
    splitName: sp.name,
  };
}

function uebungFinden(kat, eingabe) {
  if (kat.nachId.has(eingabe)) return { id: eingabe };
  const t = klein(eingabe);
  const gleich = kat.uebungen.filter((u) => klein(u.name) === t || klein(u.en) === t);
  if (gleich.length === 1) return { id: gleich[0].id };
  const aehnlich = uebungenSuchen(kat, { suche: eingabe, limit: 5 }).uebungen;
  return { fehler: `Übung "${eingabe}" nicht eindeutig im Katalog${aehnlich.length ? `, ähnlich: ${aehnlich.map((u) => `${u.id} ${u.name}`).join("; ")}` : ""}` };
}

/**
 * Nimmt einen Plan in App-Form oder Kurzform und gibt ihn so zurück, wie die App ihn als gym.plan liest.
 * Kurzform je Übung: {uebung: id oder genauer Name, saetze: 3, wdh: 10, kg: 60}. Bestehende ids bleiben
 * (Verlauf und Notizen hängen an ihnen), fehlende werden neu vergeben.
 */
export function planPruefen(eingabe, kat) {
  const fehler = [];
  if (!eingabe || !Array.isArray(eingabe.tage)) return { fehler: ["plan.tage fehlt"] };
  const belegt = new Map();
  const tage = eingabe.tage.map((t, ti) => {
    const wo = `Tag ${ti + 1}${t?.name ? ` (${t.name})` : ""}`;
    if (!t?.name || typeof t.name !== "string") fehler.push(`${wo}: name fehlt`);
    const wochentage = [...new Set(t?.wochentage ?? [])];
    for (const w of wochentage) {
      if (!Number.isInteger(w) || w < 1 || w > 7) fehler.push(`${wo}: Wochentag ${w} ungültig (1 = Mo … 7 = So)`);
      else if (belegt.has(w)) fehler.push(`${wo}: ${WOCHENTAG[w - 1]} gehört schon zu ${belegt.get(w)}`);
      else belegt.set(w, t.name);
    }
    const uebungen = (t?.uebungen ?? []).map((u, ui) => {
      const wo2 = `${wo}, Übung ${ui + 1}`;
      let id = u?.uebung;
      let name;
      if (id === "eigen") {
        if (!u.name) fehler.push(`${wo2}: eigene Übung braucht name`);
        name = u.name;
      } else {
        const f = uebungFinden(kat, String(id ?? ""));
        if (f.fehler) fehler.push(`${wo2}: ${f.fehler}`);
        id = f.id ?? id;
      }
      const k = kat.nachId.get(id);
      const cardio = u.minuten != null || istCardio(k);
      let saetze = [];
      if (!cardio) {
        let roh = u.saetze;
        if (!Array.isArray(roh)) {
          // Kurzform {saetze: 3, wdh: 10, kg: 60} wird zur App-Form und läuft durch dieselbe Prüfung.
          const n = roh ?? 3;
          if (!Number.isInteger(n) || n < 1 || n > 20) fehler.push(`${wo2}: saetze muss 1-20 sein`);
          roh = Array.from({ length: Math.max(0, Math.min(20, n | 0)) }, () => ({ wdh: u.wdh ?? 10, kg: u.kg }));
        }
        saetze = roh.map((s, si) => {
          if (!Number.isInteger(s?.wdh) || s.wdh < 1 || s.wdh > 100) fehler.push(`${wo2}, Satz ${si + 1}: wdh muss 1-100 sein`);
          if (s?.kg != null && !(s.kg >= 0 && s.kg <= 500)) fehler.push(`${wo2}, Satz ${si + 1}: kg ungültig`);
          if (s?.typ != null && s.typ !== "w" && s.typ !== "d") fehler.push(`${wo2}, Satz ${si + 1}: typ nur "w" oder "d"`);
          return { wdh: s?.wdh, ...(s?.kg != null ? { kg: s.kg } : {}), failure: s?.failure === true, ...(s?.typ ? { typ: s.typ } : {}), ...(s?.rpe != null ? { rpe: s.rpe } : {}) };
        });
        if (!saetze.length) fehler.push(`${wo2}: keine Sätze`);
      }
      return {
        id: u.id ?? neueId(), uebung: id, ...(name ? { name } : {}), saetze,
        ...(cardio ? { minuten: u.minuten ?? 20 } : {}),
        ...(u.notiz ? { notiz: String(u.notiz) } : {}), ...(u.pause != null ? { pause: u.pause } : {}), ...(u.supersatz ? { supersatz: true } : {}),
      };
    });
    return { id: t?.id ?? neueId(), name: t?.name, wochentage: wochentage.sort(), uebungen };
  });
  let ruhetage = eingabe.ruhetage ?? [1, 2, 3, 4, 5, 6, 7].filter((w) => !belegt.has(w));
  ruhetage = [...new Set(ruhetage)].sort();
  for (const w of ruhetage) if (belegt.has(w)) fehler.push(`Ruhetag ${WOCHENTAG[w - 1]} ist auch Trainingstag (${belegt.get(w)})`);
  const ids = tage.flatMap((t) => [t.id, ...t.uebungen.map((u) => u.id)]);
  if (new Set(ids).size !== ids.length) fehler.push("ids doppelt");
  const plan = { tage, ruhetage, ...(eingabe.splitName ? { splitName: String(eingabe.splitName) } : {}) };
  return fehler.length ? { fehler } : { plan };
}

/** Was sich gegenüber dem alten Plan ändert, je Tag eine Zeile. Tage gleicher id gehören zusammen. */
export function planUnterschied(alt, neu, kat) {
  const text = (t) => `${tageText(t.wochentage)}: ${t.uebungen.map((u) => `${u.name ?? kat.nachId.get(u.uebung)?.name ?? u.uebung} ${satzKurz(u)}`).join("; ") || "leer"}`;
  const altTage = new Map((alt?.tage ?? []).map((t) => [t.id, t]));
  const zeilen = [];
  for (const t of neu.tage) {
    const a = altTage.get(t.id);
    altTage.delete(t.id);
    if (!a) zeilen.push(`+ ${t.name} (${text(t)})`);
    else if (a.name !== t.name || text(a) !== text(t)) zeilen.push(`~ ${a.name}${a.name !== t.name ? ` -> ${t.name}` : ""}: ${text(a)}  ->  ${text(t)}`);
  }
  for (const a of altTage.values()) zeilen.push(`- ${a.name} (${text(a)})`);
  if (tageText(alt?.ruhetage) !== tageText(neu.ruhetage)) zeilen.push(`Ruhetage: ${tageText(alt?.ruhetage)} -> ${tageText(neu.ruhetage)}`);
  if ((alt?.splitName ?? null) !== (neu.splitName ?? null)) zeilen.push(`Splitname: ${alt?.splitName ?? "-"} -> ${neu.splitName ?? "-"}`);
  return zeilen.length ? zeilen : ["keine Änderung"];
}

export const planOp = (plan, person) => ({ id: neueId(), art: "gym.plan", von: person, zeit: new Date().toISOString(), d: plan });
