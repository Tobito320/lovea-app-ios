#!/usr/bin/env node
// Prüft, ob der Server eine Person, die nur rohe "ping" schickt, nach >60 s noch als "da" zählt.
// Aufruf: node server/praesenz.mjs <basisUrl> (nur test, schreibt nichts)
import { readFileSync } from "node:fs";

const key = readFileSync("C:\\Users\\ahmed\\code\\lovea-app-ios\\signing\\lovea-app.key", "utf8").trim();
const basis = process.argv[2];
const url = (p) => basis.replace(/^http/, "ws") + `/raum?seit=999999999&key=${encodeURIComponent(key)}&person=${p}`;

const annika = new WebSocket(url("annika"));
await new Promise((r) => annika.addEventListener("open", r));
const timer = setInterval(() => annika.send("ping"), 10_000);
await new Promise((r) => setTimeout(r, 75_000));

const ahmed = new WebSocket(url("ahmed"));
const da = await new Promise((r) => ahmed.addEventListener("message", (e) => {
  const m = JSON.parse(String(e.data));
  if (m.t === "da") r(m);
}));
console.log("annika da nach 75 s nur mit rohem ping:", da.annika);
clearInterval(timer);
annika.close(); ahmed.close();
process.exit(0);
