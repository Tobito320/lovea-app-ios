// mcp.mjs gegen einen lokalen HTTP-Server mit echtem handleFetch + Raum (fake ctx): ein Durchstich
// MCP-Client -> stdio -> HTTP -> Worker -> Raum -> SQL, ohne Cloudflare.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { handleFetch } from "./index.js";
import { Raum } from "./raum.js";
import { fakeSql } from "./fake-sql.js";
import { opEinfuegen } from "./raum-logic.js";
import { kennzahlen } from "./mcp.mjs";

function lokalerWorker() {
  const ctx = {
    storage: { sql: fakeSql(), setAlarm: async () => {}, deleteAlarm: async () => {} },
    blockConcurrencyWhile: async (fn) => fn(),
    getWebSockets: () => [],
    getTags: () => [],
  };
  const raum = new Raum(ctx, {});
  opEinfuegen(ctx.storage.sql, { id: "x1", art: "gym.satz", von: "ahmed", zeit: "2026-10-08T09:00:00Z", d: { kg: 60 } });
  const env = { LOVEA_APP_KEY: "test-schluessel", RAUM: { idFromName: () => "wir", get: () => raum } };
  const server = createServer(async (req, res) => {
    // Ohne D1-Bindung wirft /essen/* -- als 500 beantworten, sonst hängt der Client.
    const teile = [];
    for await (const s of req) teile.push(s);
    const body = req.method === "GET" ? undefined : Buffer.concat(teile);
    const antwort = await handleFetch(new Request(`http://lokal${req.url}`, { method: req.method, headers: req.headers, body }), env).catch(
      (e) => new Response(e.message, { status: 500 })
    );
    res.writeHead(antwort.status, Object.fromEntries(antwort.headers));
    res.end(Buffer.from(await antwort.arrayBuffer()));
  });
  return new Promise((r) => server.listen(0, "127.0.0.1", () => r(server)));
}

function mcpStarten(url, schluesselPfad) {
  const kind = spawn(process.execPath, [join(import.meta.dirname, "mcp.mjs")], {
    env: { ...process.env, LOVEA_URL_TEST: url, LOVEA_KEY_PFAD: schluesselPfad },
  });
  const offen = new Map();
  createInterface({ input: kind.stdout }).on("line", (z) => {
    const m = JSON.parse(z);
    offen.get(m.id)?.(m);
  });
  let n = 0;
  const frage = (method, params) =>
    new Promise((r) => {
      const id = ++n;
      offen.set(id, r);
      kind.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    });
  return { kind, frage };
}

test("MCP: initialize, tools/list und Werkzeuge gegen lokalen Worker", async () => {
  const server = await lokalerWorker();
  const ordner = mkdtempSync(join(tmpdir(), "lovea-mcp-"));
  writeFileSync(join(ordner, "key"), "test-schluessel\n");
  const { kind, frage } = mcpStarten(`http://127.0.0.1:${server.address().port}`, join(ordner, "key"));
  try {
    const init = await frage("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "t", version: "1" } });
    assert.equal(init.result.serverInfo.name, "lovea");
    kind.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

    const liste = await frage("tools/list", {});
    assert.deepEqual(liste.result.tools.map((t) => t.name), [
      "lovea_statistik", "lovea_ops", "lovea_merker", "lovea_messen", "lovea_logs",
      "lovea_gym_plan", "lovea_gym_trainings", "lovea_gym_auswertung", "lovea_gym_uebungen", "lovea_gym_splits", "lovea_gym_plan_setzen",
    ]);

    const statistik = JSON.parse((await frage("tools/call", { name: "lovea_statistik", arguments: {} })).result.content[0].text);
    assert.equal(statistik.ops.anzahl, 1);

    const ops = JSON.parse((await frage("tools/call", { name: "lovea_ops", arguments: { art: "gym.", von: "ahmed" } })).result.content[0].text);
    assert.equal(ops.ops[0].d.kg, 60);

    const gemessen = JSON.parse((await frage("tools/call", { name: "lovea_messen", arguments: { runden: 3 } })).result.content[0].text);
    assert.equal(gemessen["worker+raum"].runden, 3);

    const rufen = async (name, args) => JSON.parse((await frage("tools/call", { name, arguments: args })).result.content[0].text);
    const neu = { tage: [{ name: "Pull", wochentage: [1], uebungen: [{ uebung: "qdRxqCj", saetze: 3, wdh: 10, kg: 50 }] }] };
    const vorschau = await rufen("lovea_gym_plan_setzen", { plan: neu });
    assert.equal(vorschau.angewendet, false);
    assert.equal((await rufen("lovea_statistik", {})).ops.anzahl, 1, "Vorschau schreibt nichts");
    const geschrieben = await rufen("lovea_gym_plan_setzen", { plan: neu, anwenden: true });
    assert.equal(geschrieben.angewendet, true);
    assert.equal(geschrieben.rueckgaengig, null, "vorher gab es keinen Plan");
    const gelesen = await rufen("lovea_gym_plan", { roh: true });
    assert.equal(gelesen.roh.tage[0].name, "Pull");
    assert.equal(gelesen.roh.tage[0].uebungen[0].saetze.length, 3);
    const zweiter = await rufen("lovea_gym_plan_setzen", { split: "m-ahmed01", anwenden: true });
    assert.equal(zweiter.rueckgaengig, `lovea_gym_plan_setzen wiederherstellen=${geschrieben.seq}`);
    await rufen("lovea_gym_plan_setzen", { wiederherstellen: geschrieben.seq, anwenden: true });
    assert.equal((await rufen("lovea_gym_plan", {})).lesbar.tage[0].name, "Pull");
    assert.equal((await rufen("lovea_gym_plan_setzen", { plan: { tage: [{ name: "X", wochentage: [8] }] } })).ok, false);

    const falsch = await frage("tools/call", { name: "gibtsnicht", arguments: {} });
    assert.equal(falsch.result.isError, true);
    assert.equal((await frage("gibtsnicht/methode", {})).error.code, -32601);
  } finally {
    kind.kill();
    server.close();
  }
});

test("MCP: falscher Schlüssel gibt lesbaren Fehler statt Absturz", async () => {
  const server = await lokalerWorker();
  const ordner = mkdtempSync(join(tmpdir(), "lovea-mcp-"));
  writeFileSync(join(ordner, "key"), "falsch");
  const { kind, frage } = mcpStarten(`http://127.0.0.1:${server.address().port}`, join(ordner, "key"));
  try {
    const r = await frage("tools/call", { name: "lovea_statistik", arguments: {} });
    assert.equal(r.result.isError, true);
    assert.match(r.result.content[0].text, /401/);
  } finally {
    kind.kill();
    server.close();
  }
});

test("Kennzahlen: erster Wert kalt, Rest warm", () => {
  assert.deepEqual(kennzahlen([900, 10, 30, 20]), { kaltMs: 900, medianMs: 20, p95Ms: 30, maxMs: 30, runden: 4 });
  assert.deepEqual(kennzahlen([5]), { kaltMs: 5, medianMs: 5, p95Ms: 5, maxMs: 5, runden: 1 });
});
