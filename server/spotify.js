// Spotify "hört gerade" (Z-27.6): PKCE-Token-Tausch/-Erneuerung und die Abbildung der
// currently-playing-Antwort auf {titel, kuenstler, cover, url}. Reine Funktionen plus zwei
// Netzwerk-Aufrufer mit `fetchImpl` (wie push.js) -- so unter Node testbar, ohne echten
// Spotify-Zugriff. PKCE braucht kein Client-Secret (RFC 7636), nur `SPOTIFY_CLIENT_ID`.

const TOKEN_URL = "https://accounts.spotify.com/api/token";
const JETZT_URL = "https://api.spotify.com/v1/me/player/currently-playing";

export const CACHE_MS = 20_000; // Spec 12: "cache 20 s"
const ERNEUERN_PUFFER_MS = 60_000; // erneuern, sobald < 1 Min Restlaufzeit bleibt

// PKCE code_challenge = BASE64URL(SHA256(code_verifier)) wird auf dem Gerät gebaut (die App baut
// die Autorisierungs-URL) -- der Server bekommt nur `code` + `verifier` und reicht beides an
// Spotifys Token-Endpunkt weiter, der die Challenge selbst prüft. Kein eigener PKCE-Code hier.

export function brauchtErneuerung(ablaeuftMs, jetztMs = Date.now()) {
  return jetztMs >= ablaeuftMs - ERNEUERN_PUFFER_MS;
}

export function cacheGueltig(eintrag, jetztMs = Date.now()) {
  return eintrag != null && jetztMs - eintrag.geladenMs < CACHE_MS;
}

// Rohe currently-playing-Antwort (oder null/leer bei "nichts läuft") -> Wire-Shape (schnittstellen.md).
export function parseAktuellerSong(json) {
  if (!json || !json.item || json.is_playing === false) return {}; // pausiert ist kein "hört gerade"
  const item = json.item;
  return {
    titel: item.name ?? "",
    kuenstler: (item.artists ?? []).map((a) => a.name).join(", "),
    cover: item.album?.images?.[0]?.url ?? "",
    url: item.external_urls?.spotify ?? "",
  };
}

// Freigabe der Zielperson (Einstellung `spotify.teilen`), gefiltert hier auf dem Server, damit der
// Partner nie mehr bekommt als freigegeben. Fehlend oder unbekannt = "song" (bisheriges Verhalten).
export const STUFEN = ["aus", "musik", "kuenstler", "song"];

export function nachFreigabe(daten, stufe) {
  if (daten?.fehler) return { fehler: daten.fehler }; // Fehler sind kein Songinhalt, kein Freigabe-Filter nötig
  if (!daten?.titel) return {};
  switch (STUFEN.includes(stufe) ? stufe : "song") {
    case "aus": return {};
    case "musik": return { musik: true };
    case "kuenstler": return { musik: true, kuenstler: daten.kuenstler };
    default: return { musik: true, ...daten };
  }
}

// --- Netzwerk (fetchImpl austauschbar für Tests) ----------------------------

async function tokenAnfrage(env, body, fetchImpl, jetztMs) {
  const res = await fetchImpl(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) return null;
  const json = await res.json();
  if (!json.access_token) return null;
  return { accessToken: json.access_token, refreshToken: json.refresh_token, ablaeuftMs: jetztMs + json.expires_in * 1000, roh: json };
}

export async function tokenTauschen(env, { code, verifier, redirectUri }, fetchImpl = fetch, jetztMs = Date.now()) {
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: redirectUri,
    client_id: env.SPOTIFY_CLIENT_ID,
    code_verifier: verifier,
  });
  const ergebnis = await tokenAnfrage(env, body, fetchImpl, jetztMs);
  if (!ergebnis || !ergebnis.refreshToken) return null; // erster Tausch muss einen refresh_token liefern
  return { accessToken: ergebnis.accessToken, refreshToken: ergebnis.refreshToken, ablaeuftMs: ergebnis.ablaeuftMs };
}

// Ein alter refreshToken bleibt erhalten, wenn die Antwort keinen neuen mitschickt (Spotify tut
// das nicht bei jedem Refresh).
export async function tokenErneuern(env, alterToken, fetchImpl = fetch, jetztMs = Date.now()) {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: alterToken.refreshToken,
    client_id: env.SPOTIFY_CLIENT_ID,
  });
  const ergebnis = await tokenAnfrage(env, body, fetchImpl, jetztMs);
  if (!ergebnis) return null;
  return { accessToken: ergebnis.accessToken, refreshToken: ergebnis.roh.refresh_token ?? alterToken.refreshToken, ablaeuftMs: ergebnis.ablaeuftMs };
}

// Spotifys Fehlergrund zu einem Statuscode. Früher schluckte der Server jeden Fehlerstatus als `{}`,
// "nichts läuft" und "Spotify lehnt dich ab" sahen gleich aus -- die App konnte nie sagen, woran es liegt.
//   401 Token ungültig/widerrufen, 403 Konto nicht für die Entwickler-App freigeschaltet
//   (Development Mode: jedes Konto muss im Spotify-Dashboard unter "User Management" stehen), 429 zu viele Anfragen.
export function fehlerGrund(status) {
  if (status === 401) return "abgelaufen";
  if (status === 403) return "nicht-freigeschaltet";
  if (status === 429) return "zu-viele-anfragen";
  return "spotify";
}

// Hüllt `fetch` so ein, dass der Fehlergrund von Spotifys Token-Endpunkt (`error`, z. B. invalid_client,
// invalid_grant) mitgemerkt wird; der Tausch selbst liefert weiter nur `null`.
export function fetchMitGrund(fetchImpl = fetch) {
  const huelle = async (url, optionen) => {
    const res = await fetchImpl(url, optionen);
    if (!res.ok) huelle.grund = await res.clone().json().then((j) => String(j?.error ?? res.status)).catch(() => String(res.status));
    return res;
  };
  huelle.grund = null;
  return huelle;
}

// 204 (nichts läuft) ergibt `{}`. Jeder andere Fehlerstatus (401/403/429/...) ergibt `{ fehler }`.
export async function jetztSpielt(accessToken, fetchImpl = fetch) {
  const res = await fetchImpl(JETZT_URL, { headers: { authorization: `Bearer ${accessToken}` } });
  if (res.status === 204) return {};
  if (!res.ok) return { fehler: fehlerGrund(res.status) };
  const json = await res.json().catch(() => null);
  return parseAktuellerSong(json);
}
