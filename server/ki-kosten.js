// Kostenbuch der KI-Funktionen: rechnet die Tokens eines OpenAI-Aufrufs in Dollar
// um und schreibt sie pro Monat und Feature in die vorhandene Tabelle `merker`
// (keine Migration). Ab BERICHT_STOP_USD pausieren die Tagesberichte, Fotos und
// Coach laufen weiter -- der Rest des Budgets bleibt dem, was Ahmed taeglich nutzt.
// Reine Funktionen, SQL kommt von aussen (DO-Storage oder fake-sql.js im Test).
import { merkerLesen, merkerSchreiben } from "./raum-logic.js";

// Preise in Dollar je 1 Mio. Tokens. Gecachte Eingabe-Tokens sind billiger.
export const PREISE_STANDARD = { "gpt-6-luna": { ein: 1.25, ein_cache: 0.125, aus: 10 } };
export const BUDGET_USD = 10;
export const BERICHT_STOP_USD = 9;

const FEATURES = new Set(["essen", "coach", "bericht"]);
const MONAT = /^\d{4}-(0[1-9]|1[0-2])$/;
const MONATE_BEHALTEN = 3;
const PRAEFIX = "ki:kosten:";

const schluessel = (monat, feature) => `${PRAEFIX}${monat}:${feature}`;
const warnungSchluessel = (monat) => `${PRAEFIX}warnung:${monat}`;
const r6 = (n) => Math.round(n * 1e6) / 1e6;

function ganz(wert) {
  const n = Number(wert);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : 0;
}

/** "2026-10-08" -> "2026-10" */
export const monatVon = (tag) => String(tag ?? "").slice(0, 7);

function monatMinus(monat, anzahl) {
  const d = new Date(`${monat}-01T00:00:00Z`);
  d.setUTCMonth(d.getUTCMonth() - anzahl);
  return d.toISOString().slice(0, 7);
}

/** Preise aus der Config (env.KI_PREISE als JSON), sonst die Standardtabelle. */
export function preiseLesen(env) {
  const roh = env?.KI_PREISE;
  if (!roh) return PREISE_STANDARD;
  let j;
  try {
    j = typeof roh === "string" ? JSON.parse(roh) : roh;
  } catch {
    return PREISE_STANDARD;
  }
  if (!j || typeof j !== "object" || Array.isArray(j)) return PREISE_STANDARD;
  const preise = { ...PREISE_STANDARD };
  for (const [modell, p] of Object.entries(j)) {
    if (!p || typeof p !== "object") continue;
    const zahlen = ["ein", "ein_cache", "aus"].map((k) => Number(p[k]));
    if (zahlen.some((n) => !Number.isFinite(n) || n < 0)) continue;
    preise[modell] = { ein: zahlen[0], ein_cache: zahlen[1], aus: zahlen[2] };
  }
  return preise;
}

/** usage der Responses API -> Tokens und Dollar. Kaputtes usage ergibt Nullen. */
export function kostenRechnen(preise, modell, usage) {
  const u = usage && typeof usage === "object" ? usage : {};
  const cache = ganz(u.input_tokens_details?.cached_tokens);
  const ein = Math.max(0, ganz(u.input_tokens) - cache);
  const aus = ganz(u.output_tokens);
  const p = preise?.[modell];
  const usd = p ? r6((ein * p.ein + cache * p.ein_cache + aus * p.aus) / 1_000_000) : 0;
  return { ein, cache, aus, usd };
}

function eintragLesen(sql, monat, feature) {
  const wert = merkerLesen(sql, schluessel(monat, feature));
  if (!wert) return { ein: 0, cache: 0, aus: 0, usd: 0, n: 0 };
  try {
    const j = JSON.parse(wert);
    return { ein: ganz(j.ein), cache: ganz(j.cache), aus: ganz(j.aus), usd: Number(j.usd) || 0, n: ganz(j.n) };
  } catch {
    return { ein: 0, cache: 0, aus: 0, usd: 0, n: 0 };
  }
}

function monateAufraeumen(sql, monat) {
  const grenze = monatMinus(monat, MONATE_BEHALTEN);
  const rows = sql.exec(`SELECT schluessel FROM merker WHERE schluessel LIKE ?`, `${PRAEFIX}%`).toArray();
  for (const row of rows) {
    const teile = String(row.schluessel).slice(PRAEFIX.length).split(":");
    const m = teile[0] === "warnung" ? teile[1] : teile[0];
    if (MONAT.test(m) && m < grenze) sql.exec(`DELETE FROM merker WHERE schluessel = ?`, row.schluessel);
  }
}

/** Stand eines Monats: Summe, Aufteilung je Feature, ob Tagesberichte erlaubt sind. */
export function kostenStand(sql, monat) {
  const je_feature = {};
  let usd = 0;
  if (MONAT.test(String(monat))) {
    for (const feature of FEATURES) {
      const e = eintragLesen(sql, monat, feature);
      if (e.n === 0 && e.usd === 0) continue;
      je_feature[feature] = e;
      usd += e.usd;
    }
  }
  usd = r6(usd);
  return {
    monat,
    usd,
    budget: BUDGET_USD,
    je_feature,
    bericht_erlaubt: usd < BERICHT_STOP_USD,
    gewarnt: merkerLesen(sql, warnungSchluessel(monat)) !== null,
  };
}

/**
 * Bucht einen Aufruf. Gibt den neuen Stand zurueck, `null` bei kaputter Eingabe.
 * `warnen` ist genau einmal pro Monat true: wenn die Grenze gerissen wird.
 */
export function kostenBuchen(sql, { monat, feature, ein, cache, aus, usd } = {}) {
  if (!MONAT.test(String(monat)) || !FEATURES.has(feature)) return null;
  const betrag = Number(usd);
  if (!Number.isFinite(betrag) || betrag < 0) return null;

  const alt = eintragLesen(sql, monat, feature);
  const neu = {
    ein: alt.ein + ganz(ein),
    cache: alt.cache + ganz(cache),
    aus: alt.aus + ganz(aus),
    usd: r6(alt.usd + betrag),
    n: alt.n + 1,
  };
  merkerSchreiben(sql, schluessel(monat, feature), JSON.stringify(neu));
  monateAufraeumen(sql, monat);

  const stand = kostenStand(sql, monat);
  const warnen = !stand.bericht_erlaubt && !stand.gewarnt;
  if (warnen) merkerSchreiben(sql, warnungSchluessel(monat), String(stand.usd));
  return { ...stand, gewarnt: stand.gewarnt || warnen, warnen, usd_monat: stand.usd };
}
