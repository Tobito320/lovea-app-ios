// Server-interner Zustand für die KI-Funktionen (Durable Object Raum):
// Tageszähler pro Person und das "Portionsgedächtnis" (aus Korrekturen
// gelernte typische Mengen). Nutzt die vorhandene Tabelle `merker`, braucht
// also keine Migration. Erreichbar nur über /ki-intern/* -- index.js sperrt
// diesen Pfad nach außen, ki.js ruft ihn über den DO-Stub auf.
import { merkerLesen, merkerSchreiben } from "./raum-logic.js";

const PERSONEN = ["ahmed", "annika"];
const ARTEN = new Set(["essen", "coach", "bericht"]);
const NAMEN_MAX = 200; // so viele verschiedene Lebensmittel pro Person
const FENSTER = 20; // Durchschnitt über etwa die letzten 20 Korrekturen
const DATUM = /^\d{4}-\d{2}-\d{2}$/;

function json(body, status = 200) {
  return Response.json(body, { status });
}

// "Basmatireis (gekocht)" -> "basmatireis"; nur Buchstaben, Ziffern, Leerzeichen.
export function nameNormal(name) {
  return String(name ?? "")
    .toLowerCase()
    .replace(/\(.*?\)/g, " ")
    .replace(/[^a-zäöüß0-9 ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

const nutzungSchluessel = (tag, person, art) => `ki:nutzung:${tag}:${person}:${art}`;

function tagMinus(tag, tage) {
  const d = new Date(`${tag}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - tage);
  return d.toISOString().slice(0, 10);
}

function nutzungLesen(sql, person, art, tag) {
  return Number(merkerLesen(sql, nutzungSchluessel(tag, person, art)) ?? 0);
}

// Zählt eine Nutzung hoch, solange das Tageslimit nicht erreicht ist.
// Kein await zwischen Lesen und Schreiben -> im DO atomar.
export function nutzungZaehlen(sql, person, { art, max, tag }) {
  if (!ARTEN.has(art) || !DATUM.test(String(tag))) return null;
  const limit = Math.min(Math.max(Math.trunc(Number(max)) || 1, 1), 1000);
  const n = nutzungLesen(sql, person, art, tag);
  if (n >= limit) return { erlaubt: false, n, max: limit };
  if (n === 0) {
    // Neuer Tag: alte Zähler (älter als 3 Tage) wegräumen. 'ki:nutzung:' hat 11 Zeichen.
    sql.exec(
      `DELETE FROM merker WHERE schluessel LIKE 'ki:nutzung:%' AND substr(schluessel, 12, 10) < ?`,
      tagMinus(tag, 3)
    );
  }
  merkerSchreiben(sql, nutzungSchluessel(tag, person, art), String(n + 1));
  return { erlaubt: true, n: n + 1, max: limit };
}

// Gibt eine Nutzung zurück (wenn der KI-Aufruf selbst gescheitert ist).
export function nutzungZurueck(sql, person, { art, tag }) {
  if (!ARTEN.has(art) || !DATUM.test(String(tag))) return null;
  const n = nutzungLesen(sql, person, art, tag);
  merkerSchreiben(sql, nutzungSchluessel(tag, person, art), String(Math.max(0, n - 1)));
  return { n: Math.max(0, n - 1) };
}

export function nutzungStand(sql, person, tag) {
  const stand = {};
  for (const art of ARTEN) stand[art] = nutzungLesen(sql, person, art, tag);
  return stand;
}

const portionPrefix = (person) => `ki:portion:${person}:`;

// Lernt aus korrigierten Mahlzeiten: laufender Durchschnitt pro Lebensmittel.
export function portionenKorrigieren(sql, person, items) {
  let gespeichert = 0;
  const liste = Array.isArray(items) ? items.slice(0, 15) : [];
  for (const item of liste) {
    const name = nameNormal(item?.name);
    const gramm = Number(item?.gramm);
    if (!name || !Number.isFinite(gramm) || gramm < 1 || gramm > 2000) continue;
    const schluessel = portionPrefix(person) + name;
    const alt = merkerLesen(sql, schluessel);
    if (alt === null) {
      const zahl = sql.exec(`SELECT COUNT(*) AS c FROM merker WHERE schluessel LIKE ?`, `${portionPrefix(person)}%`).toArray()[0].c;
      if (zahl >= NAMEN_MAX) continue;
      merkerSchreiben(sql, schluessel, JSON.stringify({ g: gramm, n: 1 }));
    } else {
      let a;
      try {
        a = JSON.parse(alt);
      } catch {
        a = { g: gramm, n: 0 };
      }
      const gewicht = Math.min(a.n, FENSTER - 1);
      const neu = { g: (a.g * gewicht + gramm) / (gewicht + 1), n: Math.min(a.n + 1, 1000) };
      merkerSchreiben(sql, schluessel, JSON.stringify(neu));
    }
    gespeichert++;
  }
  return gespeichert;
}

// Die häufigsten gelernten Portionen (für den Prompt), auf 5 g gerundet.
export function portionenLesen(sql, person, anzahl = 8) {
  const zeilen = sql.exec(`SELECT schluessel, wert FROM merker WHERE schluessel LIKE ?`, `${portionPrefix(person)}%`).toArray();
  const liste = [];
  for (const z of zeilen) {
    try {
      const w = JSON.parse(z.wert);
      liste.push({ name: z.schluessel.slice(portionPrefix(person).length), gramm: Math.round(w.g / 5) * 5, n: w.n });
    } catch {
      /* kaputter Eintrag: ignorieren */
    }
  }
  return liste.sort((x, y) => y.n - x.n).slice(0, anzahl);
}

export async function kiIntern(sql, request, person) {
  if (!PERSONEN.includes(person)) return new Response("unauthorized", { status: 401 });
  const pfad = new URL(request.url).pathname;
  let body = {};
  if (request.method === "POST") {
    try {
      body = await request.json();
    } catch {
      return json({ fehler: "ungueltig" }, 400);
    }
  }
  switch (pfad) {
    case "/ki-intern/nutzung": {
      const r = nutzungZaehlen(sql, person, body);
      return r ? json(r) : json({ fehler: "ungueltig" }, 400);
    }
    case "/ki-intern/zurueck": {
      const r = nutzungZurueck(sql, person, body);
      return r ? json(r) : json({ fehler: "ungueltig" }, 400);
    }
    case "/ki-intern/stand": {
      if (!DATUM.test(String(body.tag))) return json({ fehler: "ungueltig" }, 400);
      return json(nutzungStand(sql, person, body.tag));
    }
    case "/ki-intern/korrektur":
      return json({ gespeichert: portionenKorrigieren(sql, person, body.items) });
    case "/ki-intern/portionen":
      return json({ portionen: portionenLesen(sql, person) });
    default:
      return new Response("not found", { status: 404 });
  }
}
