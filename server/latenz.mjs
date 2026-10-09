#!/usr/bin/env node
// Misst die Latenz Ahmed -> Annika: Verbindungsaufbau, Ping, Op-Echo und Op beim Partner.
// Aufruf: node server/latenz.mjs <basisUrl> [--nur-ping] [runden]
// --nur-ping schreibt nichts (fuer live). Ohne: schickt Ops der Art "latenz.test" (fuer test).
import { readFileSync } from "node:fs";

const SCHLUESSEL_PFAD = "C:\\Users\\ahmed\\code\\lovea-app-ios\\signing\\lovea-app.key";
const basis = process.argv[2];
const nurPing = process.argv.includes("--nur-ping");
const runden = Number(process.argv.find((a) => /^\d+$/.test(a)) ?? 5);
if (!basis) { console.error("Aufruf: node server/latenz.mjs <basisUrl> [--nur-ping] [runden]"); process.exit(1); }
const key = readFileSync(SCHLUESSEL_PFAD, "utf8").trim();

function verbinden(person) {
  const url = basis.replace(/^http/, "ws") + `/raum?seit=999999999&key=${encodeURIComponent(key)}&person=${person}`;
  const t0 = performance.now();
  const ws = new WebSocket(url);
  const warter = [];
  ws.addEventListener("message", (e) => {
    const text = String(e.data);
    for (const w of [...warter]) if (w.passt(text)) { warter.splice(warter.indexOf(w), 1); w.fertig(performance.now()); }
  });
  const auf = (passt, ms = 10000) => new Promise((fertig, fehler) => {
    const w = { passt, fertig };
    warter.push(w);
    setTimeout(() => fehler(new Error("timeout")), ms);
  });
  const offen = new Promise((r, f) => { ws.addEventListener("open", () => r(performance.now() - t0)); ws.addEventListener("error", f); });
  return { ws, auf, offen };
}

const ms = (x) => `${Math.round(x)} ms`;
const median = (a) => [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)];

const ahmed = verbinden("ahmed");
console.log("Verbindung ahmed (inkl. Aufwecken):", ms(await ahmed.offen));
const annika = verbinden("annika");
console.log("Verbindung annika:", ms(await annika.offen));
await new Promise((r) => setTimeout(r, 500));

const ping = [], echo = [], partner = [];
for (let i = 0; i < runden; i++) {
  let t = performance.now();
  const p = ahmed.auf((x) => x === "pong");
  ahmed.ws.send("ping");
  ping.push((await p) - t);

  if (!nurPing) {
    const id = `latenz-${Date.now()}-${i}`;
    const op = { id, art: "latenz.test", von: "ahmed", zeit: new Date().toISOString(), d: { i } };
    const e = ahmed.auf((x) => x.includes(id));
    const b = annika.auf((x) => x.includes(id));
    t = performance.now();
    ahmed.ws.send(JSON.stringify({ t: "op", op }));
    const [te, tb] = await Promise.all([e, b]);
    echo.push(te - t); partner.push(tb - t);
  }
  await new Promise((r) => setTimeout(r, Number(process.env.PAUSE_MS ?? 300)));
}
console.log(`Ping (Hin+Zurueck, ohne DO): Median ${ms(median(ping))}, max ${ms(Math.max(...ping))}`);
if (!nurPing) {
  console.log(`Op-Echo an Absender: Median ${ms(median(echo))}, max ${ms(Math.max(...echo))}`);
  console.log(`Op beim Partner:     Median ${ms(median(partner))}, max ${ms(Math.max(...partner))}`);
}
ahmed.ws.close(); annika.ws.close();
process.exit(0);
