// Prüft die KI-Endpunkte gegen einen laufenden Worker (meist lovea-test):
//   node --env-file=.env server/pruefen-ki.mjs https://lovea-test.<konto>.workers.dev ahmed [foto.jpg]
// Braucht LOVEA_APP_KEY in der Umgebung. Kostet zusammen ein paar Hundertstel Cent
// und zählt zu den Tageslimits der Person.
import { readFile } from "node:fs/promises";

const [, , basis, person = "ahmed", foto] = process.argv;
const schluessel = process.env.LOVEA_APP_KEY;
if (!basis || !schluessel) {
  console.error("Aufruf: node --env-file=.env server/pruefen-ki.mjs <worker-url> [person] [foto.jpg]  (LOVEA_APP_KEY nötig)");
  process.exit(2);
}

const kopf = { "X-Lovea-Key": schluessel, "X-Lovea-Person": person, "Content-Type": "application/json" };
let fehler = 0;
const melde = (name, ok, info = "") => {
  console.log(`${ok ? "OK    " : "FEHLER"} ${name}${info ? ` -- ${info}` : ""}`);
  if (!ok) fehler++;
};

async function aufruf(pfad, body) {
  const res = await fetch(basis + pfad, { method: body ? "POST" : "GET", headers: kopf, body: body ? JSON.stringify(body) : undefined });
  let j = null;
  try {
    j = await res.json();
  } catch {
    /* kein JSON */
  }
  return { status: res.status, j };
}

const s = await aufruf("/ki/status");
melde("status", s.status === 200 && s.j?.eingerichtet === true, s.j?.eingerichtet === false ? "OPENAI_API_KEY fehlt im Worker" : `Rest heute: ${JSON.stringify(s.j?.rest)}`);

const profil = { ziel: "cut", kcal: 2100, protein: 160 };
const c = await aufruf("/ki/coach", { nachrichten: [{ rolle: "nutzer", text: "Ich habe heute noch 400 kcal übrig. Was esse ich?" }], profil, tag: { kcal_gegessen: 1700, protein: 110 } });
melde("coach", c.status === 200 && typeof c.j?.antwort === "string" && c.j.antwort.length > 10, c.j?.antwort?.slice(0, 80) ?? JSON.stringify(c.j));

const b = await aufruf("/ki/bericht", { profil, tag: { kcal_gegessen: 2000, protein: 120, schritte: 8000, schlaf_h: 7, mahlzeiten: [{ name: "Haferflocken mit Quark", kcal: 450 }] } });
melde("bericht", b.status === 200 && b.j?.titel && b.j?.kurzfassung, b.j?.titel ?? JSON.stringify(b.j));

if (foto) {
  const bild = (await readFile(foto)).toString("base64");
  const e = await aufruf("/ki/essen", { bild, mime: foto.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg", mahlzeit: "mittag" });
  melde("essen", e.status === 200 && e.j?.ist_essen === true && e.j.items.length > 0, e.j?.ist_essen ? `${e.j.gesamt.kcal} kcal (${e.j.gesamt.kcal_min}-${e.j.gesamt.kcal_max}), ${e.j.items.map((i) => `${i.name} ${i.gramm} g`).join(", ")}` : JSON.stringify(e.j));
} else {
  console.log("INFO   Kein Foto angegeben -> /ki/essen übersprungen");
}

process.exit(fehler ? 1 : 0);
