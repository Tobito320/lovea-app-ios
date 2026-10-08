#!/usr/bin/env node
// MCP-Server (stdio) für KI-Agenten, die an Lovea arbeiten: Daten lesen, Messwerte, Worker-Logs.
// Nur lesend. Spricht die GET /agent/*-Routen des Workers an (agent.js), daher kein WebSocket und
// keine Präsenz beim Partner. Ohne Abhängigkeit: JSON-RPC 2.0, eine Nachricht pro Zeile.
// Anmeldung: .mcp.json im Repo-Wurzelordner (Claude Code), siehe docs/MCP.md.
import { readFileSync, existsSync } from "node:fs";
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";

const HIER = dirname(fileURLToPath(import.meta.url));
const SCHLUESSEL_PFAD = process.env.LOVEA_KEY_PFAD ?? "C:\\Users\\ahmed\\code\\lovea-app-ios\\signing\\lovea-app.key";
const BASIS = {
  test: process.env.LOVEA_URL_TEST ?? "https://lovea-test.ahmedhdplay12345.workers.dev",
  live: process.env.LOVEA_URL_LIVE ?? "https://lovea-live.ahmedhdplay12345.workers.dev",
};

const umgebung = { type: "string", enum: ["test", "live"], description: "Worker, Standard test. live = echte Daten von Ahmed und Annika." };
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
  throw new Error(`Unbekanntes Werkzeug: ${name}`);
}

async function antworten(msg) {
  const { id, method, params } = msg;
  if (method === "initialize") {
    return {
      protocolVersion: params?.protocolVersion ?? "2025-06-18",
      capabilities: { tools: {} },
      serverInfo: { name: "lovea", version: "1.0.0" },
      instructions: "Nur-Lese-Werkzeuge für die Lovea-App (iOS, Cloudflare-Worker). Standard ist test; live nur für echte Fehlersuche, Inhalte von Annika vertraulich behandeln.",
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
