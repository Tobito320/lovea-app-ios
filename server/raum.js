// Durable Object "Raum" (Z-1.2): SQLite-Speicher, ein WebSocket pro Person
// (Hibernation-API), Medien-Upload, Push und Zeitplan. Die eigentliche Logik
// steckt in raum-logic.js / push.js / regeln.js / zeitplan.js (pure, Node-
// testbar); diese Datei ist nur die dünne Verdrahtung gegen die echte
// Workers-Runtime (ctx.storage.sql, WebSocketPair, Alarme).
import {
  initSchema,
  opEinfuegenMitStatus,
  opGueltig,
  verbindungIstLebendig,
  opsSeit,
  SEITE,
  SEITE_BYTES,
  nurFuerAbsender,
  medienTeilSpeichern,
  medienFertig,
  medienFehlend,
  medienLesen,
  medienNachFertigAufraeumen,
  standortSchreiben,
  letzterStandort,
  zustandMerken,
  letzterZustand,
  zufaelligNah,
  einstellung,
  geraetSpeichern,
  geraetTokens,
  geraetLoeschen,
  offeneTreffen,
  offeneAngeheftet,
  offeneSpielEinladungen,
  alarmErledigt,
  alarmAlsErledigtMarkieren,
  letzteZufaelligNahMs,
  zufaelligNahAlsGemeldetMarkieren,
  ortInfo,
  gemeinsamPruefen,
  gemeinsamSeitMs,
  gemeinsamSeitSetzen,
  gemeinsamZuruecksetzen,
  spotifyTokenLesen,
  spotifyTokenSchreiben,
  spotifyCacheLesen,
  spotifyCacheSchreiben,
} from "./raum-logic.js";
import { agentStatistik, agentOps, agentMerker } from "./agent.js";
import { push } from "./push.js";
import { regel } from "./regeln.js";
import { naechsterAlarm, berlinDatum, montagDerWoche } from "./zeitplan.js";
import { brauchtErneuerung, cacheGueltig, tokenTauschen, tokenErneuern, jetztSpielt, nachFreigabe, fetchMitGrund } from "./spotify.js";
import { coachAntwort, coachMorgen, coachMorgenAn } from "./coach.js";
import { eintraegeLesen } from "./eintraege.js";
import { tagesformBerechnen } from "./tagesform.js";
import { katalog as coachKatalog } from "./coach-katalog.js";

const PERSONEN = ["ahmed", "annika"];
const partnerVon = (person) => (person === "ahmed" ? "annika" : "ahmed");
const MEDIEN_TEIL_MAX = 1024 * 1024; // 1 MiB, siehe schnittstellen.md

const ALARM_TEXT = {
  vorabend: { titel: "Lovea", text: "Morgen seht ihr euch", stufe: "laut", kategorie: "kalender" },
  stundeVorher: { titel: "Lovea", text: "In einer Stunde geht's los", stufe: "laut", kategorie: "kalender" },
  frageDesTages: { titel: "Lovea", text: "Die Frage des Tages ist da", stufe: "leise", kategorie: "frage" },
  // Z-22.3: nur eine Mitteilung, der Server rechnet keine Punkte -- die App zeigt beim Öffnen, wie's steht.
  challengeEndspurtWoche: { titel: "Lovea", text: "Letzter Tag für die Wochen-Challenges!", stufe: "laut", kategorie: "challenge" },
  challengeEndeWoche: { titel: "Lovea", text: "Die Wochen-Challenges sind vorbei — schaut nach, wie's steht", stufe: "leise", kategorie: "challenge" },
  challengeEndspurtMonat: { titel: "Lovea", text: "Letzter Tag für Gemeinsam Monat!", stufe: "laut", kategorie: "challenge" },
  challengeEndeMonat: { titel: "Lovea", text: "Der Monats-Challenge ist vorbei — schaut nach, wie's steht", stufe: "leise", kategorie: "challenge" },
  // Health-Coach: Push ohne Inhalt (der Coach-Text steht nur im Chat), nur an die Person, die es eingeschaltet hat.
  coachMorgen: { titel: "Lovea", text: "Dein Coach hat geschrieben", stufe: "leise", kategorie: "coach" },
};

export class Raum {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.sql = ctx.storage.sql;
    ctx.blockConcurrencyWhile(async () => initSchema(this.sql));
    // I-5: native Hibernation-Ping/Pong. Der Server antwortet auf ein rohes
    // "ping" (kein JSON) mit "pong", ganz ohne den DO aufzuwecken --
    // funktioniert auch, während er evictet ist. `typeof` schützt den Node-
    // Test-Import (WebSocketRequestResponsePair existiert nur im Workers-
    // Runtime-Global-Scope); `ctx.setWebSocketAutoResponse?.` schützt die
    // Fake-ctx in den Tests.
    if (typeof WebSocketRequestResponsePair !== "undefined") {
      ctx.setWebSocketAutoResponse?.(new WebSocketRequestResponsePair("ping", "pong"));
    }
  }

  async fetch(request) {
    const url = new URL(request.url);
    const teile = url.pathname.split("/").filter(Boolean);
    const person = request.headers.get("X-Lovea-Person") ?? url.searchParams.get("person");

    if (url.pathname === "/raum") return this.#upgrade(request, url, person);
    if (url.pathname === "/ops" && request.method === "POST") return this.#opsBatch(request, url, person);
    if (url.pathname === "/fl" && request.method === "POST") return this.#flHttp(request, person);
    if (teile[0] === "medien") return this.#medien(request, teile, person);
    if (url.pathname === "/spotify/verbinden" && request.method === "POST") return this.#spotifyVerbinden(request, person);
    if (url.pathname === "/spotify/jetzt" && request.method === "GET") return this.#spotifyJetzt(url);
    if (url.pathname === "/spotify/status" && request.method === "GET") return this.#spotifyStatus(person);
    if (url.pathname === "/spotify/trennen" && request.method === "POST") return this.#spotifyTrennen(person);
    if (url.pathname === "/coach/frage" && request.method === "POST") return this.#coachFrage(request, person);
    if (url.pathname === "/eintraege/lesen" && request.method === "POST") return this.#eintraegeLesen(request, person);
    if (url.pathname === "/coach/tagesform" && request.method === "POST") return this.#coachTagesform(request, person);
    if (teile[0] === "agent" && request.method === "GET") return this.#agent(teile[1], url, person);
    return new Response("not found", { status: 404 });
  }

  // Nur-Lese-Diagnose für KI-Agenten (server/mcp.mjs), Logik in agent.js.
  #agent(was, url, person) {
    if (!PERSONEN.includes(person)) return new Response("unauthorized", { status: 401 });
    const q = Object.fromEntries(url.searchParams);
    if (was === "ping") return Response.json({ ok: true, zeit: new Date().toISOString() });
    if (was === "statistik") {
      const verbunden = this.ctx.getWebSockets().map((ws) => this.ctx.getTags(ws)[0]);
      return Response.json({ ...agentStatistik(this.sql), verbunden, dbBytes: this.ctx.storage.sql.databaseSize ?? null });
    }
    if (was === "ops") return Response.json(agentOps(this.sql, { ...q, aufsteigend: q.aufsteigend === "1", voll: q.voll === "1" }, person));
    if (was === "merker" && q.schluessel) return Response.json(agentMerker(this.sql, q.schluessel));
    return new Response("not found", { status: 404 });
  }

  // Fürs Hintergrund-Standort-Tracking (I-5-Kontext): der WebSocket wird ~30s
  // nach dem Backgrounden geschlossen, aber CLLocationManager liefert weiter
  // Updates. POST /fl verhält sich exakt wie ein WebSocket-`fl` derselben
  // Person -- kein eigener Zustand, nur ein zweiter Eingang zu #flVerarbeiten.
  async #flHttp(request, person) {
    if (!PERSONEN.includes(person)) return new Response("unauthorized", { status: 401 });
    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("bad request", { status: 400 });
    }
    if (typeof body?.art !== "string" || typeof body?.d !== "object" || body.d === null || Array.isArray(body.d)) {
      return new Response("bad request", { status: 400 });
    }
    await this.#flVerarbeiten(person, body.art, body.d);
    return new Response(null, { status: 204 });
  }

  // --- WebSocket -----------------------------------------------------------

  #upgrade(request, url, person) {
    if (request.headers.get("Upgrade") !== "websocket") return new Response("expected websocket", { status: 426 });
    const seit = Number(url.searchParams.get("seit") ?? 0);
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [person]);
    this.#kontaktAktualisieren(server);

    // `seite: true` markiert eine Nachhol-Seite (beim Verbinden oder auf
    // `nachholen`) im Unterschied zu einem einzelnen Echo/Live-Broadcast --
    // der Client kann so eine sicheren Nachhol-Cursor führen, der nicht durch
    // dazwischenkommende Echos verfälscht wird. Zusatzfeld, kein Bruch: alte
    // Clients ignorieren es.
    const seitenDaten = opsSeit(this.sql, seit, SEITE, SEITE_BYTES, person);
    server.send(JSON.stringify({ t: "ops", ...seitenDaten, seite: true }));

    const letzter = letzterStandort(this.sql, partnerVon(person));
    if (letzter) server.send(JSON.stringify({ t: "standort", person: partnerVon(person), d: letzter.d }));
    const zustand = letzterZustand(this.sql, partnerVon(person));
    // audit-szene #4: `seit` reitet mit, wie beim Live-Broadcast oben -- der Client erkennt daran
    // einen unveraenderten Replay (z. B. eine seit Tagen eingefrorene "schlaeft") statt ihn als
    // frisch zu behandeln, nur weil UNSER Reconnect ihn erneut ausgeliefert hat.
    if (zustand) {
      const d = zustand.zeit ? { ...zustand.d, seit: zustand.zeit } : zustand.d;
      server.send(JSON.stringify({ t: "fl", von: partnerVon(person), art: "zustand", d }));
    }

    this.#sendePraesenz();
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const person = this.ctx.getTags(ws)[0];
    // I-5: JEDE Nachricht zählt als Lebenszeichen, nicht nur ein Ping --
    // überlebt Hibernation über die Socket-Attachment (serializeAttachment).
    this.#kontaktAktualisieren(ws);

    let msg;
    try {
      msg = JSON.parse(typeof message === "string" ? message : new TextDecoder().decode(message));
    } catch {
      return;
    }

    if (msg.t === "op") {
      // I-3/M-3/M-4: Form prüfen und `von` gegen den Socket-Tag, BEVOR
      // gespeichert wird -- eine kaputte Op (fehlende id, falscher Absender,
      // unbekannte Person) wird nie in `ops` geschrieben.
      if (!opGueltig(msg.op, person)) {
        ws.send(JSON.stringify({ t: "fehler", meldung: "ungültige Op", opId: msg.op?.id }));
        return;
      }
      const { seq, neu } = opEinfuegenMitStatus(this.sql, msg.op);
      const bestaetigt = { ...msg.op, seq };
      // Das Echo an den Absender ist die Bestätigung -- auch bei einer
      // Wiederholung nach Funkloch, damit die Op die Warteschlange verlässt.
      ws.send(JSON.stringify({ t: "ops", ops: [bestaetigt], mehr: false }));
      if (neu) {
        this.#verteilen(ws, bestaetigt);
        await this.#pushFuerOp(bestaetigt).catch((err) => this.#log("push für Op fehlgeschlagen", bestaetigt.art, err));
        await this.#alarmAktualisieren();
      }
    } else if (msg.t === "nachholen") {
      ws.send(JSON.stringify({ t: "ops", ...opsSeit(this.sql, msg.seit ?? 0, SEITE, SEITE_BYTES, person), seite: true }));
    } else if (msg.t === "ping") {
      // Fallback für den Fall, dass ein Client kein rohes "ping" (natives
      // Hibernation-Auto-Response, siehe Konstruktor) senden kann.
      ws.send(JSON.stringify({ t: "pong", zeit: new Date().toISOString() }));
    } else if (msg.t === "geraet") {
      geraetSpeichern(this.sql, person, msg.token);
      this.#anhaengen(ws, { token: msg.token });
    } else if (msg.t === "fl") {
      await this.#flVerarbeiten(person, msg.art, msg.d);
    }
  }

  webSocketClose(ws) {
    this.#sendePraesenz(ws); // M-2: den gerade schließenden Socket ausdrücklich ausschließen
  }

  webSocketError(ws) {
    this.#sendePraesenz(ws);
  }

  // I-5: "verbunden" heißt jetzt "hat sich in den letzten 60s gemeldet"
  // (Ping oder irgendeine Nachricht), nicht mehr nur "Socket existiert" --
  // eine im Hintergrund suspendierte App bleibt sonst fälschlich "verbunden"
  // und bekommt keine Push mehr.
  #istVerbunden(person, ausser) {
    const jetzt = Date.now();
    return this.ctx.getWebSockets(person).some((ws) => {
      if (ws === ausser) return false;
      return verbindungIstLebendig(this.#letzterKontakt(ws), jetzt);
    });
  }

  #kontaktAktualisieren(ws) {
    this.#anhaengen(ws, { letzterKontakt: Date.now() });
  }

  // Attachment = {letzterKontakt, token}; überlebt Hibernation. Das Token sagt, welches Gerät
  // hinter dem Socket steckt (#pushAn).
  #anhaengen(ws, felder) {
    try {
      ws.serializeAttachment({ ...(ws.deserializeAttachment?.() ?? {}), ...felder });
    } catch {
      // Fake-Sockets in Tests haben kein serializeAttachment -- dann bleibt
      // #letzterKontakt() null, was verbindungIstLebendig() als "verbunden" wertet.
    }
  }

  // 27.09.: eine Op geht an alle anderen Geräte des Absenders (iPhone + iPad = ein Profil) und,
  // außer private Arten (Entwurf, Galerie), an den Partner. Der Absender-Socket hat sein Echo schon.
  #verteilen(absenderWs, op) {
    const eigene = this.ctx.getWebSockets(op.von).filter((s) => s !== absenderWs);
    const partner = nurFuerAbsender(op.art) ? [] : this.ctx.getWebSockets(partnerVon(op.von));
    this.#sendeAn([...eigene, ...partner], { t: "ops", ops: [op], mehr: false });
  }

  // Push an jedes Gerät der Person, das gerade keine lebende Verbindung hat -- ein offenes iPad
  // zu Hause darf dem iPhone in der Tasche keine Mitteilung wegnehmen.
  async #pushAn(person, nachricht, { auchVerbunden = false } = {}) {
    const jetzt = Date.now();
    const verbunden = new Set(
      this.ctx
        .getWebSockets(person)
        .filter((ws) => verbindungIstLebendig(this.#letzterKontakt(ws), jetzt))
        .map((ws) => this.#tokenVon(ws))
        .filter(Boolean)
    );
    for (const token of geraetTokens(this.sql, person)) {
      if (!auchVerbunden && verbunden.has(token)) continue;
      const res = await push(this.env, token, nachricht).catch((err) => {
        this.#log("push fehlgeschlagen", person, err);
        return null;
      });
      if (res && !res.ok) this.#log("APNs-Antwort", person, "->", res.status);
      if (res?.expired) geraetLoeschen(this.sql, token);
    }
  }

  #tokenVon(ws) {
    try {
      return ws.deserializeAttachment?.()?.token ?? null;
    } catch {
      return null;
    }
  }

  #letzterKontakt(ws) {
    let angehaengt = null;
    try {
      angehaengt = ws.deserializeAttachment?.()?.letzterKontakt ?? null;
    } catch {
      // ignorieren, s. o.
    }
    // Das native Ping/Pong (Konstruktor) überlebt Hibernation unabhängig vom
    // Attachment -- der jüngere der beiden Werte gewinnt.
    const autoDate = this.ctx.getWebSocketAutoResponseTimestamp?.(ws) ?? null;
    const autoMs = autoDate ? autoDate.getTime() : null;
    const werte = [angehaengt, autoMs].filter((x) => typeof x === "number");
    return werte.length ? Math.max(...werte) : null;
  }

  #sendePraesenz(ausser) {
    const status = { t: "da", ahmed: this.#istVerbunden("ahmed", ausser), annika: this.#istVerbunden("annika", ausser) };
    this.#sendeAn(this.ctx.getWebSockets(), status);
  }

  #sendeAnPartner(von, nachricht) {
    this.#sendeAn(this.ctx.getWebSockets(partnerVon(von)), nachricht);
  }

  // Ein throw in send() (z. B. ein Socket, der zwischen getWebSockets() und
  // hier schon weg ist) darf die anderen Empfänger nicht mitreißen.
  #sendeAn(sockets, nachricht) {
    const text = JSON.stringify(nachricht);
    for (const ws of sockets) {
      try {
        ws.send(text);
      } catch {
        // ignorieren -- Präsenz/Broadcast an einen toten Socket ist kein Fehler.
      }
    }
  }

  // Gemeinsamer Weg für ein `fl` -- egal ob per WebSocket oder per POST /fl
  // (Hintergrund-Standort, siehe #flHttp). `standort` hat sein eigenes
  // Wire-Format (`{t:"standort",...}`, siehe schnittstellen.md und
  // #standort()); alles andere geht als generisches `{t:"fl",von,art,d}`
  // nur an den Partner raus und wird nie gespeichert.
  async #flVerarbeiten(person, art, d) {
    if (art === "standort") {
      await this.#standort(person, d);
    } else {
      let ausgehend = d;
      if (art === "zustand") {
        // audit-szene #4: `seit` reitet auf `d` mit, damit der Client (auch beim Live-Empfang,
        // nicht nur beim Reconnect-Replay unten) weiss, wann DIESER Wert wirklich verschickt wurde.
        const zeitIso = new Date().toISOString();
        zustandMerken(this.sql, person, d, zeitIso);
        ausgehend = { ...d, seit: zeitIso };
      }
      this.#sendeAnPartner(person, { t: "fl", von: person, art, d: ausgehend });
      if (art === "karte.offen" && d?.an === true) await this.#karteWecken(partnerVon(person));
    }
  }

  // Partner im Hintergrund hat keinen Socket -- ohne Push bleibt sein Standort im Sparbetrieb
  // (alle paar Minuten). Stille Push, LoveaAppDelegate startet damit den Live-Modus.
  // ponytail: Drossel nur im Speicher, nach Hibernation darf eine Push extra rausgehen.
  #karteWeckMs = 0;
  async #karteWecken(partner) {
    if (Date.now() - this.#karteWeckMs < 60_000) return;
    this.#karteWeckMs = Date.now();
    await this.#pushAn(partner, { stufe: "still", daten: { art: "karte.offen", an: true } });
  }

  async #standort(person, d) {
    const jetzt = Date.now();
    const jetztIso = new Date(jetzt).toISOString();
    // Live geht immer sofort an den Partner (der Client steuert selbst, wie
    // oft er sendet). Nur das Wegschreiben in die Tabelle standort ist
    // gedrosselt (überlebt Reconnect/Hibernation), siehe schnittstellen.md.
    this.#sendeAnPartner(person, { t: "standort", person, d });
    standortSchreiben(this.sql, person, d, jetztIso, jetzt);
    await this.#pruefeZufaelligNah(person, d, jetzt).catch((err) => this.#log("Zufällig-nah-Prüfung fehlgeschlagen", err));
    this.#pruefeGemeinsam(person, d, jetzt);
  }

  // --- Unsere Orte (Z-27.4) ---------------------------------------------------

  #pruefeGemeinsam(person, d, jetztMs) {
    const partner = letzterStandort(this.sql, partnerVon(person));
    const a = { d, zeit: new Date(jetztMs).toISOString() };
    const { nah, seit, melden } = gemeinsamPruefen({ a, b: partner, jetztMs, seitMs: gemeinsamSeitMs(this.sql) });
    if (!nah) {
      gemeinsamZuruecksetzen(this.sql);
      return;
    }
    if (seit !== gemeinsamSeitMs(this.sql)) gemeinsamSeitSetzen(this.sql, seit);
    if (!melden) return;
    // Deterministische Op-id über `seit` -- solange die Streak andauert, dedupt INSERT OR IGNORE
    // jeden weiteren Aufruf, kein eigener "schon gemeldet"-Merker nötig.
    const op = { id: `gemeinsam-${seit}`, art: "ort.gemeinsam", von: person, zeit: new Date(jetztMs).toISOString(), d: { lat: d.lat, lon: d.lon, datum: berlinDatum(jetztMs) } };
    const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
    if (neu) this.#sendeAn(this.ctx.getWebSockets(), { t: "ops", ops: [{ ...op, seq }], mehr: false });
  }

  // --- Push für eintreffende Ops (Z-1.6) ------------------------------------

  #letztesHerz = {}; // nur im Speicher wie #letzterTon
  #letzterTon = {}; // ponytail: nur im Speicher, nach Hibernation klingt die nächste Push wieder
  async #pushFuerOp(op) {
    let kontext;
    if (op.art === "ort.ereignis") {
      const ort = ortInfo(this.sql, op.d.ortId);
      // Kein bekannter Ort, oder für diese Richtung abgeschaltet (melden:
      // "nichts"/"ankunft"/"verlassen"/"beides") -> keine Push (Spec 12:
      // "Ankunft oder Verlassen gewählter Orte").
      if (!ort || !(ort.melden === "beides" || ort.melden === op.d.art)) return;
      kontext = { ortName: ort.name };
    }
    const r = regel(op.art, op.von, op.d, kontext);
    if (!r || r.stufe === "inapp") return;
    const empfaenger = partnerVon(op.von);
    if (einstellung(this.sql, empfaenger, `mitteilungen.${r.kategorie}`) === false) return;

    // Herz-Tipps zählen alle, die Push geht höchstens alle 10 Minuten.
    if (op.art === "geste" && op.d.art === "herz") {
      if (Date.now() - (this.#letztesHerz[empfaenger] ?? 0) < 10 * 60_000) return;
      this.#letztesHerz[empfaenger] = Date.now();
    }

    const immer = op.art === "ort.ereignis"; // Ankunft/Verlassen gehen immer.
    // Z-32.1: Antippen springt im Chat zur Nachricht, die App liest `userInfo["nachrichtId"]`.
    // 25.09.: Kuss/Anstupsen/Herz (art "geste") schicken `art` mit, die App öffnet damit das Partnerprofil.
    const daten = op.art.startsWith("nachricht.") && typeof op.d.id === "string"
      ? { art: op.art, nachrichtId: op.d.id }
      : op.art === "geste" ? { art: op.art } : undefined;
    // Several pushes in a burst each played their sound over the last one ("glitch"): only the
    // first within 3 s per recipient rings, the rest arrive silently.
    const jetzt = Date.now();
    const ton = jetzt - (this.#letzterTon[empfaenger] ?? 0) < 3000 ? undefined : r.ton;
    if (ton) this.#letzterTon[empfaenger] = jetzt;
    await this.#pushAn(empfaenger, { stufe: r.stufe, titel: r.titel, text: r.text, ton, daten }, { auchVerbunden: immer });
  }

  // --- Zufällig nah (Z-1.8) --------------------------------------------------

  async #pruefeZufaelligNah(person, d, jetztMs) {
    const partner = partnerVon(person);
    const b = letzterStandort(this.sql, partner);
    if (!b) return;
    const a = { d, zeit: new Date(jetztMs).toISOString() };
    const heute = berlinDatum(jetztMs);
    const kontextAb = berlinDatum(jetztMs - 2 * 86_400_000);
    const heuteTreffen = offeneTreffen(this.sql, kontextAb).some((t) => t.datum === heute);
    if (!zufaelligNah({ a, b, jetztMs, heuteTreffen })) return;

    const letzteWarnungMs = letzteZufaelligNahMs(this.sql);
    if (letzteWarnungMs !== null && jetztMs - letzteWarnungMs < 6 * 3_600_000) return;
    zufaelligNahAlsGemeldetMarkieren(this.sql, jetztMs);

    // Eine Op "an beide" -- nicht zwei separate, sonst zwei System-Bubbles im Chat.
    const op = { id: `nah-${jetztMs}`, art: "nachricht.neu", von: person, zeit: new Date(jetztMs).toISOString(), d: { system: "nah" } };
    const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
    const bestaetigt = { ...op, seq };
    this.#sendeAn(this.ctx.getWebSockets(), { t: "ops", ops: [bestaetigt], mehr: false });
    if (neu) await this.#pushBeide({ stufe: "laut", titel: "Lovea", text: "Ihr seid gerade zufällig ganz nah beieinander" }, "orte");
  }

  // --- Ops-Batch (Umzugsskript, Z-1.9) ---------------------------------------

  async #opsBatch(request, url, person) {
    // Nur fürs Umzugsskript: Bulk-Import historischer Ops. Absichtlich keine
    // Push -- sonst spammen hunderte migrierte Ops beide Handys wach.
    const { ops } = await request.json();
    let letzteSeq = 0;
    let uebersprungen = 0;
    for (const op of ops ?? []) {
      // I-3: keine Verbindung hier, also nur "ist überhaupt eine gültige Op
      // einer bekannten Person" prüfen (kein Abgleich gegen einen Socket-Tag).
      if (!opGueltig(op)) {
        uebersprungen++;
        continue;
      }
      const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
      letzteSeq = seq;
      if (neu) this.#verteilen(null, { ...op, seq });
      // Widget-Herz (kein Socket): nur mit ?push=1, nur "geste", nur vom Absender selbst.
      if (neu && url?.searchParams.get("push") === "1" && op.art === "geste" && op.von === person) {
        await this.#pushFuerOp({ ...op, seq }).catch((err) => this.#log("push für Op fehlgeschlagen", op.art, err));
      }
    }
    await this.#alarmAktualisieren();
    return Response.json({ seq: letzteSeq, uebersprungen });
  }

  // --- Medien (Z-1.4) --------------------------------------------------------

  async #medien(request, teile, person) {
    // ["medien", id, rolle, teil|"fertig"] oder ["medien", id] oder ["medien", id, "fehlend"]
    const id = teile[1];
    if (!id) return new Response("bad request", { status: 400 });

    if (request.method === "PUT" && teile.length === 4) {
      const [, , rolle, teilStr] = teile;
      const teil = Number(teilStr);
      const bytes = new Uint8Array(await request.arrayBuffer());
      if (bytes.byteLength > MEDIEN_TEIL_MAX) return new Response("zu groß", { status: 413 });
      medienTeilSpeichern(this.sql, id, rolle, teil, bytes);
      return new Response(null, { status: 204 });
    }

    if (request.method === "POST" && teile[2] && teile[3] === "fertig") {
      const rolle = teile[2];
      const { teile: anzahl, typ, bytes } = await request.json();
      const ergebnis = medienFertig(this.sql, id, rolle, { teile: anzahl, typ, bytes, von: person });
      if (!ergebnis.fertig) return Response.json(ergebnis, { status: 409 });
      medienNachFertigAufraeumen(this.sql, id, rolle); // falls "original" schon vorher abgeholt wurde
      return Response.json(ergebnis);
    }

    if (request.method === "GET" && teile[2] === "fehlend") {
      const url = new URL(request.url);
      const rolle = url.searchParams.get("rolle") ?? "original";
      const teileParam = url.searchParams.get("teile"); // C-1: optionale Gesamtzahl vom Client
      const gesamt = teileParam !== null ? Number(teileParam) : undefined;
      return Response.json(medienFehlend(this.sql, id, rolle, gesamt));
    }

    if (request.method === "GET" && teile.length === 2) {
      const gefunden = medienLesen(this.sql, id, person);
      if (!gefunden) return new Response("not found", { status: 404 });
      return new Response(gefunden.daten, {
        headers: { "content-type": gefunden.typ ?? "application/octet-stream", "X-Lovea-Rolle": gefunden.rolle },
      });
    }

    return new Response("not found", { status: 404 });
  }

  // --- Spotify "hört gerade" (Z-27.6) -----------------------------------------

  // `person` (Header, schon geprüft) ist immer der Konto-Inhaber, der sich gerade verbindet --
  // ein `person` im Body wird ignoriert statt vertraut (M-3-artig: der Absender steht schon fest).
  async #spotifyVerbinden(request, person) {
    if (!this.env.SPOTIFY_CLIENT_ID) return Response.json({ fehler: "nicht eingerichtet" }, { status: 503 });
    let body;
    try {
      body = await request.json();
    } catch {
      return new Response("bad request", { status: 400 });
    }
    if (typeof body?.code !== "string" || typeof body?.verifier !== "string" || typeof body?.redirectUri !== "string") {
      return new Response("bad request", { status: 400 });
    }
    const holer = fetchMitGrund();
    const token = await tokenTauschen(this.env, { code: body.code, verifier: body.verifier, redirectUri: body.redirectUri }, holer).catch((err) => {
      this.#log("Spotify-Token-Tausch fehlgeschlagen", err);
      return null;
    });
    // `grund` = Spotifys eigener Fehlercode (invalid_client: Client-ID falsch; invalid_grant: Code oder Redirect-URI passt nicht).
    if (!token) return Response.json({ fehler: "tausch fehlgeschlagen", grund: holer.grund ?? "netz" }, { status: 502 });
    spotifyTokenSchreiben(this.sql, person, token);
    spotifyCacheSchreiben(this.sql, person, null); // ein alter Fehler im Cache gilt für die neue Verbindung nicht
    return Response.json({ ok: true });
  }

  // `person` in der Query ist die Zielperson (wessen Song gerade läuft), nicht der Abfragende --
  // der Partner schaut sich die eigene Figur des anderen an.
  async #spotifyJetzt(url) {
    const ziel = url.searchParams.get("person");
    if (!PERSONEN.includes(ziel)) return new Response("bad request", { status: 400 });

    const stufe = einstellung(this.sql, ziel, "spotify.teilen");
    if (stufe === "aus") return Response.json({}); // keine Spotify-Abfrage, wenn nichts geteilt wird
    return Response.json(nachFreigabe(await this.#spotifyDaten(ziel), stufe));
  }

  // Eigener Zustand fürs Einstellungs-Blatt: ist ein Token da, und was sagt Spotify dazu? Ignoriert die
  // Freigabe (der Konto-Inhaber sieht seine eigene Verbindung), und der Partner kann hier nicht mitlesen.
  async #spotifyStatus(person) {
    if (!PERSONEN.includes(person)) return new Response("bad request", { status: 400 });
    if (!this.env.SPOTIFY_CLIENT_ID) return Response.json({ verbunden: false, fehler: "nicht-eingerichtet" });
    if (!spotifyTokenLesen(this.sql, person)) return Response.json({ verbunden: false });
    const daten = await this.#spotifyDaten(person);
    return Response.json(daten.fehler ? { verbunden: true, fehler: daten.fehler } : { verbunden: true });
  }

  // Rohdaten (mit 20-s-Cache) zu `ziel`: Song, `{}` oder `{ fehler }`. Fehler landen auch im Cache,
  // damit ein kaputtes Token Spotify nicht alle 20 Sekunden erneut belästigt.
  async #spotifyDaten(ziel) {
    const jetztMs = Date.now();
    const cache = spotifyCacheLesen(this.sql, ziel);
    if (cacheGueltig(cache, jetztMs)) return cache.daten;

    let token = spotifyTokenLesen(this.sql, ziel);
    if (!token) return {};
    const speichern = (daten) => {
      spotifyCacheSchreiben(this.sql, ziel, { geladenMs: jetztMs, daten });
      return daten;
    };
    if (brauchtErneuerung(token.ablaeuftMs, jetztMs)) {
      const erneuert = await tokenErneuern(this.env, token).catch((err) => {
        this.#log("Spotify-Token-Erneuerung fehlgeschlagen", err);
        return null;
      });
      // Erneuern scheitert, wenn die Verbindung bei Spotify widerrufen wurde (oder Spotify nicht erreichbar ist).
      if (!erneuert) return speichern({ fehler: "abgelaufen" });
      token = erneuert;
      spotifyTokenSchreiben(this.sql, ziel, token);
    }
    const daten = await jetztSpielt(token.accessToken).catch((err) => {
      this.#log("Spotify jetztSpielt fehlgeschlagen", err);
      return { fehler: "spotify" };
    });
    return speichern(daten);
  }

  // Nur der Konto-Inhaber (Header) trennt sich selbst. `null` im Merker liest sich wie "nie verbunden".
  #spotifyTrennen(person) {
    if (!PERSONEN.includes(person)) return new Response("bad request", { status: 400 });
    spotifyTokenSchreiben(this.sql, person, null);
    spotifyCacheSchreiben(this.sql, person, null);
    return Response.json({ ok: true });
  }

  // --- Health-Coach (Logik in coach.js) -----------------------------------------

  async #coachFrage(request, person) {
    if (!PERSONEN.includes(person)) return new Response("bad request", { status: 400 });
    const body = await request.json().catch(() => null);
    const r = await coachAntwort({ sql: this.sql, env: this.env, person, text: body?.text, marker: body?.marker, jetztMs: Date.now(), katalog: coachKatalog });
    if (r.grund) this.#log("Coach", person, r.grund); // nur der kurze Grund, nie Rohantwort oder Schlüssel
    if (r.ops) this.#coachVerteilen(person, r.ops);
    return Response.json(r.body, { status: r.status });
  }

  async #eintraegeLesen(request, person) {
    if (!PERSONEN.includes(person)) return new Response("bad request", { status: 400 });
    const body = await request.json().catch(() => null);
    const r = await eintraegeLesen({ sql: this.sql, env: this.env, person, text: body?.text, jetztMs: Date.now() });
    if (r.grund) this.#log("Eintraege", person, r.grund);
    return Response.json(r.body, { status: r.status });
  }

  async #coachTagesform(request, person) {
    if (!PERSONEN.includes(person)) return new Response("bad request", { status: 400 });
    const body = await request.json().catch(() => null);
    const r = await tagesformBerechnen({ sql: this.sql, env: this.env, person, body, jetztMs: Date.now() });
    if (r.grund) this.#log("Coach", person, r.grund);
    return Response.json(r.body, { status: r.status });
  }

  // coach.nachricht ist privat: nur die Geräte der Person selbst (iPhone + iPad), nie der Partner.
  #coachVerteilen(person, ops) {
    this.#sendeAn(this.ctx.getWebSockets(person), { t: "ops", ops, mehr: false });
  }

  // Für zeitplan.js: aktiv = jemand hat die Morgen-Nachricht an UND der Schlüssel ist da.
  #coachMorgenKontext(heute) {
    if (!this.env.OPENAI_API_KEY) return { aktiv: false, erledigt: true };
    const an = PERSONEN.filter((p) => coachMorgenAn(this.sql, p));
    return { aktiv: an.length > 0, erledigt: an.every((p) => alarmErledigt(this.sql, "coachMorgen", `${p}.${heute}`)) };
  }

  // --- Alarme (Z-1.7) ---------------------------------------------------------

  async #alarmAktualisieren() {
    const jetzt = Date.now();
    const { naechste } = naechsterAlarm(this.#kontext(jetzt), jetzt);
    if (naechste) await this.ctx.storage.setAlarm(naechste);
    else await this.ctx.storage.deleteAlarm();
  }

  #kontext(jetztMs) {
    const heute = berlinDatum(jetztMs);
    // -2 Tage, nicht "heute": die Pünktlich-Karte für ein gestriges Treffen
    // braucht dessen treffen.setzen noch in der Liste (sie feuert erst am
    // Morgen danach). Die schon vergangenen vorabend/stundeVorher-Kandidaten
    // für so ein Treffen sind längst erledigt-markiert und damit ein No-op.
    const kontextAb = berlinDatum(jetztMs - 2 * 86_400_000);
    return {
      treffen: offeneTreffen(this.sql, kontextAb),
      angeheftet: offeneAngeheftet(this.sql),
      spielEinladungen: offeneSpielEinladungen(this.sql),
      erinnerungenHeute: {
        frage: alarmErledigt(this.sql, "frageDesTages", heute),
      },
      coachMorgen: this.#coachMorgenKontext(heute),
      challengeErledigt: {
        endspurtWoche: alarmErledigt(this.sql, "challengeEndspurtWoche", montagDerWoche(heute)),
        endeWoche: alarmErledigt(this.sql, "challengeEndeWoche", montagDerWoche(heute)),
        endspurtMonat: alarmErledigt(this.sql, "challengeEndspurtMonat", heute.slice(0, 7)),
        endeMonat: alarmErledigt(this.sql, "challengeEndeMonat", heute.slice(0, 7)),
      },
    };
  }

  async alarm() {
    const jetzt = Date.now();
    const { faellig } = naechsterAlarm(this.#kontext(jetzt), jetzt);
    for (const ereignis of faellig) {
      await this.#verarbeiteAlarm(ereignis, jetzt).catch((err) => this.#log("Alarm fehlgeschlagen", ereignis.art, err));
    }
    await this.#alarmAktualisieren();
  }

  async #verarbeiteAlarm(ereignis, jetztMs) {
    const jetztIso = new Date(jetztMs).toISOString();
    switch (ereignis.art) {
      case "vorabend":
      case "stundeVorher": {
        const schluessel = `${ereignis.datum}-${ereignis.art}`;
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide(ALARM_TEXT[ereignis.art], ALARM_TEXT[ereignis.art].kategorie);
        break;
      }
      case "puenktlichKarte": {
        const schluessel = ereignis.datum;
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide({ stufe: "still" }); // still: keine mitteilungen.<kategorie>-Prüfung nötig
        break;
      }
      case "frageDesTages": {
        const schluessel = berlinDatum(jetztMs);
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide(ALARM_TEXT[ereignis.art], ALARM_TEXT[ereignis.art].kategorie);
        break;
      }
      case "coachMorgen": {
        // coachMorgen() markiert den Tag je Person selbst, bevor es arbeitet: ein Fehler löst keine Alarm-Schleife aus.
        const { titel, text, stufe, kategorie } = ALARM_TEXT.coachMorgen;
        for (const person of PERSONEN) {
          try {
            const r = await coachMorgen({ sql: this.sql, env: this.env, person, jetztMs, katalog: coachKatalog });
            if (r.grund) this.#log("Coach Morgen", person, r.grund);
            if (!r.gesendet) continue;
            this.#coachVerteilen(person, r.ops);
            if (einstellung(this.sql, person, `mitteilungen.${kategorie}`) === false) continue;
            await this.#pushAn(person, { titel, text, stufe, daten: { art: "coach.nachricht" } });
          } catch (err) {
            this.#log("Coach Morgen fehlgeschlagen", person, err);
          }
        }
        break;
      }
      case "nachrichtLoesen": {
        const op = { id: `los-${ereignis.id}`, art: "nachricht.losgeloest", von: ereignis.von ?? "ahmed", zeit: jetztIso, d: { id: ereignis.id } };
        const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
        if (neu) this.#sendeAn(this.ctx.getWebSockets(), { t: "ops", ops: [{ ...op, seq }], mehr: false });
        break;
      }
      case "spielVerfallen": {
        const op = { id: `verfallen-${ereignis.id}`, art: "spiel.verfallen", von: ereignis.von ?? "ahmed", zeit: jetztIso, d: { id: ereignis.id } };
        const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
        if (neu) this.#sendeAn(this.ctx.getWebSockets(), { t: "ops", ops: [{ ...op, seq }], mehr: false });
        break;
      }
      case "challengeEndspurtWoche":
      case "challengeEndeWoche": {
        const schluessel = montagDerWoche(berlinDatum(jetztMs));
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide(ALARM_TEXT[ereignis.art], ALARM_TEXT[ereignis.art].kategorie);
        break;
      }
      case "challengeEndspurtMonat":
      case "challengeEndeMonat": {
        const schluessel = berlinDatum(jetztMs).slice(0, 7);
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide(ALARM_TEXT[ereignis.art], ALARM_TEXT[ereignis.art].kategorie);
        break;
      }
    }
  }

  async #pushBeide(nachricht, kategorie) {
    for (const person of PERSONEN) {
      if (kategorie && einstellung(this.sql, person, `mitteilungen.${kategorie}`) === false) continue;
      await this.#pushAn(person, nachricht);
    }
  }

  // ponytail: console.error statt stillem Schlucken -- sichtbar in
  // `wrangler tail`. Kein strukturiertes Logging, das lohnt sich erst mit
  // echtem Volumen.
  #log(...teile) {
    console.error("[raum]", ...teile);
  }
}
