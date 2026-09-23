// Zeitgesteuertes (Z-1.7): reine Funktionen, Europe/Berlin über Intl, DST-sicher
// (auch über die Zeitumstellung 25.10.2026). raum.js sammelt den `kontext` aus
// den Ops und ruft naechsterAlarm() nach jedem Alarm-Feuern neu auf.

const TZ = "Europe/Berlin";

function berlinParts(ms) {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  const p = Object.fromEntries(fmt.formatToParts(ms).filter((x) => x.type !== "literal").map((x) => [x.type, x.value]));
  return { y: +p.year, mo: +p.month, d: +p.day, h: +p.hour, mi: +p.minute, s: +p.second };
}

// UTC-Zeitpunkt, der in Europe/Berlin der Wanduhrzeit y-mo-d h:mi:s entspricht.
// Iterativ, damit die echte IANA-Zeitzone (inkl. Zeitumstellung) entscheidet.
function berlinInstant(y, mo, d, h, mi = 0, s = 0) {
  let guessMs = Date.UTC(y, mo - 1, d, h, mi, s);
  const wantMs = guessMs;
  for (let i = 0; i < 4; i++) {
    const p = berlinParts(guessMs);
    const wallMs = Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s);
    const diff = wantMs - wallMs;
    if (diff === 0) break;
    guessMs += diff;
  }
  return guessMs;
}

// Kalendertag +/- n, über einen Mittags-Anker (bleibt sicher innerhalb des
// Zieltags, auch wenn DST den Tag um +/-1h verschiebt).
function tagVerschieben(datumStr, n) {
  const [y, mo, d] = datumStr.split("-").map(Number);
  const dt = new Date(Date.UTC(y, mo - 1, d, 12, 0, 0) + n * 86_400_000);
  return { y: dt.getUTCFullYear(), mo: dt.getUTCMonth() + 1, d: dt.getUTCDate() };
}

const pad2 = (n) => String(n).padStart(2, "0");
const alsDatumStr = ({ y, mo, d }) => `${y}-${pad2(mo)}-${pad2(d)}`;

// Montag der Woche, die `datumStr` enthält, als "YYYY-MM-DD" -- dieselbe Montag-first-Woche wie
// der iOS-Client (`Datum.montagDerWoche`), hier lokal nachgebaut (kein Swift-Import im Worker).
export function montagDerWoche(datumStr) {
  const [y, mo, d] = datumStr.split("-").map(Number);
  const utcTag = new Date(Date.UTC(y, mo - 1, d, 12)).getUTCDay(); // 0=So..6=Sa
  const wochentag = utcTag === 0 ? 7 : utcTag; // 1=Mo..7=So
  return alsDatumStr(tagVerschieben(datumStr, -(wochentag - 1)));
}

function letzterTagImMonat(y, mo) {
  return new Date(Date.UTC(y, mo, 0)).getUTCDate(); // Tag 0 des Folgemonats = letzter Tag von mo
}

export function vorabendZeit(treffenDatum) {
  const t = tagVerschieben(treffenDatum, -1);
  return berlinInstant(t.y, t.mo, t.d, 20, 0, 0);
}

export function stundeVorherZeit(treffenDatum, uhrzeit) {
  const [y, mo, d] = treffenDatum.split("-").map(Number);
  const [hh, mm] = uhrzeit.split(":").map(Number);
  return berlinInstant(y, mo, d, hh, mm, 0) - 3_600_000;
}

// ponytail: feste Uhrzeit 09:00, Spec sagt nur "am Morgen". Upgrade-Weg: aus
// den Wochenplan-Zeiten der Person ableiten, sobald die existieren.
export function puenktlichZeit(treffenDatum) {
  const t = tagVerschieben(treffenDatum, 1);
  return berlinInstant(t.y, t.mo, t.d, 9, 0, 0);
}

// Kalendertag in Europe/Berlin als "YYYY-MM-DD", für Streak & Tages-Dedupe.
export function berlinDatum(ms) {
  const p = berlinParts(ms);
  return `${p.y}-${String(p.mo).padStart(2, "0")}-${String(p.d).padStart(2, "0")}`;
}

// Nächster Zeitpunkt hh:mm Berlin, strikt nach jetztMs.
export function naechsteTageszeit(jetztMs, hh, mm = 0) {
  const p = berlinParts(jetztMs);
  let kandidat = berlinInstant(p.y, p.mo, p.d, hh, mm, 0);
  if (kandidat <= jetztMs) {
    const morgen = tagVerschieben(`${p.y}-${String(p.mo).padStart(2, "0")}-${String(p.d).padStart(2, "0")}`, 1);
    kandidat = berlinInstant(morgen.y, morgen.mo, morgen.d, hh, mm, 0);
  }
  return kandidat;
}

// Nächster fälliger Zeitpunkt für ein tägliches Ereignis (Frage des Tages,
// Streak-Warnung): wenn es heute noch nicht erledigt ist, ist der Kandidat
// HEUTE hh:mm -- auch wenn das schon in der Vergangenheit liegt (dann wird es
// beim nächsten Alarm sofort nachgeholt, statt nie zu feuern). Ist es heute
// schon erledigt, ist der Kandidat morgen hh:mm, damit dauerhaft ein
// Wach-Zeitpunkt geplant bleibt (sonst würde die letzte Erinnerung des Tages
// den DO-Alarm ganz abschalten und der nächste Tag nie mehr aufwachen).
export function naechsteFaelligeTageszeit(jetztMs, hh, mm, heuteErledigt) {
  if (!heuteErledigt) {
    const p = berlinParts(jetztMs);
    return berlinInstant(p.y, p.mo, p.d, hh, mm, 0);
  }
  return naechsteTageszeit(jetztMs, hh, mm);
}

// --- Challenges (Z-22.3): Endspurt am letzten Tag (18 Uhr), Ende-Mitteilung kurz danach ---
// (nicht mitten in der Nacht, deshalb 09:00 statt 00:00 -- ponytail: fest, keine Zustellzeit-
// Personalisierung). "Ende" heißt hier nur "Zeitraum ist um", der Server rechnet keine Punkte.

export function challengeEndspurtWocheZeit(heuteStr) {
  const sonntag = alsDatumStr(tagVerschieben(montagDerWoche(heuteStr), 6));
  const [y, mo, d] = sonntag.split("-").map(Number);
  return berlinInstant(y, mo, d, 18, 0, 0);
}

export function challengeEndeWocheZeit(heuteStr) {
  const naechsterMontag = alsDatumStr(tagVerschieben(montagDerWoche(heuteStr), 7));
  const [y, mo, d] = naechsterMontag.split("-").map(Number);
  return berlinInstant(y, mo, d, 9, 0, 0);
}

export function challengeEndspurtMonatZeit(heuteStr) {
  const [y, mo] = heuteStr.split("-").map(Number);
  return berlinInstant(y, mo, letzterTagImMonat(y, mo), 18, 0, 0);
}

export function challengeEndeMonatZeit(heuteStr) {
  const [y, mo] = heuteStr.split("-").map(Number);
  const naechster = mo === 12 ? { y: y + 1, mo: 1 } : { y, mo: mo + 1 };
  return berlinInstant(naechster.y, naechster.mo, 1, 9, 0, 0);
}

// Wenn diese Periode schon erledigt ist, den Anker um eine Periode weiterschieben, damit `zeitFn`
// die Zeit der NÄCHSTEN Woche/des NÄCHSTEN Monats liefert statt wieder derselben.
function naechsteWoechentlicheChallengeZeit(jetztMs, zeitFn, erledigt) {
  const heute = berlinDatum(jetztMs);
  if (!erledigt) return zeitFn(heute);
  return zeitFn(alsDatumStr(tagVerschieben(montagDerWoche(heute), 7)));
}

function naechsteMonatlicheChallengeZeit(jetztMs, zeitFn, erledigt) {
  const heute = berlinDatum(jetztMs);
  if (!erledigt) return zeitFn(heute);
  const [y, mo] = heute.split("-").map(Number);
  return zeitFn(mo === 12 ? `${y + 1}-01-01` : `${y}-${pad2(mo + 1)}-01`);
}

// kontext, von raum.js aus den Ops gebaut:
// {
//   treffen: [{datum:"YYYY-MM-DD", uhrzeit?:"HH:mm"}],
//   angeheftet: [{id, bis}],            // noch nicht losgelöste Nachrichten mit Ablauf
//   spielEinladungen: [{id, bis}],      // noch offene Einladungen
//   streakLaeuftHeuteAb: boolean,
//   erinnerungenHeute: {frage: boolean, streak: boolean},
//   challengeErledigt: {endspurtWoche, endeWoche, endspurtMonat, endeMonat: boolean},
// }
export function naechsterAlarm(kontext, jetztMs) {
  const kandidaten = [];
  for (const t of kontext.treffen ?? []) {
    kandidaten.push({ art: "vorabend", datum: t.datum, zeitMs: vorabendZeit(t.datum) });
    if (t.uhrzeit) kandidaten.push({ art: "stundeVorher", datum: t.datum, zeitMs: stundeVorherZeit(t.datum, t.uhrzeit) });
    kandidaten.push({ art: "puenktlichKarte", datum: t.datum, zeitMs: puenktlichZeit(t.datum) });
  }
  for (const m of kontext.angeheftet ?? []) {
    if (m.bis) kandidaten.push({ art: "nachrichtLoesen", id: m.id, von: m.von, zeitMs: Date.parse(m.bis) });
  }
  for (const s of kontext.spielEinladungen ?? []) {
    if (s.bis) kandidaten.push({ art: "spielVerfallen", id: s.id, von: s.von, zeitMs: Date.parse(s.bis) });
  }
  // Immer einen Kandidaten für die Frage des Tages einplanen: entweder heute
  // (falls noch offen -- kann in der Vergangenheit liegen und wird nachgeholt)
  // oder morgen (falls heute schon erledigt). So bleibt immer ein Wach-
  // Zeitpunkt geplant, auch wenn sonst nichts ansteht.
  kandidaten.push({ art: "frageDesTages", zeitMs: naechsteFaelligeTageszeit(jetztMs, 18, 0, kontext.erinnerungenHeute?.frage) });
  if (kontext.streakLaeuftHeuteAb) {
    kandidaten.push({ art: "streakWarnung", zeitMs: naechsteFaelligeTageszeit(jetztMs, 21, 0, kontext.erinnerungenHeute?.streak) });
  }
  // Duell der Woche + Gemeinsam Woche/Monat laufen immer, kein Op-Kontext nötig.
  const ce = kontext.challengeErledigt ?? {};
  kandidaten.push({ art: "challengeEndspurtWoche", zeitMs: naechsteWoechentlicheChallengeZeit(jetztMs, challengeEndspurtWocheZeit, ce.endspurtWoche) });
  kandidaten.push({ art: "challengeEndeWoche", zeitMs: naechsteWoechentlicheChallengeZeit(jetztMs, challengeEndeWocheZeit, ce.endeWoche) });
  kandidaten.push({ art: "challengeEndspurtMonat", zeitMs: naechsteMonatlicheChallengeZeit(jetztMs, challengeEndspurtMonatZeit, ce.endspurtMonat) });
  kandidaten.push({ art: "challengeEndeMonat", zeitMs: naechsteMonatlicheChallengeZeit(jetztMs, challengeEndeMonatZeit, ce.endeMonat) });

  const faellig = kandidaten.filter((k) => k.zeitMs <= jetztMs).sort((a, b) => a.zeitMs - b.zeitMs);
  const kommend = kandidaten.filter((k) => k.zeitMs > jetztMs).sort((a, b) => a.zeitMs - b.zeitMs);
  return { faellig, naechste: kommend[0]?.zeitMs ?? null };
}
