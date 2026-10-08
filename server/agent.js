// Nur-Lese-Diagnose für KI-Agenten (GET /agent/*, genutzt von mcp.mjs): Kennzahlen und
// gefilterte Ops aus dem Raum, ohne WebSocket -- also ohne Präsenz-Wechsel beim Partner.
// Pure Funktionen gegen `sql`, unter Node testbar wie raum-logic.js.
import { NUR_FUER_ABSENDER } from "./raum-logic.js";

const PERSONEN = ["ahmed", "annika"];
const MAX_LIMIT = 200;
const KURZ_AB = 2000; // Zeichen JSON; ein Strich hat 10-30 KB
const ANFANG = 300;

export function agentStatistik(sql) {
  const jeArt = sql
    .exec(`SELECT art, COUNT(*) AS anzahl, SUM(length(d)) AS bytes, MAX(zeit) AS letzte FROM ops GROUP BY art ORDER BY anzahl DESC`)
    .toArray();
  const jePerson = {};
  for (const r of sql.exec(`SELECT von, COUNT(*) AS n FROM ops GROUP BY von`)) jePerson[r.von] = r.n;
  const gesamt = sql.exec(`SELECT COUNT(*) AS anzahl, MAX(seq) AS letzteSeq, SUM(length(d)) AS bytes FROM ops`).one();

  const m = sql
    .exec(
      `SELECT COUNT(*) AS eintraege, SUM(fertig = 0) AS unfertig, SUM(abgeholt = 1) AS abgeholt, SUM(bytes) AS angemeldetBytes FROM medien_info`
    )
    .one();
  const gespeichert = sql.exec(`SELECT SUM(length(daten)) AS b FROM medien`).one().b ?? 0;

  const geraete = {};
  const standort = {};
  for (const p of PERSONEN) {
    geraete[p] = sql.exec(`SELECT 1 FROM geraete WHERE person = ? AND token IS NOT NULL AND token != ''`, p).toArray().length > 0;
    standort[p] = sql.exec(`SELECT zeit FROM standort WHERE person = ?`, p).toArray()[0]?.zeit ?? null;
  }
  const merker = sql.exec(`SELECT schluessel FROM merker ORDER BY schluessel`).toArray().map((r) => r.schluessel);

  return {
    ops: { anzahl: gesamt.anzahl, letzteSeq: gesamt.letzteSeq ?? 0, bytes: gesamt.bytes ?? 0, jePerson, jeArt },
    medien: {
      eintraege: m.eintraege,
      unfertig: m.unfertig ?? 0,
      abgeholt: m.abgeholt ?? 0,
      angemeldetBytes: m.angemeldetBytes ?? 0,
      gespeichertBytes: gespeichert,
    },
    geraete, // nur ob ein Push-Token da ist, nie das Token
    standort, // nur Zeitpunkt, nie Koordinaten
    merker, // nur Schlüssel; Werte über agentMerker
  };
}

// Filter: art ("gym." = Präfix, sonst genau), von, seit (seq), ab/bis (ISO-Zeit), suche (Text in d),
// limit (1-200, Standard 50), aufsteigend (sonst neueste zuerst), voll (große d nicht kürzen).
// `fuer`: private Arten der anderen Person bleiben unsichtbar, wie in opsSeit.
export function agentOps(sql, f, fuer) {
  const wo = [`NOT ((art = ? OR art LIKE 'galerie.%' OR art LIKE 'geschenkbox.%') AND von != ?)`];
  const werte = [NUR_FUER_ABSENDER, fuer];
  if (f.art) {
    const praefix = f.art.endsWith(".") || f.art.endsWith("*");
    wo.push(praefix ? `art LIKE ? ESCAPE '\\'` : `art = ?`);
    werte.push(praefix ? f.art.replace(/\*$/, "").replace(/[%_\\]/g, "\\$&") + "%" : f.art);
  }
  if (f.von) wo.push(`von = ?`), werte.push(f.von);
  if (f.seit != null) wo.push(`seq > ?`), werte.push(Number(f.seit));
  if (f.ab) wo.push(`zeit >= ?`), werte.push(f.ab);
  if (f.bis) wo.push(`zeit <= ?`), werte.push(f.bis);
  if (f.suche) wo.push(`d LIKE ? ESCAPE '\\'`), werte.push("%" + f.suche.replace(/[%_\\]/g, "\\$&") + "%");
  const limit = Math.min(MAX_LIMIT, Math.max(1, Number(f.limit ?? 50) || 1));

  const zeilen = sql
    .exec(
      `SELECT seq, id, art, von, zeit, d FROM ops WHERE ${wo.join(" AND ")} ORDER BY seq ${f.aufsteigend ? "ASC" : "DESC"} LIMIT ?`,
      ...werte,
      limit + 1
    )
    .toArray();
  const mehr = zeilen.length > limit;
  const ops = zeilen.slice(0, limit).map((r) => ({
    seq: r.seq,
    id: r.id,
    art: r.art,
    von: r.von,
    zeit: r.zeit,
    d: !f.voll && r.d.length > KURZ_AB ? { _gekuerzt: true, bytes: r.d.length, anfang: r.d.slice(0, ANFANG) } : JSON.parse(r.d),
  }));
  return { ops, mehr };
}

export function agentMerker(sql, schluessel) {
  if (schluessel.startsWith("spotify.token.")) return { fehler: "gesperrt" };
  const wert = sql.exec(`SELECT wert FROM merker WHERE schluessel = ?`, schluessel).toArray()[0]?.wert ?? null;
  return { schluessel, wert };
}
