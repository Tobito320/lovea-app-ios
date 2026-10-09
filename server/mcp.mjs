#!/usr/bin/env node
// MCP-Server (stdio) für KI-Agenten, die an Lovea arbeiten: Daten lesen, Messwerte, Worker-Logs.
// Liest über die GET /agent/*-Routen des Workers (agent.js), daher kein WebSocket und keine Präsenz
// beim Partner. Einzige Schreibstelle: lovea_gym_plan_setzen schickt eine gym.plan-Op über POST /ops
// (ohne Push), erst nach Vorschau mit anwenden=true. Gym-Rechnungen in gym.js.
// Ohne Abhängigkeit: JSON-RPC 2.0, eine Nachricht pro Zeile.
// Anmeldung: .mcp.json im Repo-Wurzelordner (Claude Code), siehe docs/MCP.md.
import { readFileSync, existsSync } from "node:fs";
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import * as gym from "./gym.js";

const HIER = dirname(fileURLToPath(import.meta.url));
const SCHLUESSEL_PFAD = process.env.LOVEA_KEY_PFAD ?? "C:\\Users\\ahmed\\code\\lovea-app-ios\\signing\\lovea-app.key";
const BASIS = {
  test: process.env.LOVEA_URL_TEST ?? "https://lovea-test.ahmedhdplay12345.workers.dev",
  live: process.env.LOVEA_URL_LIVE ?? "https://lovea-live.ahmedhdplay12345.workers.dev",
};

const umgebung = { type: "string", enum: ["test", "live"], description: "Worker, Standard test. live = echte Daten von Ahmed und Annika." };
const person = { type: "string", enum: ["ahmed", "annika"], description: "Standard ahmed" };
const WERKZEUGE = [
  {
    name: "lovea_statistik",
    description:
      "Kennzahlen des Lovea-Raums: Ops je Art (Anzahl, Bytes, letzte Zeit) und Person, Medien (unfertige Uploads, Bytes), wer per WebSocket verbunden ist, Push-Token vorhanden, letzter Standort-Zeitpunkt, Merker-Schlüssel, DB-Größe. Keine Inhalte. Erster Schritt bei jedem Lovea-Problem.",
    inputSchema: { type: "object", properties: { umgebung } },
  },
  {
    name: "lovea_ops",
    description:
      "Ops (Op-Log, das alle App-Daten trägt) gefiltert lesen, neueste zuerst. Arten z.B. nachricht.neu, gym.satz, kalender.*, einstellung.setzen; 'gym.' filtert alle mit Präfix. Inhalte über 2000 Zeichen werden gekürzt (voll=true für alles).",
    inputSchema: {
      type: "object",
      properties: {
        umgebung,
        art: { type: "string", description: "Genaue Art oder Präfix mit Punkt am Ende" },
        von: { type: "string", enum: ["ahmed", "annika"] },
        seit: { type: "integer", description: "Nur seq größer als dieser Wert" },
        ab: { type: "string", description: "ISO-Zeit, z.B. 2026-10-07" },
        bis: { type: "string", description: "ISO-Zeit, inklusiv" },
        suche: { type: "string", description: "Text im Inhalt (d), ohne Groß/Klein" },
        limit: { type: "integer", description: "1-200, Standard 50" },
        aufsteigend: { type: "boolean" },
        voll: { type: "boolean" },
      },
    },
  },
  {
    name: "lovea_merker",
    description: "Server-internen Merker lesen (erledigte Alarme, Zufällig-nah, Spotify-Cache usw.). Schlüssel aus lovea_statistik. Spotify-Token sind gesperrt.",
    inputSchema: { type: "object", properties: { umgebung, schluessel: { type: "string" } }, required: ["schluessel"] },
  },
  {
    name: "lovea_messen",
    description:
      "Antwortzeiten messen: Worker+Raum (/agent/ping), Raum mit SQL (/agent/statistik), D1-Lebensmittelsuche (/essen/suche). Erster Aufruf = kalt (Aufwecken), dann Median, p95, max. Schreibt nichts.",
    inputSchema: { type: "object", properties: { umgebung, runden: { type: "integer", description: "1-30, Standard 10" } } },
  },
  {
    name: "lovea_logs",
    description:
      "Live-Logs des Workers (wrangler tail) für einige Sekunden mitschneiden: Anfragen, Fehler, console.log, Ausnahmen. Nur was in dem Zeitraum passiert; App vorher bedienen lassen oder lovea_messen parallel.",
    inputSchema: { type: "object", properties: { umgebung, sekunden: { type: "integer", description: "5-120, Standard 20" } } },
  },
  {
    name: "lovea_gym_plan",
    description:
      "Aktuellen Trainingsplan lesen (Tage, Wochentage, Übungen mit Namen, Sätze, Ruhetage, Splitname). roh=true gibt zusätzlich den Plan genau so, wie die App ihn speichert (zum Ändern und Zurückgeben an lovea_gym_plan_setzen). Mit verlauf=true auch frühere Pläne (seq zum Wiederherstellen).",
    inputSchema: { type: "object", properties: { umgebung, person, roh: { type: "boolean" }, verlauf: { type: "boolean" } } },
  },
  {
    name: "lovea_gym_trainings",
    description: "Trainingseinheiten (neueste zuerst): Datum, Plantag, Dauer, je Übung die abgehakten Sätze (kg×Wdh), getauschte Übungen, kcal und Puls.",
    inputSchema: { type: "object", properties: { umgebung, person, ab: { type: "string", description: "YYYY-MM-DD" }, limit: { type: "integer", description: "Standard 10" } } },
  },
  {
    name: "lovea_gym_auswertung",
    description:
      "Gym messen: je Woche Trainings, Minuten, Sätze, Volumen und Sätze je Muskelgruppe; diese Woche gegen Satzziele (ziel.saetze.*); Erholung je Gruppe wie in der App plus Formerhalt nach Pause (openGym-Modell); je Übung Verlauf, bestes e1RM (Epley), Plateau, Vorschlag fürs nächste Mal (8-12 Wdh, +2,5 kg); Plantreue je Plantag; Kraftverhältnis der Langhantel-Grundübungen (Thibaudeau). Grundlage, um den Plan anzupassen.",
    inputSchema: { type: "object", properties: { umgebung, person, wochen: { type: "integer", description: "Rückblick 1-52, Standard 8" } } },
  },
  {
    name: "lovea_gym_uebungen",
    description: "Übungskatalog der App durchsuchen (1333 Übungen, lokal). Nur ids von hier in Plänen verwenden. Suche in deutschem und englischem Namen, Filter nach Muskel (z.B. Brust, Latissimus, Quadrizeps) oder Körperteil (Brust, Rücken, Beine, Arme, Cardio) und Gerät (Langhantel, Kurzhantel, Kabelzug, Maschine, Körpergewicht …).",
    inputSchema: { type: "object", properties: { suche: { type: "string" }, muskel: { type: "string" }, geraet: { type: "string" }, limit: { type: "integer", description: "Standard 30, höchstens 100" } } },
  },
  {
    name: "lovea_gym_splits",
    description: "Split-Vorlagen der App (85, m-ahmed01..15 sind Ahmeds). Ohne id: Liste mit Name, Gruppe m/w, Level, Ziel, Gerät, Tagen. Mit id: alle Einheiten mit Übungen. Übernehmen über lovea_gym_plan_setzen mit split.",
    inputSchema: { type: "object", properties: { id: { type: "string" }, gruppe: { type: "string", enum: ["m", "w"] }, suche: { type: "string" } } },
  },
  {
    name: "lovea_gym_plan_setzen",
    description:
      "Trainingsplan von Ahmed ersetzen. Genau eins: plan (ganzer Plan; App-Form aus lovea_gym_plan roh oder Kurzform je Übung {uebung: Katalog-id oder genauer Name, saetze: 3, wdh: 10, kg: 60}; bestehende ids behalten, damit Verlauf und Notizen bleiben), split (Vorlagen-id, wie Split wählen in der App) oder wiederherstellen (seq eines früheren Plans aus lovea_gym_plan verlauf). Ohne anwenden=true nur Prüfung und Vorschau mit Unterschied. Mit anwenden=true wird eine gym.plan-Op geschrieben (neuester Plan gilt, alte bleiben im Log, also rückgängig über wiederherstellen). Die App sieht den Plan beim nächsten Verbinden. Wochentage 1 = Mo … 7 = So.",
    inputSchema: {
      type: "object",
      properties: {
        umgebung,
        plan: { type: "object", description: "{tage:[{id?, name, wochentage:[1..7], uebungen:[...]}], ruhetage?:[...], splitName?}" },
        split: { type: "string" },
        wiederherstellen: { type: "integer" },
        anwenden: { type: "boolean" },
      },
    },
  },
];

function schluessel() {
  if (!existsSync(SCHLUESSEL_PFAD)) throw new Error(`Schlüsseldatei fehlt: ${SCHLUESSEL_PFAD} (oder LOVEA_KEY_PFAD setzen)`);
  return readFileSync(SCHLUESSEL_PFAD, "utf8").trim();
}

async function holen(umg, pfad) {
  const basis = BASIS[umg ?? "test"];
  if (!basis) throw new Error(`Unbekannte Umgebung: ${umg}`);
  const t0 = performance.now();
  const res = await fetch(basis + pfad, { headers: { "X-Lovea-Key": schluessel(), "X-Lovea-Person": "ahmed" } });
  const ms = performance.now() - t0;
  const text = await res.text();
  if (res.status === 404 && pfad.startsWith("/agent/")) throw new Error(`${umg ?? "test"}: /agent/* fehlt, Worker mit server/agent.js deployen`);
  if (!res.ok) throw new Error(`${pfad}: HTTP ${res.status} ${text.slice(0, 200)}`);
  return { daten: text ? JSON.parse(text) : null, ms };
}

async function senden(umg, pfad, koerper) {
  const basis = BASIS[umg ?? "test"];
  if (!basis) throw new Error(`Unbekannte Umgebung: ${umg}`);
  const res = await fetch(basis + pfad, {
    method: "POST",
    headers: { "X-Lovea-Key": schluessel(), "X-Lovea-Person": "ahmed", "Content-Type": "application/json" },
    body: JSON.stringify(koerper),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${pfad}: HTTP ${res.status} ${text.slice(0, 200)}`);
  return JSON.parse(text);
}

let katalog;
const kat = () => (katalog ??= gym.katalogLaden(join(HIER, "..", "Lovea", "Sources", "Health")));

/** Alle Ops einer Art (oder eines Präfixes) einer Person, in Seiten zu 200, älteste zuerst. */
async function alleOps(umg, art, von) {
  const alle = [];
  for (let seit = 0; ; ) {
    const { ops, mehr } = (await holen(umg, `/agent/ops?${abfrage({ art, von, seit, limit: 200, aufsteigend: true, voll: true })}`)).daten;
    alle.push(...ops);
    if (!mehr || !ops.length) return alle;
    seit = ops.at(-1).seq;
  }
}

const gymStand = async (umg, wer) => gym.falten(await alleOps(umg, "gym.", wer));

async function ziele(umg, wer) {
  const werte = {};
  for (const op of await alleOps(umg, "einstellung.setzen", wer)) {
    const { schluessel: k, wert } = op.d ?? {};
    if (typeof k === "string" && k.startsWith("ziel.") && typeof wert === "number") werte[k] = wert;
  }
  return gym.ziele(werte, wer);
}

async function planSetzen(a) {
  const quellen = ["plan", "split", "wiederherstellen"].filter((k) => a[k] != null);
  if (quellen.length !== 1) throw new Error("Genau eins angeben: plan, split oder wiederherstellen");
  const k = kat();
  const stand = await gymStand(a.umgebung, "ahmed");
  let eingabe = a.plan;
  if (a.split != null) {
    const sp = k.splits.find((s) => s.id === a.split);
    if (!sp) throw new Error(`Split ${a.split} unbekannt (lovea_gym_splits)`);
    eingabe = gym.splitAlsPlan(sp);
  }
  if (a.wiederherstellen != null) {
    const op = (await alleOps(a.umgebung, "gym.plan", "ahmed")).find((o) => o.seq === a.wiederherstellen);
    if (!op) throw new Error(`Kein gym.plan von ahmed mit seq ${a.wiederherstellen}`);
    eingabe = op.d;
  }
  const { plan, fehler } = gym.planPruefen(eingabe, k);
  if (fehler) return { ok: false, fehler };
  const ergebnis = { unterschied: gym.planUnterschied(stand.plan, plan, k), plan: gym.planLesbar(plan, k) };
  if (!a.anwenden) return { ok: true, angewendet: false, hinweis: "Vorschau. Mit anwenden=true schreiben.", ...ergebnis };
  const antwort = await senden(a.umgebung, "/ops", { ops: [gym.planOp(plan, "ahmed")] });
  if (antwort.uebersprungen) throw new Error("Worker hat die Op abgelehnt (opGueltig)");
  const vorher = stand.plaene[0]?.seq;
  return { ok: true, angewendet: true, seq: antwort.seq, rueckgaengig: vorher ? `lovea_gym_plan_setzen wiederherstellen=${vorher}` : null, ...ergebnis };
}

async function gymWerkzeug(name, a) {
  const wer = a.person ?? "ahmed";
  if (name === "lovea_gym_uebungen") return gym.uebungenSuchen(kat(), a);
  if (name === "lovea_gym_splits") {
    const k = kat();
    if (a.id) {
      const sp = k.splits.find((s) => s.id === a.id);
      if (!sp) throw new Error(`Split ${a.id} unbekannt`);
      return gym.splitLesbar(sp, k);
    }
    const w = (a.suche ?? "").toLowerCase();
    return k.splits
      .filter((s) => (!a.gruppe || s.gruppe === a.gruppe) && s.name.toLowerCase().includes(w))
      .map(({ id, name, gruppe, level, ziel, geraet, tage }) => ({ id, name, gruppe, level, ziel, geraet, tage }));
  }
  if (name === "lovea_gym_plan_setzen") return planSetzen(a);
  const stand = await gymStand(a.umgebung, wer);
  if (name === "lovea_gym_plan") {
    return { lesbar: gym.planLesbar(stand.plan, kat()), ...(a.roh ? { roh: stand.plan } : {}), ...(a.verlauf ? { verlauf: stand.plaene.slice(0, 30) } : {}) };
  }
  if (name === "lovea_gym_trainings") {
    const liste = stand.sessions.filter((s) => !a.ab || gym.datumText(s.start) >= a.ab).slice(0, Math.min(100, a.limit ?? 10));
    return liste.map((s) => gym.sessionLesbar(s, kat(), stand.tagNamen));
  }
  return gym.auswerten(stand, kat(), { wochen: Math.min(52, Math.max(1, a.wochen ?? 8)), ziel: await ziele(a.umgebung, wer) });
}

const abfrage = (a) => {
  const p = new URLSearchParams();
  for (const k of ["art", "von", "seit", "ab", "bis", "suche", "limit"]) if (a[k] != null && a[k] !== "") p.set(k, String(a[k]));
  if (a.aufsteigend) p.set("aufsteigend", "1");
  if (a.voll) p.set("voll", "1");
  return p.toString();
};

export function kennzahlen(zeiten) {
  const [kalt, ...warm] = zeiten;
  const s = [...(warm.length ? warm : zeiten)].sort((x, y) => x - y);
  const r = (x) => Math.round(x);
  return { kaltMs: r(kalt), medianMs: r(s[Math.floor(s.length / 2)]), p95Ms: r(s[Math.min(s.length - 1, Math.ceil(s.length * 0.95) - 1)]), maxMs: r(s.at(-1)), runden: zeiten.length };
}

async function messen(umg, runden) {
  const n = Math.min(30, Math.max(1, runden ?? 10));
  const ziele = { "worker+raum": "/agent/ping", "raum+sql": "/agent/statistik", "d1-essen": "/essen/suche?q=apfel&n=5" };
  const ergebnis = {};
  for (const [name, pfad] of Object.entries(ziele)) {
    const zeiten = [];
    try {
      for (let i = 0; i < n; i++) zeiten.push((await holen(umg, pfad)).ms);
      ergebnis[name] = kennzahlen(zeiten);
    } catch (e) {
      ergebnis[name] = { fehler: e.message };
    }
  }
  return ergebnis;
}

function logs(umg, sekunden) {
  const wrangler = join(HIER, "node_modules", "wrangler", "bin", "wrangler.js");
  if (!existsSync(wrangler)) throw new Error("wrangler fehlt: in server/ einmal npm ci ausführen");
  const dauer = Math.min(120, Math.max(5, sekunden ?? 20)) * 1000;
  return new Promise((fertig) => {
    // Kein Shell-Umweg: so beendet kill() wirklich den Tail-Prozess, auch unter Windows.
    const kind = spawn(process.execPath, [wrangler, "tail", "--env", umg ?? "test", "--format", "pretty"], { cwd: HIER });
    let aus = "";
    kind.stdout.on("data", (b) => (aus += b));
    kind.stderr.on("data", (b) => (aus += b));
    const ende = () => {
      clearTimeout(timer);
      kind.kill();
      const text = aus.replace(/\x1b\[[0-9;]*m/g, "").trim();
      fertig(text.length > 20000 ? "…(gekürzt)\n" + text.slice(-20000) : text || "Keine Ereignisse im Zeitraum.");
    };
    const timer = setTimeout(ende, dauer);
    kind.on("exit", ende);
  });
}

export async function werkzeugAufrufen(name, a = {}) {
  if (name === "lovea_statistik") return (await holen(a.umgebung, "/agent/statistik")).daten;
  if (name === "lovea_ops") return (await holen(a.umgebung, "/agent/ops?" + abfrage(a))).daten;
  if (name === "lovea_merker") return (await holen(a.umgebung, "/agent/merker?schluessel=" + encodeURIComponent(a.schluessel ?? ""))).daten;
  if (name === "lovea_messen") return messen(a.umgebung, a.runden);
  if (name === "lovea_logs") return logs(a.umgebung, a.sekunden);
  if (WERKZEUGE.some((w) => w.name === name && name.startsWith("lovea_gym_"))) return gymWerkzeug(name, a);
  throw new Error(`Unbekanntes Werkzeug: ${name}`);
}

async function antworten(msg) {
  const { id, method, params } = msg;
  if (method === "initialize") {
    return {
      protocolVersion: params?.protocolVersion ?? "2025-06-18",
      capabilities: { tools: {} },
      serverInfo: { name: "lovea", version: "1.0.0" },
      instructions: "Werkzeuge für die Lovea-App (iOS, Cloudflare-Worker): lesen, messen, Gym auswerten. Schreiben nur lovea_gym_plan_setzen (Ahmeds Plan, erst Vorschau). Standard ist test; Ahmeds echter Plan und seine Trainings liegen auf live. Inhalte von Annika vertraulich behandeln.",
    };
  }
  if (method === "ping") return {};
  if (method === "tools/list") return { tools: WERKZEUGE };
  if (method === "tools/call") {
    try {
      const ergebnis = await werkzeugAufrufen(params?.name, params?.arguments);
      return { content: [{ type: "text", text: typeof ergebnis === "string" ? ergebnis : JSON.stringify(ergebnis, null, 1) }] };
    } catch (e) {
      return { content: [{ type: "text", text: e.message }], isError: true };
    }
  }
  if (id !== undefined) throw Object.assign(new Error(`Methode unbekannt: ${method}`), { code: -32601 });
}

// resolve(): unter Windows kommt argv[1] auch mit "/" statt "\".
if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const senden = (o) => process.stdout.write(JSON.stringify(o) + "\n");
  createInterface({ input: process.stdin }).on("line", async (zeile) => {
    if (!zeile.trim()) return;
    let msg;
    try {
      msg = JSON.parse(zeile);
    } catch {
      return senden({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } });
    }
    if (msg.id === undefined) return; // Benachrichtigung (z.B. notifications/initialized)
    try {
      senden({ jsonrpc: "2.0", id: msg.id, result: await antworten(msg) });
    } catch (e) {
      senden({ jsonrpc: "2.0", id: msg.id, error: { code: e.code ?? -32603, message: e.message } });
    }
  });
}
