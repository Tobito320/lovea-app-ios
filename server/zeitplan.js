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

// kontext, von raum.js aus den Ops gebaut:
// {
//   treffen: [{datum:"YYYY-MM-DD", uhrzeit?:"HH:mm"}],
//   angeheftet: [{id, bis}],            // noch nicht losgelöste Nachrichten mit Ablauf
//   spielEinladungen: [{id, bis}],      // noch offene Einladungen
//   streakLaeuftHeuteAb: boolean,
//   erinnerungenHeute: {frage: boolean, streak: boolean},
// }
export function naechsterAlarm(kontext, jetztMs) {
  const kandidaten = [];
  for (const t of kontext.treffen ?? []) {
    kandidaten.push({ art: "vorabend", datum: t.datum, zeitMs: vorabendZeit(t.datum) });
    if (t.uhrzeit) kandidaten.push({ art: "stundeVorher", datum: t.datum, zeitMs: stundeVorherZeit(t.datum, t.uhrzeit) });
    kandidaten.push({ art: "puenktlichKarte", datum: t.datum, zeitMs: puenktlichZeit(t.datum) });
  }
  for (const m of kontext.angeheftet ?? []) {
    if (m.bis) kandidaten.push({ art: "nachrichtLoesen", id: m.id, zeitMs: Date.parse(m.bis) });
  }
  for (const s of kontext.spielEinladungen ?? []) {
    if (s.bis) kandidaten.push({ art: "spielVerfallen", id: s.id, zeitMs: Date.parse(s.bis) });
  }
  if (!kontext.erinnerungenHeute?.frage) {
    kandidaten.push({ art: "frageDesTages", zeitMs: naechsteTageszeit(jetztMs, 18, 0) });
  }
  if (kontext.streakLaeuftHeuteAb && !kontext.erinnerungenHeute?.streak) {
    kandidaten.push({ art: "streakWarnung", zeitMs: naechsteTageszeit(jetztMs, 21, 0) });
  }

  const faellig = kandidaten.filter((k) => k.zeitMs <= jetztMs).sort((a, b) => a.zeitMs - b.zeitMs);
  const kommend = kandidaten.filter((k) => k.zeitMs > jetztMs).sort((a, b) => a.zeitMs - b.zeitMs);
  return { faellig, naechste: kommend[0]?.zeitMs ?? null };
}
