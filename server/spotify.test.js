import { test } from "node:test";
import assert from "node:assert/strict";
import { brauchtErneuerung, cacheGueltig, parseAktuellerSong, tokenTauschen, tokenErneuern, jetztSpielt, CACHE_MS } from "./spotify.js";

const env = { SPOTIFY_CLIENT_ID: "test-client-id" };

function fakeFetch(antwort) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    return antwort(url, init);
  };
  impl.calls = calls;
  return impl;
}

test("brauchtErneuerung: erst innerhalb der letzten Minute vor Ablauf", () => {
  assert.equal(brauchtErneuerung(100_000, 39_999), false);
  assert.equal(brauchtErneuerung(100_000, 40_000), true);
  assert.equal(brauchtErneuerung(100_000, 100_000), true);
});

test("cacheGueltig: 20 s Fenster, leer ist nie gültig", () => {
  assert.equal(cacheGueltig(null, 1000), false);
  assert.equal(cacheGueltig({ geladenMs: 1000 }, 1000 + CACHE_MS - 1), true);
  assert.equal(cacheGueltig({ geladenMs: 1000 }, 1000 + CACHE_MS), false);
});

test("parseAktuellerSong: Track -> {titel,kuenstler,cover,url}, kein Track -> {}", () => {
  const antwort = {
    item: {
      name: "Ein Song",
      artists: [{ name: "Erste Band" }, { name: "Feat." }],
      album: { images: [{ url: "https://img/1.jpg" }, { url: "https://img/2.jpg" }] },
      external_urls: { spotify: "https://open.spotify.com/track/abc" },
    },
  };
  assert.deepEqual(parseAktuellerSong(antwort), {
    titel: "Ein Song",
    kuenstler: "Erste Band, Feat.",
    cover: "https://img/1.jpg",
    url: "https://open.spotify.com/track/abc",
  });
  assert.deepEqual(parseAktuellerSong(null), {});
  assert.deepEqual(parseAktuellerSong({}), {});
});

test("tokenTauschen: schickt grant_type=authorization_code mit PKCE-Verifier, kein Client-Secret", async () => {
  const fetchImpl = fakeFetch(async () => Response.json({ access_token: "AT", refresh_token: "RT", expires_in: 3600 }));
  const token = await tokenTauschen(env, { code: "CODE", verifier: "VERIFIER", redirectUri: "lovea://spotify" }, fetchImpl, 1_000_000);
  assert.deepEqual(token, { accessToken: "AT", refreshToken: "RT", ablaeuftMs: 1_000_000 + 3_600_000 });

  const [{ url, init }] = fetchImpl.calls;
  assert.equal(url, "https://accounts.spotify.com/api/token");
  const body = new URLSearchParams(init.body);
  assert.equal(body.get("grant_type"), "authorization_code");
  assert.equal(body.get("code_verifier"), "VERIFIER");
  assert.equal(body.get("client_id"), "test-client-id");
  assert.equal(body.has("client_secret"), false);
});

test("tokenTauschen: keine access_token/refresh_token in der Antwort -> null", async () => {
  const ohneRefresh = fakeFetch(async () => Response.json({ access_token: "AT", expires_in: 3600 }));
  assert.equal(await tokenTauschen(env, { code: "c", verifier: "v", redirectUri: "r" }, ohneRefresh), null);

  const fehler = fakeFetch(async () => new Response(null, { status: 400 }));
  assert.equal(await tokenTauschen(env, { code: "c", verifier: "v", redirectUri: "r" }, fehler), null);
});

test("tokenErneuern: behält den alten refresh_token, wenn keiner mitkommt; nimmt neuen, wenn er kommt", async () => {
  const alterToken = { accessToken: "alt", refreshToken: "RT-alt", ablaeuftMs: 0 };

  const ohneNeuen = fakeFetch(async () => Response.json({ access_token: "AT-neu", expires_in: 3600 }));
  const erneuert1 = await tokenErneuern(env, alterToken, ohneNeuen, 2_000_000);
  assert.deepEqual(erneuert1, { accessToken: "AT-neu", refreshToken: "RT-alt", ablaeuftMs: 2_000_000 + 3_600_000 });

  const mitNeuem = fakeFetch(async () => Response.json({ access_token: "AT-neu2", refresh_token: "RT-neu", expires_in: 3600 }));
  const erneuert2 = await tokenErneuern(env, alterToken, mitNeuem, 2_000_000);
  assert.equal(erneuert2.refreshToken, "RT-neu");

  const [{ init }] = ohneNeuen.calls;
  const body = new URLSearchParams(init.body);
  assert.equal(body.get("grant_type"), "refresh_token");
  assert.equal(body.get("refresh_token"), "RT-alt");
});

test("jetztSpielt: 204 (nichts läuft) und ein Fehlerstatus ergeben beide {}", async () => {
  const leer = fakeFetch(async () => new Response(null, { status: 204 }));
  assert.deepEqual(await jetztSpielt("AT", leer), {});

  const abgelehnt = fakeFetch(async () => new Response(null, { status: 401 }));
  assert.deepEqual(await jetztSpielt("AT", abgelehnt), {});
});

test("jetztSpielt: trägt den Access-Token als Bearer-Header ein und liefert den geparsten Song", async () => {
  const fetchImpl = fakeFetch(async () =>
    Response.json({ item: { name: "Song", artists: [{ name: "Band" }], album: { images: [] }, external_urls: { spotify: "u" } } })
  );
  const song = await jetztSpielt("mein-token", fetchImpl);
  assert.equal(song.titel, "Song");
  assert.equal(fetchImpl.calls[0].init.headers.authorization, "Bearer mein-token");
});
