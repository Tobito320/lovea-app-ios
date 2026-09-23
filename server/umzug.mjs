#!/usr/bin/env node
// Umzugsskript (Block 11, Z-11.1/Z-11.3): liest die alte Web-App-Daten aus
// Supabase (Tabelle blobs) und aus inhalt/termine.json und schreibt sie als
// Ops in den neuen Cloudflare-Raum. Einmalig, read-only gegen Supabase.
//
// Aufruf:
//   node --env-file=C:\Users\ahmed\code\lovea-app\.env server/umzug.mjs --ziel test --trocken
//   node --env-file=C:\Users\ahmed\code\lovea-app\.env server/umzug.mjs --ziel test
//   node --env-file=C:\Users\ahmed\code\lovea-app\.env server/umzug.mjs --ziel live
//
// --trocken zaehlt nur (keine Netzwerkanfrage an den Worker). Ohne --trocken
// laedt es Medien hoch, schickt die Ops per POST /ops und prueft danach per
// WebSocket (seit=0), dass alle migrierten Ops (Id-Praefix "umzug:") wirklich
// im Raum stehen.
//
// Sicherheit: nie den SUPABASE_SERVICE_KEY oder einzelne Blob-Keys/Inhalte
// loggen -- nur Zahlen und Praefixe.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const SCHLUESSEL_PFAD = "C:\\Users\\ahmed\\code\\lovea-app-ios\\signing\\lovea-app.key";
const TERMINE_PFAD = "C:\\Users\\ahmed\\code\\lovea-app\\inhalt\\termine.json";
const AUSGESCHLOSSENE_PRAEFIXE = ["test/", "stage/", "probe/", "lern/"];

const ZIELE = {
  test: "https://lovea-test.ahmedhdplay12345.workers.dev",
  live: "https://lovea-live.ahmedhdplay12345.workers.dev",
};

const PERSONEN = ["ahmed", "annika"];
const ANDERE = { ahmed: "annika", annika: "ahmed" };

// perfekt/passt/zuspaet stehen wörtlich in block-11.md. "skip" (in der alten App: der
// Tag wurde absichtlich nicht bewertet) hat dort kein Gegenstück -- ponytail: auf "weg"
// abgebildet, der einzige der vier neuen Werte ohne alte Entsprechung, statt Daten zu verwerfen.
const PUENKTLICH_WERT = { perfekt: "uhrwerk", passt: "charmant", zuspaet: "troedel", skip: "weg" };

// Die alte App kennt genau einen festen Plan (server/plaene.mjs in lovea-app). Ein zweiter
// Plan bräuchte hier eine weitere Zeile -- ponytail: kein Nachladen aus der alten App für
// ein Skript, das nur einmal läuft.
const PLAENE = { halloween: { datum: "2026-10-31", besitzerin: "annika" } };

function op(id, art, von, zeit, d) {
  return { id, art, von, zeit, d };
}

// PNG: 8-Byte-Signatur, dann IHDR-Chunk mit Breite/Höhe als 4-Byte-BE ab Offset 16.
// Für Aufkleber/Galerie-Ebenen reicht "Bild als Medium", die brauchen keine Maße.
function bildAbmessung(dataUrl) {
  const komma = dataUrl.indexOf(",");
  const buf = Buffer.from(dataUrl.slice(komma + 1, komma + 1 + 40), "base64");
  return { breite: buf.readUInt32BE(16), hoehe: buf.readUInt32BE(20) };
}

function bildTyp(dataUrl) {
  return /^data:(.*?);base64,/.exec(dataUrl)?.[1] ?? "application/octet-stream";
}

// Medien-Ids laufen (anders als Op-Ids) in der URL mit (PUT /medien/<id>/...), dürfen also
// keine "/" enthalten -- sonst verschiebt sich raum.js' Pfad-Split und die Route passt nicht
// mehr. ponytail: einfache Zeichen-Ersetzung statt Hash; Kollisionen bräuchten zwei Schlüssel,
// die sich nur in Sonderzeichen unterscheiden -- neueId() liefert nie welche.
function medienId(key, suffix = "") {
  const kern = key.replace(/[^A-Za-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return `umzug-${kern}${suffix ? `-${suffix}` : ""}`;
}

// Reine Abbildung eines Supabase-Blob-Datensatzes ({key, wert, geaendert}) auf Ops +
// hochzuladende Medien. Keine I/O hier -- das macht main() -- deshalb ohne Netz testbar.
export function zeileZuEintraege(zeile) {
  const { key, wert: d, geaendert } = zeile;
  const ops = [];
  const medien = [];
  let m;

  if ((m = /^kalender\/(\d{4}-\d{2}-\d{2})$/.exec(key))) {
    const [, iso] = m;
    // herz ist das Treffen-Häkchen, gemeinsam ("was macht ihr") ist davon unabhängig editierbar
    // (kalender.mjs: `if ('gemeinsam' in b) neu.gemeinsam = ...`, ohne Herz-Prüfung). Die neue
    // App hat für einen reinen Plan-Text ohne Herz kein eigenes Feld -- treffen.setzen ist das
    // einzige Ziel dafür, also auch ohne herz emittieren, wenn gemeinsam/uhrzeit gesetzt ist.
    if (d.herz || d.gemeinsam || d.uhrzeit) {
      ops.push(
        op(`umzug:${key}:treffen`, "treffen.setzen", d.von ?? "ahmed", geaendert, {
          datum: iso,
          ...(d.uhrzeit ? { uhrzeit: d.uhrzeit } : {}),
          ...(d.gemeinsam ? { wasMachenWir: d.gemeinsam } : {}),
        })
      );
    }
    for (const person of PERSONEN) {
      const text = d.notizen?.[person];
      if (text) ops.push(op(`umzug:${key}:notiz:${person}`, "notiz.setzen", person, geaendert, { datum: iso, text }));
      const stimmung = d.stimmung?.[person];
      if (stimmung) ops.push(op(`umzug:${key}:stimmung:${person}`, "stimmung.setzen", person, geaendert, { datum: iso, stimmung }));
    }
    return { ops, medien };
  }

  if ((m = /^puenktlich\/(\d{4}-\d{2}-\d{2})$/.exec(key))) {
    const [, iso] = m;
    for (const [feld, von, ueber] of [
      ["vonAhmed", "ahmed", "annika"],
      ["vonAnnika", "annika", "ahmed"],
    ]) {
      const wert = PUENKTLICH_WERT[d[feld]];
      if (wert) ops.push(op(`umzug:${key}:${von}`, "puenktlich.setzen", von, geaendert, { datum: iso, ueber, wert }));
    }
    return { ops, medien };
  }

  if ((m = /^antwort\/([^/]+)\/(ahmed|annika)$/.exec(key))) {
    const [, frageId, person] = m;
    ops.push(op(`umzug:${key}`, "frage.antwort", person, d.zeit ?? geaendert, { frageId, text: d.text }));
    return { ops, medien };
  }

  if (key.startsWith("frage/")) {
    ops.push(op(`umzug:${key}`, "frage.eigene", d.von, d.zeit ?? geaendert, { id: d.id, text: d.text, kategorie: null }));
    return { ops, medien };
  }

  if (key.startsWith("thema/")) {
    ops.push(op(`umzug:${key}`, "thema.setzen", d.von, d.zeit ?? geaendert, { id: d.id, text: d.text, besprochen: d.besprochen ?? null }));
    return { ops, medien };
  }

  if (key.startsWith("zukunft/")) {
    ops.push(op(`umzug:${key}`, "liste.setzen", d.von, d.zeit ?? geaendert, { id: d.id, text: d.text, geschafft: d.geschafft ?? null }));
    return { ops, medien };
  }

  if (key.startsWith("date/")) {
    ops.push(op(`umzug:${key}`, "idee.neu", d.von, d.zeit ?? geaendert, { id: d.id, text: d.text }));
    return { ops, medien };
  }

  if ((m = /^plan\/([^/]+)\/([^/]+)$/.exec(key))) {
    const [, planId, punktId] = m;
    const plan = PLAENE[planId];
    if (!plan) return { ops, medien }; // unbekannter Plan -- lieber auslassen als raten
    ops.push(
      op(`umzug:${key}`, "checkliste.setzen", plan.besitzerin, d.zeit ?? geaendert, {
        datum: plan.datum,
        id: punktId,
        text: d.text,
        erledigt: !!d.erledigt,
      })
    );
    return { ops, medien };
  }

  if (key.startsWith("zeichnung/")) {
    const opId = `umzug:${key}`;
    const mId = medienId(key);
    const { breite, hoehe } = bildAbmessung(d.bild);
    medien.push({ id: mId, dataUrl: d.bild, von: d.von });
    ops.push(
      op(opId, "nachricht.neu", d.von, d.zeit ?? geaendert, {
        id: opId,
        medien: [{ id: mId, typ: "foto", breite, hoehe }],
      })
    );
    return { ops, medien };
  }

  // Z-11.2 (App-Seite, andere Instanz) erwartet laut block-11.md pro alter Ebene eine
  // Bild-Ebene mit Deckkraft/Modus/Clipping/Schutz/Sichtbarkeit -- d bildet das 1:1 ab.
  if ((m = /^galerie\/(ahmed|annika)\/(.+)$/.exec(key))) {
    const [, person, id] = m;
    const ebenen = (d.ebenen ?? []).map((e, i) => {
      const mId = medienId(key, `ebene${i}`);
      medien.push({ id: mId, dataUrl: e.bild, von: person });
      return { medienId: mId, name: e.name, deckkraft: e.deckkraft, modus: e.modus, clip: e.clip, schuetzt: e.schuetzt, sichtbar: e.sichtbar };
    });
    ops.push(
      op(`umzug:${key}`, "umzug.galerie", person, d.zeit ?? geaendert, { id, name: d.name, format: d.format, papier: d.papier, ebenen })
    );
    return { ops, medien };
  }

  if ((m = /^aufkleber\/(ahmed|annika)\/(.+)$/.exec(key))) {
    const [, person, id] = m;
    const mId = medienId(key);
    medien.push({ id: mId, dataUrl: d.bild, von: person });
    ops.push(op(`umzug:${key}`, "umzug.aufkleber", person, d.zeit ?? geaendert, { id, name: d.name, medienId: mId }));
    return { ops, medien };
  }

  return { ops, medien }; // unbekannter/nicht migrierter Schlüssel -- wird ignoriert und gezählt
}

export function termineZuOps(termine, jetztIso) {
  return termine.map((t, i) =>
    op(`umzug:termine:${t.iso}:${i}`, "termin.setzen", "ahmed", jetztIso, {
      id: `umzug-termin-${t.iso}-${i}`,
      fuer: t.wer === "wir" ? ["ahmed", "annika"] : [t.wer],
      titel: t.t,
      typ: "sonstiges",
      datum: t.iso,
    })
  );
}

// Vor dem Posten prüfen statt mittendrin an einem NOT-NULL-Constraint scheitern und den Raum
// halb befüllt zurücklassen (ops.von/zeit sind in raum-logic.js initSchema() NOT NULL).
export function pruefeOps(ops) {
  const fehler = [];
  for (const o of ops) {
    if (!PERSONEN.includes(o.von)) fehler.push(`${o.art}: von "${o.von}" ist keine Person`);
    if (!o.zeit || Number.isNaN(Date.parse(o.zeit))) fehler.push(`${o.art}: zeit "${o.zeit}" ist kein Datum`);
    if (!o.id) fehler.push(`${o.art}: id fehlt`);
  }
  return fehler;
}

export function zaehlung(ops) {
  const arten = new Map();
  for (const o of ops) arten.set(o.art, (arten.get(o.art) ?? 0) + 1);
  return arten;
}

function praefixVon(key) {
  const i = key.indexOf("/");
  return i === -1 ? key : key.slice(0, i + 1);
}

// --- Supabase (read-only) ---------------------------------------------------

async function supabaseZeilenLaden() {
  const basis = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const schluessel = process.env.SUPABASE_SERVICE_KEY || "";
  if (!basis || !schluessel) throw new Error("SUPABASE_URL und SUPABASE_SERVICE_KEY fehlen (--env-file?).");
  const headers = { apikey: schluessel, authorization: `Bearer ${schluessel}` };

  const SEITE = 1000;
  const alle = [];
  for (let von = 0; ; von += SEITE) {
    const res = await fetch(`${basis}/rest/v1/blobs?select=key,wert,geaendert&order=key`, {
      headers: { ...headers, Range: `${von}-${von + SEITE - 1}` },
    });
    if (!res.ok && res.status !== 206) throw new Error(`Supabase ${res.status}`);
    const seite = await res.json();
    alle.push(...seite);
    if (seite.length < SEITE) break;
  }
  return alle;
}

// --- Worker-Client -----------------------------------------------------------

async function medienHochladen(basisUrl, schluessel, { id, dataUrl, von }) {
  const komma = dataUrl.indexOf(",");
  const typ = bildTyp(dataUrl);
  const bytes = Buffer.from(dataUrl.slice(komma + 1), "base64");
  const headers = { "X-Lovea-Key": schluessel, "X-Lovea-Person": von };
  const TEIL = 1024 * 1024;
  let teile = 0;
  for (let off = 0; off < bytes.length; off += TEIL, teile++) {
    const stueck = bytes.subarray(off, off + TEIL);
    const res = await fetch(`${basisUrl}/medien/${id}/original/${teile}`, { method: "PUT", headers, body: stueck });
    if (!res.ok) throw new Error(`Medien-Upload fehlgeschlagen: ${res.status}`);
  }
  const fertig = await fetch(`${basisUrl}/medien/${id}/original/fertig`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json" },
    body: JSON.stringify({ teile, typ, bytes: bytes.length }),
  });
  if (!fertig.ok) throw new Error(`Medien-fertig fehlgeschlagen: ${fertig.status}`);
}

// Holt ein hochgeladenes Medium als der Partner ab (wie die App das täte) und vergleicht die
// Byte-Länge -- ein Zähler allein sagt nichts darüber, ob PUT/fertig wirklich das Richtige
// gespeichert haben.
async function medienUeberpruefen(basisUrl, schluessel, { id, dataUrl, von }) {
  const bytes = Buffer.from(dataUrl.slice(dataUrl.indexOf(",") + 1), "base64");
  const res = await fetch(`${basisUrl}/medien/${id}`, {
    headers: { "X-Lovea-Key": schluessel, "X-Lovea-Person": ANDERE[von] },
  });
  if (!res.ok) throw new Error(`Medium ${id} nicht lesbar: ${res.status}`);
  const zurueck = new Uint8Array(await res.arrayBuffer());
  if (zurueck.length !== bytes.length) throw new Error(`Medium ${id}: ${zurueck.length} Bytes zurück, ${bytes.length} erwartet`);
}

async function opsPosten(basisUrl, schluessel, ops) {
  const STAPEL = 200;
  for (let i = 0; i < ops.length; i += STAPEL) {
    const stapel = ops.slice(i, i + STAPEL);
    const res = await fetch(`${basisUrl}/ops`, {
      method: "POST",
      headers: { "X-Lovea-Key": schluessel, "X-Lovea-Person": "ahmed", "content-type": "application/json" },
      body: JSON.stringify({ ops: stapel }),
    });
    if (!res.ok) throw new Error(`POST /ops fehlgeschlagen: ${res.status}`);
  }
}

// Zaehlt per WebSocket (seit=0, wie pruefen.mjs) alle Ops mit Id-Praefix "umzug:" nach Art --
// so bleiben echte App-Ops im selben Raum unberuehrt vom Vergleich.
async function migrierteZaehlungImRaum(basisUrl, schluessel) {
  const wsBasis = basisUrl.replace(/^http/, "ws");
  const arten = new Map();
  let seit = 0;
  for (;;) {
    const seite = await new Promise((resolve, reject) => {
      const ws = new WebSocket(`${wsBasis}/raum?seit=${seit}&key=${encodeURIComponent(schluessel)}&person=ahmed`);
      const timeout = setTimeout(() => reject(new Error("Timeout beim Zaehlen")), 20000);
      ws.addEventListener("message", (ev) => {
        const msg = JSON.parse(ev.data);
        if (msg.t !== "ops") return;
        clearTimeout(timeout);
        ws.close();
        resolve(msg);
      });
      ws.addEventListener("error", reject);
    });
    for (const o of seite.ops) if (o.id.startsWith("umzug:")) arten.set(o.art, (arten.get(o.art) ?? 0) + 1);
    if (!seite.mehr || !seite.ops.length) break;
    seit = seite.ops.at(-1).seq;
  }
  return arten;
}

function tabelle(arten) {
  const zeilen = [...arten.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  const gesamt = zeilen.reduce((n, [, c]) => n + c, 0);
  for (const [art, n] of zeilen) console.log(`  ${art.padEnd(24)} ${n}`);
  console.log(`  ${"gesamt".padEnd(24)} ${gesamt}`);
}

async function main() {
  const args = process.argv.slice(2);
  const ziel = args[args.indexOf("--ziel") + 1];
  const trocken = args.includes("--trocken");
  if (!ZIELE[ziel]) {
    console.error("Aufruf: node server/umzug.mjs --ziel <test|live> [--trocken]");
    process.exit(1);
  }
  const basisUrl = ZIELE[ziel];

  const zeilen = await supabaseZeilenLaden();
  const live = zeilen.filter((z) => !AUSGESCHLOSSENE_PRAEFIXE.some((p) => z.key.startsWith(p)));
  console.log(`Supabase: ${zeilen.length} Zeilen gesamt, ${live.length} live (ohne test/stage/probe/lern).`);

  const ops = [];
  const medien = [];
  const ignoriertePraefixe = new Map();
  for (const zeile of live) {
    const { ops: neueOps, medien: neueMedien } = zeileZuEintraege(zeile);
    if (!neueOps.length) ignoriertePraefixe.set(praefixVon(zeile.key), (ignoriertePraefixe.get(praefixVon(zeile.key)) ?? 0) + 1);
    ops.push(...neueOps);
    medien.push(...neueMedien);
  }

  const termine = JSON.parse(readFileSync(TERMINE_PFAD, "utf8"));
  ops.push(...termineZuOps(termine, new Date().toISOString()));

  const opFehler = pruefeOps(ops);
  if (opFehler.length) {
    console.error("Ungültige Ops, breche ab:");
    for (const f of opFehler) console.error(`  ${f}`);
    process.exit(1);
  }

  console.log("\nOps pro Art:");
  const erwartet = zaehlung(ops);
  tabelle(erwartet);
  console.log(`\nMedien zum Hochladen: ${medien.length}`);
  if (ignoriertePraefixe.size) {
    console.log("\nNicht migrierte Praefixe (nicht in block-11.md gelistet):");
    for (const [praefix, n] of ignoriertePraefixe) console.log(`  ${praefix.padEnd(24)} ${n}`);
  }

  if (trocken) {
    console.log("\nTrockenlauf -- keine Netzwerkanfrage an den Worker.");
    return;
  }

  const schluessel = readFileSync(SCHLUESSEL_PFAD, "utf8").trim();

  console.log(`\nLade ${medien.length} Medien nach ${ziel} hoch ...`);
  let hochgeladen = 0;
  for (const m of medien) {
    await medienHochladen(basisUrl, schluessel, m);
    hochgeladen++;
    if (hochgeladen % 10 === 0 || hochgeladen === medien.length) console.log(`  ${hochgeladen}/${medien.length}`);
  }

  console.log(`Pruefe ${medien.length} hochgeladene Medien (Abruf als Partner) ...`);
  for (const m of medien) await medienUeberpruefen(basisUrl, schluessel, m);
  console.log("  alle lesbar, Byte-Laenge stimmt.");

  console.log(`Schicke ${ops.length} Ops nach ${ziel} ...`);
  await opsPosten(basisUrl, schluessel, ops);

  console.log("Pruefe die Zahlen im Raum (WebSocket, seit=0, nur Ops mit Praefix umzug:) ...");
  const tatsaechlich = await migrierteZaehlungImRaum(basisUrl, schluessel);
  console.log("\nTatsaechlich im Raum:");
  tabelle(tatsaechlich);

  const arten = new Set([...erwartet.keys(), ...tatsaechlich.keys()]);
  let ok = true;
  for (const art of arten) {
    const e = erwartet.get(art) ?? 0;
    const t = tatsaechlich.get(art) ?? 0;
    if (e !== t) {
      ok = false;
      console.error(`Abweichung bei ${art}: erwartet ${e}, im Raum ${t}`);
    }
  }
  console.log(ok ? "\nZahlen stimmen ueberein." : "\nZahlen weichen ab, siehe oben.");
  if (!ok) process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((err) => {
    console.error("Umzug fehlgeschlagen:", err.message);
    process.exit(1);
  });
}
