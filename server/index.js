// Worker-Einstieg (Z-1.1): prüft den Schlüssel, leitet alles an das eine
// Objekt "Raum" weiter, proxyt GET /gif zu Klipy. Reine fetch(request, env)
// -Funktion ohne cloudflare:workers-Import -> unter Node testbar.
export { Raum } from "./raum.js";

const PERSONEN = new Set(["ahmed", "annika"]);

function gleicheLaenge(a, b) {
  // Konstante Zeit über die maximale Länge, auch bei unterschiedlicher Länge.
  const enc = new TextEncoder();
  const x = enc.encode(a ?? "");
  const y = enc.encode(b ?? "");
  const len = Math.max(x.length, y.length, 1);
  let diff = x.length ^ y.length;
  for (let i = 0; i < len; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

// Liefert die geprüfte Person oder null. Für /raum wird als ponytail-Fallback
// auch ?key=&person= akzeptiert, weil Node/URLSessionWebSocketTask-Gegenstücke
// nicht überall eigene Header aufs WebSocket-Upgrade legen können
// (pruefen.mjs nutzt Node's globales WebSocket, das keine Header kann).
export function pruefeAuth(request, env, url) {
  let schluessel = request.headers.get("X-Lovea-Key");
  let person = request.headers.get("X-Lovea-Person");
  if ((!schluessel || !person) && url.pathname === "/raum") {
    schluessel = schluessel ?? url.searchParams.get("key");
    person = person ?? url.searchParams.get("person");
  }
  if (!gleicheLaenge(schluessel, env.LOVEA_APP_KEY)) return null;
  if (!PERSONEN.has(person)) return null;
  return person;
}

async function gifProxy(url, env) {
  if (!env.KLIPY_KEY) return Response.json({ fehler: "nicht eingerichtet" }, { status: 503 });
  const q = url.searchParams.get("q");
  const basis = `https://api.klipy.com/api/v1/${env.KLIPY_KEY}/gifs`;
  const ziel = q ? `${basis}/search?q=${encodeURIComponent(q)}` : `${basis}/trending`;
  return fetch(ziel);
}

export async function handleFetch(request, env) {
  const url = new URL(request.url);
  const person = pruefeAuth(request, env, url);
  if (!person) return new Response("unauthorized", { status: 401 });

  if (url.pathname === "/gif") return gifProxy(url, env);

  const id = env.RAUM.idFromName("wir");
  const stub = env.RAUM.get(id, { locationHint: "weur" });
  return stub.fetch(request);
}

export default { fetch: handleFetch };
