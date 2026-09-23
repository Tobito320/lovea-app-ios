// Pure Raum (Durable Object "Wir") logic. No cloudflare:workers import here on
// purpose, so this file loads and runs under plain Node for tests. raum.js
// wires this up against the real ctx.storage.sql and WebSocket API.
import { berlinDatum } from "./zeitplan.js";

export const SEITE = 500;

export function initSchema(sql) {
  sql.exec(`CREATE TABLE IF NOT EXISTS ops (
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    id TEXT UNIQUE,
    art TEXT NOT NULL,
    von TEXT NOT NULL,
    zeit TEXT NOT NULL,
    d TEXT NOT NULL
  )`);
  sql.exec(`CREATE TABLE IF NOT EXISTS medien (
    id TEXT NOT NULL,
    rolle TEXT NOT NULL,
    teil INTEGER NOT NULL,
    daten BLOB NOT NULL,
    PRIMARY KEY (id, rolle, teil)
  )`);
  sql.exec(`CREATE TABLE IF NOT EXISTS medien_info (
    id TEXT NOT NULL,
    rolle TEXT NOT NULL,
    typ TEXT,
    teile INTEGER,
    bytes INTEGER,
    von TEXT,
    fertig INTEGER NOT NULL DEFAULT 0,
    abgeholt INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (id, rolle)
  )`);
  sql.exec(`CREATE TABLE IF NOT EXISTS geraete (
    person TEXT PRIMARY KEY,
    token TEXT
  )`);
  sql.exec(`CREATE TABLE IF NOT EXISTS standort (
    person TEXT PRIMARY KEY,
    d TEXT NOT NULL,
    zeit TEXT NOT NULL
  )`);
  // Kleiner Key-Value-Speicher für Server-internen Zustand (erledigte Alarme,
  // letzte "Zufällig nah"-Meldung), der NICHT als Op an die Clients geht.
  sql.exec(`CREATE TABLE IF NOT EXISTS merker (
    schluessel TEXT PRIMARY KEY,
    wert TEXT NOT NULL
  )`);
  // Jede Kontext-Berechnung für den Zeitplan fragt mehrfach "alle Ops einer
  // Art" ab (Last: Spec 13) -- ohne Index wäre das ein Full-Table-Scan pro Op.
  sql.exec(`CREATE INDEX IF NOT EXISTS ops_art_von_zeit ON ops (art, von, zeit)`);
}

// --- Merker (Server-interner Zustand, kein Op) ------------------------------

export function merkerLesen(sql, schluessel) {
  const rows = sql.exec(`SELECT wert FROM merker WHERE schluessel = ?`, schluessel).toArray();
  return rows.length ? rows[0].wert : null;
}

export function merkerSchreiben(sql, schluessel, wert) {
  sql.exec(
    `INSERT INTO merker (schluessel, wert) VALUES (?, ?) ON CONFLICT(schluessel) DO UPDATE SET wert = excluded.wert`,
    schluessel,
    wert
  );
}

// --- Ops ---------------------------------------------------------------

const PERSONEN_SET = new Set(["ahmed", "annika"]);

// I-3/M-3/M-4: Form- und Absender-Prüfung, BEVOR eine Op gespeichert wird.
// Prüft nicht die Bedeutung von `d` (die ist je nach `art` verschieden,
// siehe schnittstellen.md) -- nur, dass überhaupt gespeichert werden darf,
// ohne die `ops`-Tabelle zu beschädigen oder auf `.one()` zu crashen (M-4).
// `erwarteteVon`, wenn gesetzt (WebSocket-Pfad): `von` muss zum Absender-Tag
// der Verbindung passen (M-3) -- beim Batch-Import (POST /ops) gibt es keine
// Verbindung, dort reicht "ist überhaupt eine gültige Person".
export function opGueltig(op, erwarteteVon) {
  if (op == null || typeof op !== "object") return false;
  if (typeof op.id !== "string" || op.id.length === 0) return false;
  if (typeof op.art !== "string" || op.art.length === 0) return false;
  if (!PERSONEN_SET.has(op.von)) return false;
  if (typeof op.zeit !== "string" || op.zeit.length === 0) return false;
  if (typeof op.d !== "object" || op.d === null || Array.isArray(op.d)) return false;
  if (erwarteteVon !== undefined && op.von !== erwarteteVon) return false;
  return true;
}

// I-5: ein Socket gilt als verbunden, wenn er entweder noch nie "belauscht"
// wurde (frisch akzeptiert, `letzterKontaktMs === null`) oder sich innerhalb
// der letzten 60s gemeldet hat (Ping oder irgendeine andere Nachricht).
export const PING_TIMEOUT_MS = 60_000;
export function verbindungIstLebendig(letzterKontaktMs, jetztMs) {
  return letzterKontaktMs === null || letzterKontaktMs === undefined || jetztMs - letzterKontaktMs < PING_TIMEOUT_MS;
}

// Speichert eine Op. Doppelte id -> vorhandene seq zurück (INSERT OR IGNORE).
export function opEinfuegen(sql, op) {
  sql.exec(
    `INSERT OR IGNORE INTO ops (id, art, von, zeit, d) VALUES (?, ?, ?, ?, ?)`,
    op.id,
    op.art,
    op.von,
    op.zeit,
    JSON.stringify(op.d ?? {})
  );
  const row = sql.exec(`SELECT seq FROM ops WHERE id = ?`, op.id).one();
  return row.seq;
}

// Wie opEinfuegen, meldet aber zusätzlich, ob die Op neu war (für Push/Broadcast:
// eine Wiederholung nach Funkloch soll nicht noch einmal Krach machen).
export function opEinfuegenMitStatus(sql, op) {
  const vorher = sql.exec(`SELECT seq FROM ops WHERE id = ?`, op.id).toArray();
  if (vorher.length) return { seq: vorher[0].seq, neu: false };
  const seq = opEinfuegen(sql, op);
  return { seq, neu: true };
}

function zeileZuOp(row) {
  return { seq: row.seq, id: row.id, art: row.art, von: row.von, zeit: row.zeit, d: JSON.parse(row.d) };
}

// Seite von Ops ab (ausschließlich) `seit`, höchstens `SEITE` Stück.
export function opsSeit(sql, seit, limit = SEITE) {
  const rows = sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE seq > ? ORDER BY seq ASC LIMIT ?`, seit, limit + 1)
    .toArray();
  const mehr = rows.length > limit;
  const ops = rows.slice(0, limit).map(zeileZuOp);
  return { ops, mehr };
}

// Letzte Op einer Art von einer Person (für Einstellungen, Streak, etc.).
export function letzteOpVon(sql, von, art) {
  const rows = sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE von = ? AND art = ? ORDER BY seq DESC LIMIT 50`, von, art)
    .toArray();
  return rows.length ? zeileZuOp(rows[0]) : null;
}

export function alleOpsVon(sql, von, art) {
  return sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE von = ? AND art = ? ORDER BY seq DESC`, von, art)
    .toArray()
    .map(zeileZuOp);
}

export function alleOpsArt(sql, art) {
  return sql
    .exec(`SELECT seq, id, art, von, zeit, d FROM ops WHERE art = ? ORDER BY seq ASC`, art)
    .toArray()
    .map(zeileZuOp);
}

// Neuester Wert einer Einstellung `schluessel` für `person` (z. B. "mitteilungen.chat").
export function einstellung(sql, person, schluessel) {
  const rows = alleOpsVon(sql, person, "einstellung.setzen");
  const treffer = rows.find((op) => op.d.schluessel === schluessel);
  return treffer ? treffer.d.wert : undefined;
}

// --- Medien --------------------------------------------------------------

export function medienTeilSpeichern(sql, id, rolle, teil, daten) {
  sql.exec(`INSERT OR REPLACE INTO medien (id, rolle, teil, daten) VALUES (?, ?, ?, ?)`, id, rolle, teil, daten);
}

function vorhandeneTeile(sql, id, rolle) {
  return sql
    .exec(`SELECT teil FROM medien WHERE id = ? AND rolle = ? ORDER BY teil ASC`, id, rolle)
    .toArray()
    .map((r) => r.teil);
}

// C-1: `vorhanden` ist die verlässliche Quelle und IMMER korrekt, auch für
// eine unbekannte/neue id ([]) -- der Client kann seinen Upload-Plan daraus
// bauen (alle 0..gesamt-1, die nicht in `vorhanden` stehen), unabhängig davon,
// wie `fehlend` gemeint ist. Teile zählen serverweit ab 0 (0-based).
//
// `gesamt` (aus `?teile=N`, wenn der Client seine Gesamtzahl schon kennt):
// dann ist `fehlend` die volle Komplementmenge 0..gesamt-1 \ vorhanden, und
// `gesamt` steht mit in der Antwort. Ohne `gesamt` (Gesamtzahl noch nicht
// bekannt, z. B. vor dem ersten `fertig`-Versuch) bleibt `fehlend` best-effort
// auf die Lücken unterhalb des bisher höchsten Teils beschränkt -- mehr lässt
// sich ohne die Gesamtzahl nicht sagen.
export function medienFehlend(sql, id, rolle, gesamt) {
  const vorhanden = vorhandeneTeile(sql, id, rolle);
  const vorhandenSet = new Set(vorhanden);

  if (gesamt != null) {
    const fehlend = [];
    for (let i = 0; i < gesamt; i++) if (!vorhandenSet.has(i)) fehlend.push(i);
    return { vorhanden, fehlend, gesamt };
  }

  const fehlend = [];
  if (vorhanden.length) {
    const max = vorhanden[vorhanden.length - 1];
    for (let i = 0; i < max; i++) if (!vorhandenSet.has(i)) fehlend.push(i);
  }
  return { vorhanden, fehlend };
}

// Markiert ein Medium als fertig, wenn wirklich alle `teile` Stück da sind.
export function medienFertig(sql, id, rolle, { teile, typ, bytes, von }) {
  const vorhanden = new Set(vorhandeneTeile(sql, id, rolle));
  for (let i = 0; i < teile; i++) {
    if (!vorhanden.has(i)) return { fertig: false, fehlend: medienFehlend(sql, id, rolle).fehlend };
  }
  sql.exec(
    `INSERT INTO medien_info (id, rolle, typ, teile, bytes, von, fertig, abgeholt)
     VALUES (?, ?, ?, ?, ?, ?, 1, 0)
     ON CONFLICT(id, rolle) DO UPDATE SET typ = excluded.typ, teile = excluded.teile, bytes = excluded.bytes, von = excluded.von, fertig = 1`,
    id,
    rolle,
    typ,
    teile,
    bytes,
    von
  );
  return { fertig: true };
}

function medienInfo(sql, id, rolle) {
  const rows = sql.exec(`SELECT * FROM medien_info WHERE id = ? AND rolle = ?`, id, rolle).toArray();
  return rows[0] ?? null;
}

// ponytail: baut das ganze Medium im DO-Speicher zusammen (M-6) -- bei
// großen Videos droht das 128-MB-Limit. Upgrade-Weg: Response mit einem
// ReadableStream füttern, der Teil für Teil aus `medien` liest, statt hier
// zu konkatenieren. Für 1-MiB-Teile und Fotos/kurze Clips unkritisch, daher
// zurückgestellt.
function medienBytes(sql, id, rolle) {
  const teile = sql.exec(`SELECT daten FROM medien WHERE id = ? AND rolle = ? ORDER BY teil ASC`, id, rolle).toArray();
  const gesamt = teile.reduce((n, t) => n + t.daten.byteLength, 0);
  const out = new Uint8Array(gesamt);
  let off = 0;
  for (const t of teile) {
    out.set(new Uint8Array(t.daten), off);
    off += t.daten.byteLength;
  }
  return out;
}

function medienLoeschen(sql, id, rolle) {
  sql.exec(`DELETE FROM medien WHERE id = ? AND rolle = ?`, id, rolle);
  sql.exec(`DELETE FROM medien_info WHERE id = ? AND rolle = ?`, id, rolle);
}

// Original löschen, sobald der Partner es geholt hat und `klein` existiert.
function originalAufraeumen(sql, id) {
  const original = medienInfo(sql, id, "original");
  const klein = medienInfo(sql, id, "klein");
  if (original?.fertig && original.abgeholt && klein?.fertig) {
    medienLoeschen(sql, id, "original");
  }
}

// Liefert {rolle, typ, bytes:Uint8Array} für GET /medien/<id>, oder null.
export function medienLesen(sql, id, anfragendePerson) {
  const original = medienInfo(sql, id, "original");
  if (original?.fertig) {
    const daten = medienBytes(sql, id, "original");
    if (anfragendePerson && anfragendePerson !== original.von) {
      sql.exec(`UPDATE medien_info SET abgeholt = 1 WHERE id = ? AND rolle = 'original'`, id);
      originalAufraeumen(sql, id);
    }
    return { rolle: "original", typ: original.typ, daten };
  }
  const klein = medienInfo(sql, id, "klein");
  if (klein?.fertig) {
    return { rolle: "klein", typ: klein.typ, daten: medienBytes(sql, id, "klein") };
  }
  return null;
}

// Wird nach einem erfolgreichen "klein"-fertig aufgerufen: falls das Original
// bereits als abgeholt markiert war, kann es jetzt weg.
export function medienNachFertigAufraeumen(sql, id, rolle) {
  if (rolle === "klein") originalAufraeumen(sql, id);
}

// --- Standort (gedrosselt) ------------------------------------------------

const STANDORT_DROSSEL_MS = 60_000;

export function standortSchreiben(sql, person, d, zeitIso, jetztMs) {
  const bisher = sql.exec(`SELECT zeit FROM standort WHERE person = ?`, person).toArray();
  if (bisher.length) {
    const letztMs = Date.parse(bisher[0].zeit);
    if (jetztMs - letztMs < STANDORT_DROSSEL_MS) return false;
  }
  sql.exec(
    `INSERT INTO standort (person, d, zeit) VALUES (?, ?, ?)
     ON CONFLICT(person) DO UPDATE SET d = excluded.d, zeit = excluded.zeit`,
    person,
    JSON.stringify(d),
    zeitIso
  );
  return true;
}

export function letzterStandort(sql, person) {
  const rows = sql.exec(`SELECT d, zeit FROM standort WHERE person = ?`, person).toArray();
  if (!rows.length) return null;
  return { d: JSON.parse(rows[0].d), zeit: rows[0].zeit };
}

// --- Geräte (Push-Token) ---------------------------------------------------

export function geraetSpeichern(sql, person, token) {
  sql.exec(
    `INSERT INTO geraete (person, token) VALUES (?, ?)
     ON CONFLICT(person) DO UPDATE SET token = excluded.token`,
    person,
    token
  );
}

export function geraetToken(sql, person) {
  const rows = sql.exec(`SELECT token FROM geraete WHERE person = ?`, person).toArray();
  return rows[0]?.token ?? null;
}

export function geraetLoeschen(sql, person) {
  sql.exec(`DELETE FROM geraete WHERE person = ?`, person);
}

// Letzter Zeitpunkt (ms) einer "Zufällig nah"-Meldung, für die 6h-Drossel --
// im Merker gespeichert (kein Op), überlebt also DO-Hibernation.
export function letzteZufaelligNahMs(sql) {
  const wert = merkerLesen(sql, "nah.letzte");
  return wert === null ? null : Number(wert);
}

export function zufaelligNahAlsGemeldetMarkieren(sql, jetztMs) {
  merkerSchreiben(sql, "nah.letzte", String(jetztMs));
}

// --- Zufällig nah (Z-1.8) --------------------------------------------------

const ERDRADIUS_M = 6_371_000;

function distanzMeter(a, b) {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const s =
    Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * ERDRADIUS_M * Math.asin(Math.sqrt(s));
}

// Prüft die Bedingung für "Zufällig nah" (Spec 7 / Z-1.8). `heuteTreffen`:
// true, wenn für den heutigen Tag (Europe/Berlin) ein Treffen eingetragen ist.
export function zufaelligNah({ a, b, jetztMs, heuteTreffen }) {
  if (heuteTreffen) return false;
  if (!a || !b) return false;
  if (jetztMs - Date.parse(a.zeit) >= 10 * 60_000) return false;
  if (jetztMs - Date.parse(b.zeit) >= 10 * 60_000) return false;
  return distanzMeter(a.d, b.d) < 100;
}

// --- Zeitplan-Kontext (Z-1.7): aus den Ops abgeleiteter Stand, den
// zeitplan.naechsterAlarm() braucht. Reine Ableitung, keine Zeitpläne selbst. --

// Offene Treffen ab `heuteDatum` (>=), jüngste Fassung pro Kalendertag gewinnt.
export function offeneTreffen(sql, heuteDatum) {
  const gesetzt = alleOpsArt(sql, "treffen.setzen");
  const geloescht = new Set(alleOpsArt(sql, "treffen.loeschen").map((o) => o.d.datum));
  const byDatum = new Map();
  for (const op of gesetzt) byDatum.set(op.d.datum, op.d); // aufsteigende seq: später überschreibt früher
  const ergebnis = [];
  for (const [datum, d] of byDatum) {
    if (geloescht.has(datum) || datum < heuteDatum) continue;
    ergebnis.push({ datum, uhrzeit: d.uhrzeit });
  }
  return ergebnis;
}

// Noch nicht losgelöste angeheftete Nachrichten mit einer Ablaufzeit.
export function offeneAngeheftet(sql) {
  const gesetzt = alleOpsArt(sql, "nachricht.angeheftet");
  const geloest = new Set(alleOpsArt(sql, "nachricht.losgeloest").map((o) => o.d.id));
  const byId = new Map();
  for (const op of gesetzt) byId.set(op.d.id, { id: op.d.id, bis: op.d.bis, von: op.von });
  return [...byId.values()].filter((x) => x.bis && !geloest.has(x.id));
}

// Noch offene (weder angenommene noch verfallene) Spiel-Einladungen.
export function offeneSpielEinladungen(sql) {
  const gesetzt = alleOpsArt(sql, "spiel.einladung");
  const erledigt = new Set([
    ...alleOpsArt(sql, "spiel.angenommen").map((o) => o.d.id),
    ...alleOpsArt(sql, "spiel.verfallen").map((o) => o.d.id),
  ]);
  const byId = new Map();
  for (const op of gesetzt) byId.set(op.d.id, { id: op.d.id, bis: op.d.bis, von: op.von });
  return [...byId.values()].filter((x) => !erledigt.has(x.id));
}

// Neueste Fassung eines Orts (für Namen/`melden` bei ort.ereignis-Push).
export function ortInfo(sql, ortId) {
  const treffer = alleOpsArt(sql, "ort.setzen").filter((op) => op.d.id === ortId);
  return treffer.length ? treffer[treffer.length - 1].d : null;
}

// Streak: beide aktiv (mind. eine echte, nicht-System-nachricht.neu) an
// aufeinanderfolgenden Tagen. "läuft heute ab": gestern waren beide aktiv,
// heute (bisher) noch nicht beide. Auf die letzten Tage begrenzt (Last, Spec 13).
function aktiveTage(sql, person, seitIso) {
  const rows = sql
    .exec(`SELECT zeit, d FROM ops WHERE art = 'nachricht.neu' AND von = ? AND zeit >= ? ORDER BY seq ASC`, person, seitIso)
    .toArray();
  const tage = new Set();
  for (const row of rows) {
    const d = JSON.parse(row.d);
    if (d.system) continue; // Systemnachrichten (z. B. "zufällig nah") zählen nicht für den Streak.
    tage.add(berlinDatum(Date.parse(row.zeit)));
  }
  return tage;
}

export function streakLaeuftHeuteAb(sql, jetztMs) {
  const heute = berlinDatum(jetztMs);
  const gestern = berlinDatum(jetztMs - 86_400_000);
  const seit = new Date(jetztMs - 3 * 86_400_000).toISOString(); // Puffer über Zeitzone/DST
  const ahmed = aktiveTage(sql, "ahmed", seit);
  const annika = aktiveTage(sql, "annika", seit);
  return ahmed.has(gestern) && annika.has(gestern) && !(ahmed.has(heute) && annika.has(heute));
}

// Markiert, dass ein zeitgesteuertes Ereignis (Vorabend, 1h-vorher,
// Frage-des-Tages, Streak-Warnung, ...) für einen Schlüssel schon erledigt
// ist -- damit der nächste Alarm es nicht noch einmal auslöst. Liegt im
// Merker, nicht in den Ops: das ist Server-Buchhaltung, kein Chat-Ereignis,
// und soll nicht als unbekannte Op-Art beim Client ankommen.
export function alarmErledigt(sql, art, schluessel) {
  return merkerLesen(sql, `alarm.${art}.${schluessel}`) !== null;
}

export function alarmAlsErledigtMarkieren(sql, art, schluessel, jetztIso) {
  merkerSchreiben(sql, `alarm.${art}.${schluessel}`, jetztIso);
}
