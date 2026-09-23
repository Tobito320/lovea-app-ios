// APNs push, HTTP/2 via fetch, token auth (JWT ES256) via WebCrypto. No
// library — Workers and Node both expose fetch + crypto.subtle.

const APNS_TOPIC = "com.onlyus.lovea";
const JWT_GUELTIG_MS = 60 * 60 * 1000; // eine Stunde zwischengespeichert

const b64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

function pemZuArrayBuffer(pem) {
  const b64 = pem.replace(/-----BEGIN [^-]+-----/, "").replace(/-----END [^-]+-----/, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

// Cache pro Modul-Instanz (überlebt mehrere Requests im selben Worker-Isolat).
const cache = new Map(); // keyId -> {jwt, erzeugtMs}

export async function apnsJwt(env, jetztMs = Date.now()) {
  const cached = cache.get(env.APNS_KEY_ID);
  if (cached && jetztMs - cached.erzeugtMs < JWT_GUELTIG_MS) return cached.jwt;

  const header = { alg: "ES256", kid: env.APNS_KEY_ID };
  const claims = { iss: env.APNS_TEAM_ID, iat: Math.floor(jetztMs / 1000) };
  const enc = new TextEncoder();
  const signingInput = `${b64url(enc.encode(JSON.stringify(header)))}.${b64url(enc.encode(JSON.stringify(claims)))}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemZuArrayBuffer(env.APNS_KEY_P8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(signingInput));
  const jwt = `${signingInput}.${b64url(signature)}`;
  cache.set(env.APNS_KEY_ID, { jwt, erzeugtMs: jetztMs });
  return jwt;
}

// stufe: "laut" | "leise" | "still". "still" = content-available, kein Text.
export function apnsPayload({ stufe, titel, text, ton, threadId = "wir" }) {
  if (stufe === "still") {
    return { aps: { "content-available": 1 } };
  }
  const aps = {
    alert: { title: titel, body: text },
    "interruption-level": stufe === "laut" ? "active" : "passive",
    "thread-id": threadId,
  };
  if (ton) aps.sound = ton;
  return { aps };
}

export function apnsHeaders({ stufe, jwt }) {
  return {
    authorization: `bearer ${jwt}`,
    "apns-topic": APNS_TOPIC,
    "apns-push-type": stufe === "still" ? "background" : "alert",
    "apns-priority": stufe === "still" ? "5" : "10",
    "content-type": "application/json",
  };
}

// Schickt eine Push. `fetchImpl` ist für Tests austauschbar. Bei 410 wird das
// Token beim Aufrufer als abgelaufen gemeldet (expired:true) -> er löscht es.
export async function push(env, token, nachricht, fetchImpl = fetch) {
  const jwt = await apnsJwt(env);
  const res = await fetchImpl(`https://api.push.apple.com/3/device/${token}`, {
    method: "POST",
    headers: apnsHeaders({ stufe: nachricht.stufe, jwt }),
    body: JSON.stringify(apnsPayload(nachricht)),
  });
  return { status: res.status, ok: res.status === 200, expired: res.status === 410 };
}
