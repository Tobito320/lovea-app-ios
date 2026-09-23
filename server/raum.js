// Durable Object "Raum" (Z-1.2): SQLite-Speicher, ein WebSocket pro Person
// (Hibernation-API), Medien-Upload, Push und Zeitplan. Die eigentliche Logik
// steckt in raum-logic.js / push.js / regeln.js / zeitplan.js (pure, Node-
// testbar); diese Datei ist nur die dünne Verdrahtung gegen die echte
// Workers-Runtime (ctx.storage.sql, WebSocketPair, Alarme).
import {
  initSchema,
  opEinfuegenMitStatus,
  opsSeit,
  medienTeilSpeichern,
  medienFertig,
  medienFehlend,
  medienLesen,
  standortSchreiben,
  letzterStandort,
  zufaelligNah,
  einstellung,
  geraetSpeichern,
  geraetToken,
  geraetLoeschen,
  offeneTreffen,
  offeneAngeheftet,
  offeneSpielEinladungen,
  streakLaeuftHeuteAb,
  alarmErledigt,
  alarmAlsErledigtMarkieren,
  letzteZufaelligNahMs,
} from "./raum-logic.js";
import { push } from "./push.js";
import { regel } from "./regeln.js";
import { naechsterAlarm, berlinDatum } from "./zeitplan.js";

const PERSONEN = ["ahmed", "annika"];
const partnerVon = (person) => (person === "ahmed" ? "annika" : "ahmed");
const MEDIEN_TEIL_MAX = 1024 * 1024; // 1 MiB, siehe schnittstellen.md

const ALARM_TEXT = {
  vorabend: { titel: "Lovea", text: "Morgen seht ihr euch", stufe: "laut", kategorie: "kalender" },
  stundeVorher: { titel: "Lovea", text: "In einer Stunde geht's los", stufe: "laut", kategorie: "kalender" },
  frageDesTages: { titel: "Lovea", text: "Die Frage des Tages ist da", stufe: "leise", kategorie: "frage" },
  streakWarnung: { titel: "Lovea", text: "Euer Streak läuft heute ab!", stufe: "laut", kategorie: "streak" },
};

export class Raum {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
    this.sql = ctx.storage.sql;
    ctx.blockConcurrencyWhile(async () => initSchema(this.sql));
  }

  async fetch(request) {
    const url = new URL(request.url);
    const teile = url.pathname.split("/").filter(Boolean);
    const person = request.headers.get("X-Lovea-Person") ?? url.searchParams.get("person");

    if (url.pathname === "/raum") return this.#upgrade(request, url, person);
    if (url.pathname === "/ops" && request.method === "POST") return this.#opsBatch(request);
    if (teile[0] === "medien") return this.#medien(request, teile, person);
    return new Response("not found", { status: 404 });
  }

  // --- WebSocket -----------------------------------------------------------

  #upgrade(request, url, person) {
    if (request.headers.get("Upgrade") !== "websocket") return new Response("expected websocket", { status: 426 });
    const seit = Number(url.searchParams.get("seit") ?? 0);
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [person]);

    const seite = opsSeit(this.sql, seit);
    server.send(JSON.stringify({ t: "ops", ...seite }));

    const letzter = letzterStandort(this.sql, partnerVon(person));
    if (letzter) server.send(JSON.stringify({ t: "standort", person: partnerVon(person), d: letzter.d }));

    this.#sendePraesenz();
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const person = this.ctx.getTags(ws)[0];
    let msg;
    try {
      msg = JSON.parse(typeof message === "string" ? message : new TextDecoder().decode(message));
    } catch {
      return;
    }

    if (msg.t === "op") {
      const { seq, neu } = opEinfuegenMitStatus(this.sql, msg.op);
      const bestaetigt = { ...msg.op, seq };
      // Das Echo an den Absender ist die Bestätigung -- auch bei einer
      // Wiederholung nach Funkloch, damit die Op die Warteschlange verlässt.
      ws.send(JSON.stringify({ t: "ops", ops: [bestaetigt], mehr: false }));
      if (neu) {
        this.#sendeAnPartner(person, { t: "ops", ops: [bestaetigt], mehr: false });
        await this.#pushFuerOp(bestaetigt).catch(() => {});
        await this.#alarmAktualisieren();
      }
    } else if (msg.t === "nachholen") {
      ws.send(JSON.stringify({ t: "ops", ...opsSeit(this.sql, msg.seit ?? 0) }));
    } else if (msg.t === "geraet") {
      geraetSpeichern(this.sql, person, msg.token);
    } else if (msg.t === "fl") {
      if (msg.art === "standort") {
        await this.#standort(person, msg.d);
      } else {
        this.#sendeAnPartner(person, { t: "fl", von: person, art: msg.art, d: msg.d });
      }
    }
  }

  webSocketClose(ws) {
    this.#sendePraesenz();
  }

  webSocketError(ws) {
    this.#sendePraesenz();
  }

  #istVerbunden(person) {
    return this.ctx.getWebSockets(person).length > 0;
  }

  #sendePraesenz() {
    const status = { t: "da", ahmed: this.#istVerbunden("ahmed"), annika: this.#istVerbunden("annika") };
    for (const ws of this.ctx.getWebSockets()) ws.send(JSON.stringify(status));
  }

  #sendeAnPartner(von, nachricht) {
    for (const ws of this.ctx.getWebSockets(partnerVon(von))) ws.send(JSON.stringify(nachricht));
  }

  async #standort(person, d) {
    const jetzt = Date.now();
    const geschrieben = standortSchreiben(this.sql, person, d, new Date(jetzt).toISOString(), jetzt);
    if (!geschrieben) return;
    this.#sendeAnPartner(person, { t: "standort", person, d });
    await this.#pruefeZufaelligNah(person, d, jetzt).catch(() => {});
  }

  // --- Push für eintreffende Ops (Z-1.6) ------------------------------------

  async #pushFuerOp(op) {
    const r = regel(op.art, op.von, op.d);
    if (!r || r.stufe === "inapp") return;
    const empfaenger = partnerVon(op.von);
    if (einstellung(this.sql, empfaenger, `mitteilungen.${r.kategorie}`) === false) return;

    const immer = op.art === "ort.ereignis"; // Ankunft/Verlassen gehen immer.
    if (!immer && this.#istVerbunden(empfaenger)) return;

    const token = geraetToken(this.sql, empfaenger);
    if (!token) return;
    const res = await push(this.env, token, { stufe: r.stufe, titel: r.titel, text: r.text, ton: r.ton });
    if (res.expired) geraetLoeschen(this.sql, empfaenger);
  }

  // --- Zufällig nah (Z-1.8) --------------------------------------------------

  async #pruefeZufaelligNah(person, d, jetztMs) {
    const partner = partnerVon(person);
    const b = letzterStandort(this.sql, partner);
    if (!b) return;
    const a = { d, zeit: new Date(jetztMs).toISOString() };
    const heute = berlinDatum(jetztMs);
    const heuteTreffen = offeneTreffen(this.sql, heute).some((t) => t.datum === heute);
    if (!zufaelligNah({ a, b, jetztMs, heuteTreffen })) return;

    const letzteWarnungMs = letzteZufaelligNahMs(this.sql);
    if (letzteWarnungMs !== null && jetztMs - letzteWarnungMs < 6 * 3_600_000) return;

    for (const von of [person, partner]) {
      const op = {
        id: `nah-${jetztMs}-${von}`,
        art: "nachricht.neu",
        von,
        zeit: new Date(jetztMs).toISOString(),
        d: { system: "nah" },
      };
      const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
      const bestaetigt = { ...op, seq };
      for (const ws of this.ctx.getWebSockets(von)) ws.send(JSON.stringify({ t: "ops", ops: [bestaetigt], mehr: false }));
      this.#sendeAnPartner(von, { t: "ops", ops: [bestaetigt], mehr: false });
      if (neu) await this.#pushFuerOp(bestaetigt).catch(() => {});
    }
  }

  // --- Ops-Batch (Umzugsskript, Z-1.9) ---------------------------------------

  async #opsBatch(request) {
    const { ops } = await request.json();
    let letzteSeq = 0;
    for (const op of ops ?? []) {
      const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
      letzteSeq = seq;
      if (neu) {
        this.#sendeAnPartner(op.von, { t: "ops", ops: [{ ...op, seq }], mehr: false });
        await this.#pushFuerOp({ ...op, seq }).catch(() => {});
      }
    }
    await this.#alarmAktualisieren();
    return Response.json({ seq: letzteSeq });
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
      return Response.json(ergebnis);
    }

    if (request.method === "GET" && teile[2] === "fehlend") {
      const url = new URL(request.url);
      const rolle = url.searchParams.get("rolle") ?? "original";
      return Response.json(medienFehlend(this.sql, id, rolle));
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

  // --- Alarme (Z-1.7) ---------------------------------------------------------

  async #alarmAktualisieren() {
    const jetzt = Date.now();
    const { naechste } = naechsterAlarm(this.#kontext(jetzt), jetzt);
    if (naechste) await this.ctx.storage.setAlarm(naechste);
    else await this.ctx.storage.deleteAlarm();
  }

  #kontext(jetztMs) {
    const heute = berlinDatum(jetztMs);
    return {
      treffen: offeneTreffen(this.sql, heute),
      angeheftet: offeneAngeheftet(this.sql),
      spielEinladungen: offeneSpielEinladungen(this.sql),
      streakLaeuftHeuteAb: streakLaeuftHeuteAb(this.sql, jetztMs),
      erinnerungenHeute: {
        frage: alarmErledigt(this.sql, "frageDesTages", heute),
        streak: alarmErledigt(this.sql, "streakWarnung", heute),
      },
    };
  }

  async alarm() {
    const jetzt = Date.now();
    const { faellig } = naechsterAlarm(this.#kontext(jetzt), jetzt);
    for (const ereignis of faellig) {
      await this.#verarbeiteAlarm(ereignis, jetzt).catch(() => {});
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
        await this.#pushBeide(ALARM_TEXT[ereignis.art]);
        break;
      }
      case "puenktlichKarte": {
        const schluessel = ereignis.datum;
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide({ stufe: "still" });
        break;
      }
      case "frageDesTages":
      case "streakWarnung": {
        const schluessel = berlinDatum(jetztMs);
        if (alarmErledigt(this.sql, ereignis.art, schluessel)) return;
        alarmAlsErledigtMarkieren(this.sql, ereignis.art, schluessel, jetztIso);
        await this.#pushBeide(ALARM_TEXT[ereignis.art]);
        break;
      }
      case "nachrichtLoesen": {
        const op = { id: `los-${ereignis.id}`, art: "nachricht.losgeloest", von: "ahmed", zeit: jetztIso, d: { id: ereignis.id } };
        const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
        if (neu) for (const person of PERSONEN) this.#sendeAnPartner(partnerVon(person), { t: "ops", ops: [{ ...op, seq }], mehr: false });
        break;
      }
      case "spielVerfallen": {
        const op = { id: `verfallen-${ereignis.id}`, art: "spiel.verfallen", von: "ahmed", zeit: jetztIso, d: { id: ereignis.id } };
        const { seq, neu } = opEinfuegenMitStatus(this.sql, op);
        if (neu) for (const person of PERSONEN) this.#sendeAnPartner(partnerVon(person), { t: "ops", ops: [{ ...op, seq }], mehr: false });
        break;
      }
    }
  }

  async #pushBeide(nachricht) {
    for (const person of PERSONEN) {
      if (this.#istVerbunden(person)) continue;
      const token = geraetToken(this.sql, person);
      if (!token) continue;
      const res = await push(this.env, token, nachricht).catch(() => null);
      if (res?.expired) geraetLoeschen(this.sql, person);
    }
  }
}
