#!/usr/bin/env node
// Prüfskript für Z-1.9: verbindet gegen einen laufenden Worker (typischerweise
// lovea-test), schickt eine Op, prüft das Echo mit seq, verbindet neu und holt
// sie über `seit=0` nach, lädt dann ein zweiteiliges Medium hoch und wieder
// runter. Aufruf: `node server/pruefen.mjs https://lovea-test.<konto>.workers.dev`
import { readFileSync } from "node:fs";

// ponytail: fester Pfad zum lokalen Geheimnis-Ordner (nicht Teil des Repos,
// pro-PC). Node's globales WebSocket kann keine eigenen Header setzen, daher
// nutzt dieses Skript den in schnittstellen.md dokumentierten Query-Fallback
// (?key=&person=) für den /raum-Upgrade; HTTP-Aufrufe (Medien) nutzen echte
// Header.
const SCHLUESSEL_PFAD = "C:\\Users\\ahmed\\code\\lovea-app-ios\\signing\\lovea-app.key";

const basisUrl = process.argv[2];
if (!basisUrl) {
  console.error("Aufruf: node server/pruefen.mjs <https://lovea-test....workers.dev>");
  process.exit(1);
}
const schluessel = readFileSync(SCHLUESSEL_PFAD, "utf8").trim();
const person = "ahmed";
const wsBasis = basisUrl.replace(/^http/, "ws");

let bestanden = 0;
let fehlgeschlagen = 0;
function pruefe(name, bedingung) {
  if (bedingung) {
    bestanden++;
    console.log(`✔ ${name}`);
  } else {
    fehlgeschlagen++;
    console.error(`✘ ${name}`);
  }
}

function verbinden(seit = 0) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`${wsBasis}/raum?seit=${seit}&key=${encodeURIComponent(schluessel)}&person=${person}`);
    const nachrichten = [];
    ws.addEventListener("message", (ev) => nachrichten.push(JSON.parse(ev.data)));
    ws.addEventListener("error", reject);
    ws.addEventListener("open", () => resolve({ ws, nachrichten }));
  });
}

function warteAufNachricht(nachrichten, passt, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const tick = () => {
      const treffer = nachrichten.find(passt);
      if (treffer) return resolve(treffer);
      if (Date.now() - start > timeoutMs) return reject(new Error("Timeout beim Warten auf Nachricht"));
      setTimeout(tick, 50);
    };
    tick();
  });
}

async function main() {
  // 1) Verbinden, Op senden, Echo mit seq bekommen.
  const { ws, nachrichten } = await verbinden(0);
  const opId = crypto.randomUUID();
  const op = { id: opId, art: "nachricht.neu", von: person, zeit: new Date().toISOString(), d: { text: "pruefen.mjs" } };
  ws.send(JSON.stringify({ t: "op", op }));

  const echo = await warteAufNachricht(nachrichten, (m) => m.t === "ops" && m.ops.some((o) => o.id === opId));
  const bestaetigteOp = echo.ops.find((o) => o.id === opId);
  pruefe("Echo der eigenen Op mit seq", typeof bestaetigteOp?.seq === "number");
  ws.close();

  // 2) Neu verbinden mit seit=0, Op muss wieder da sein (Nachholen).
  const { ws: ws2, nachrichten: nachrichten2 } = await verbinden(0);
  const seite = await warteAufNachricht(nachrichten2, (m) => m.t === "ops");
  pruefe("Nachholen (seit=0) liefert die Op erneut", seite.ops.some((o) => o.id === opId));
  ws2.close();

  // 3) Medium in 2 Teilen hoch- und wieder runterladen.
  const medienId = crypto.randomUUID();
  const headers = { "X-Lovea-Key": schluessel, "X-Lovea-Person": person };
  const teil0 = new Uint8Array([1, 2, 3, 4]);
  const teil1 = new Uint8Array([5, 6, 7, 8]);

  const put0 = await fetch(`${basisUrl}/medien/${medienId}/original/0`, { method: "PUT", headers, body: teil0 });
  const put1 = await fetch(`${basisUrl}/medien/${medienId}/original/1`, { method: "PUT", headers, body: teil1 });
  pruefe("Medien-Teile hochladen (204)", put0.status === 204 && put1.status === 204);

  const fertig = await fetch(`${basisUrl}/medien/${medienId}/original/fertig`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json" },
    body: JSON.stringify({ teile: 2, typ: "application/octet-stream", bytes: 8 }),
  });
  pruefe("Medium als fertig markiert", fertig.status === 200);

  const geholt = await fetch(`${basisUrl}/medien/${medienId}`, { headers: { ...headers, "X-Lovea-Person": "annika" } });
  const bytes = new Uint8Array(await geholt.arrayBuffer());
  pruefe("Medium herunterladen liefert die richtigen Bytes", geholt.status === 200 && bytes.length === 8 && bytes[0] === 1 && bytes[7] === 8);

  console.log(`\n${bestanden} bestanden, ${fehlgeschlagen} fehlgeschlagen`);
  process.exit(fehlgeschlagen === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error("Prüfskript fehlgeschlagen:", err);
  process.exit(1);
});
