import { test } from "node:test";
import assert from "node:assert/strict";
import { fakeSql } from "./fake-sql.js";
import {
  initSchema,
  opEinfuegen,
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
  offeneTreffen,
  offeneAngeheftet,
  offeneSpielEinladungen,
  streakLaeuftHeuteAb,
  alarmErledigt,
  alarmAlsErledigtMarkieren,
  ortInfo,
  opGueltig,
  verbindungIstLebendig,
  PING_TIMEOUT_MS,
  offeneKapseln,
  gemeinsamPruefen,
  spotifyTokenLesen,
  spotifyTokenSchreiben,
  spotifyCacheLesen,
  spotifyCacheSchreiben,
} from "./raum-logic.js";

function raum() {
  const sql = fakeSql();
  initSchema(sql);
  return sql;
}

function op(id, art, von, d = {}, zeit = new Date().toISOString()) {
  return { id, art, von, zeit, d };
}

// Review-Fokus 1 / Z-1.3: dieselbe Operation kommt zweimal.
test("doppelte Op ergibt eine Zeile, gleiche seq", () => {
  const sql = raum();
  const a = op("op-1", "nachricht.neu", "ahmed", { text: "hi" });
  const seq1 = opEinfuegen(sql, a);
  const seq2 = opEinfuegen(sql, a);
  assert.equal(seq1, seq2);
  const { ops } = opsSeit(sql, 0);
  assert.equal(ops.length, 1);
});

// Review-Fokus 3 / Z-1.3: 1200 Ops ergeben drei Seiten zu 500.
test("1200 Ops werden in drei Seiten zu 500 nachgeliefert", () => {
  const sql = raum();
  for (let i = 0; i < 1200; i++) {
    opEinfuegen(sql, op(`id-${i}`, "nachricht.neu", "ahmed", { i }));
  }
  const seite1 = opsSeit(sql, 0);
  assert.equal(seite1.ops.length, 500);
  assert.equal(seite1.mehr, true);

  const seite2 = opsSeit(sql, seite1.ops.at(-1).seq);
  assert.equal(seite2.ops.length, 500);
  assert.equal(seite2.mehr, true);

  const seite3 = opsSeit(sql, seite2.ops.at(-1).seq);
  assert.equal(seite3.ops.length, 200);
  assert.equal(seite3.mehr, false);
});

// C-1: 600 Ops zu je 5 KB passen nicht in einen Frame. Die Seite bleibt unter
// 512 KB, und alle Seiten zusammen liefern jede Op genau einmal.
test("Seiten sind nach Größe begrenzt, Nachholen liefert jede Op genau einmal", () => {
  const sql = raum();
  const punkte = "x".repeat(5 * 1024);
  for (let i = 0; i < 600; i++) opEinfuegen(sql, op(`s-${i}`, "zeichnung.op", "annika", { punkte }));

  const erste = opsSeit(sql, 0);
  assert.equal(erste.mehr, true);
  assert.ok(erste.ops.length > 0 && erste.ops.length < 500);
  assert.ok(JSON.stringify({ t: "ops", ...erste, seite: true }).length < 512 * 1024);

  const gesehen = [];
  let seit = 0;
  for (;;) {
    const seite = opsSeit(sql, seit);
    gesehen.push(...seite.ops.map((o) => o.id));
    seit = seite.ops.at(-1).seq;
    if (!seite.mehr) break;
  }
  assert.equal(gesehen.length, 600);
  assert.equal(new Set(gesehen).size, 600);
});

test("Eine Op über 512 KB kommt allein, und das Nachholen geht weiter", () => {
  const sql = raum();
  opEinfuegen(sql, op("gross", "zeichnung.op", "annika", { punkte: "x".repeat(600 * 1024) }));
  opEinfuegen(sql, op("klein", "nachricht.neu", "annika", { text: "hi" }));

  const erste = opsSeit(sql, 0);
  assert.deepEqual(erste.ops.map((o) => o.id), ["gross"]);
  assert.equal(erste.mehr, true);
  const zweite = opsSeit(sql, erste.ops[0].seq);
  assert.deepEqual(zweite.ops.map((o) => o.id), ["klein"]);
  assert.equal(zweite.mehr, false);
});

// I-5: Stand-Medien werden aufgeräumt, aber nur, was niemand mehr braucht.
test("Neuer Stand löscht nur die verwaisten Medien des vorigen Stands", () => {
  const sql = raum();
  const medium = (id) => {
    medienTeilSpeichern(sql, id, "original", 0, new Uint8Array([1]));
    medienFertig(sql, id, "original", { teile: 1, typ: "image/png", bytes: 1, von: "ahmed" });
  };
  for (const id of ["doc1", "vor1", "ebeneA1", "ebeneB", "doc2", "vor2", "ebeneA2", "fremdDoc", "opMedium", "doc3", "vor3", "ebeneA3"]) medium(id);

  const stand = (id, zeichnungId, basis, medienId, vorschau, ebenen) =>
    op(id, "zeichnung.stand", "ahmed", { zeichnungId, medienId, basis, vorschau, ebenen: ebenen.map((m, i) => ({ ebene: `e${i}`, medienId: m })) });

  opEinfuegenMitStatus(sql, stand("st1", "z1", 0, "doc1", "vor1", ["ebeneA1", "ebeneB"]));
  // Eine andere Zeichnung nutzt denselben Inhalt wie Ebene A von z1 (Hash-Cache des Handys).
  opEinfuegenMitStatus(sql, stand("fr1", "z2", 0, "fremdDoc", undefined, ["ebeneA1"]));
  const st2 = opEinfuegenMitStatus(sql, stand("st2", "z1", 2, "doc2", "vor2", ["ebeneA2", "ebeneB"]));
  // doc1 und vor1 sind verwaist, ebeneB nutzt der neue Stand, ebeneA1 die andere Zeichnung.
  assert.equal(medienLesen(sql, "doc1"), null);
  assert.equal(medienLesen(sql, "vor1"), null);
  assert.notEqual(medienLesen(sql, "ebeneB"), null);
  assert.notEqual(medienLesen(sql, "ebeneA1"), null);

  // Eine zeichnung.op nach der basis des neuen Stands nennt ein altes Medium: bleibt.
  opEinfuegen(sql, op("zo", "zeichnung.op", "ahmed", { id: "x", zeichnungId: "z1", basis: st2.seq, aktion: { ebenen: { neu: [{ medienId: "ebeneA2" }] } } }));
  opEinfuegenMitStatus(sql, stand("st3", "z1", st2.seq, "doc3", "vor3", ["ebeneA3", "ebeneB"]));
  assert.notEqual(medienLesen(sql, "ebeneA2"), null);
  assert.equal(medienLesen(sql, "doc2"), null);
  assert.notEqual(medienLesen(sql, "fremdDoc"), null);
  // Doppelte Zustellung desselben Stands räumt nichts weiter weg.
  opEinfuegenMitStatus(sql, stand("st3", "z1", st2.seq, "doc3", "vor3", ["ebeneA3", "ebeneB"]));
  assert.notEqual(medienLesen(sql, "doc3"), null);
});

test("Einstellung: neuester Wert gewinnt", () => {
  const sql = raum();
  opEinfuegen(sql, op("s1", "einstellung.setzen", "annika", { schluessel: "mitteilungen.chat", wert: true }));
  opEinfuegen(sql, op("s2", "einstellung.setzen", "annika", { schluessel: "mitteilungen.chat", wert: false }));
  assert.equal(einstellung(sql, "annika", "mitteilungen.chat"), false);
  assert.equal(einstellung(sql, "annika", "mitteilungen.unbekannt"), undefined);
});

// Review-Fokus 5 / Z-1.4: Medien-Upload bricht mittendrin ab.
test("Medium mit fehlendem Teil ist nicht abrufbar, nach Nachreichen schon", () => {
  const sql = raum();
  medienTeilSpeichern(sql, "m1", "original", 0, new Uint8Array([1, 2]));
  medienTeilSpeichern(sql, "m1", "original", 2, new Uint8Array([5, 6]));

  const versuch1 = medienFertig(sql, "m1", "original", { teile: 3, typ: "image/jpeg", bytes: 6, von: "ahmed" });
  assert.equal(versuch1.fertig, false);
  assert.deepEqual(versuch1.fehlend, [1]);
  assert.equal(medienLesen(sql, "m1", "annika"), null);

  const luecken = medienFehlend(sql, "m1", "original");
  assert.deepEqual(luecken.fehlend, [1]);

  medienTeilSpeichern(sql, "m1", "original", 1, new Uint8Array([3, 4]));
  const versuch2 = medienFertig(sql, "m1", "original", { teile: 3, typ: "image/jpeg", bytes: 6, von: "ahmed" });
  assert.equal(versuch2.fertig, true);

  const gelesen = medienLesen(sql, "m1", "annika");
  assert.equal(gelesen.rolle, "original");
  assert.deepEqual([...gelesen.daten], [1, 2, 3, 4, 5, 6]);
});

// C-1: `vorhanden` muss für eine unbekannte id verlässlich [] sein, damit der
// Client seinen Upload-Plan daraus bauen kann, statt `fehlend` (ohne `gesamt`
// nur die Lücken unterhalb des höchsten Teils, für eine neue id also auch [])
// fälschlich als "nichts fehlt" zu lesen.
test("medienFehlend: unbekannte id liefert vorhanden:[] (C-1)", () => {
  const sql = raum();
  assert.deepEqual(medienFehlend(sql, "unbekannt", "original"), { vorhanden: [], fehlend: [] });
});

test("medienFehlend: mit ?teile=N ist fehlend die volle Komplementmenge 0..N-1, nicht nur Lücken unterhalb des Maximums", () => {
  const sql = raum();
  medienTeilSpeichern(sql, "m2", "original", 0, new Uint8Array([1]));
  medienTeilSpeichern(sql, "m2", "original", 2, new Uint8Array([1]));
  // Ohne gesamt: nur die Lücke unterhalb von max(vorhanden)=2.
  assert.deepEqual(medienFehlend(sql, "m2", "original"), { vorhanden: [0, 2], fehlend: [1] });
  // Mit gesamt=5: auch 3 und 4 fehlen, die vorher unsichtbar waren.
  assert.deepEqual(medienFehlend(sql, "m2", "original", 5), { vorhanden: [0, 2], fehlend: [1, 3, 4], gesamt: 5 });
});

// I-3/M-3/M-4: reine Formprüfung.
test("opGueltig: prüft id/art/von/zeit/d-Form und optional den Absender", () => {
  const gueltig = { id: "x", art: "nachricht.neu", von: "ahmed", zeit: "2026-01-01T00:00:00.000Z", d: {} };
  assert.equal(opGueltig(gueltig), true);
  assert.equal(opGueltig(gueltig, "ahmed"), true);
  assert.equal(opGueltig(gueltig, "annika"), false); // von passt nicht zum Socket-Tag (M-3)

  assert.equal(opGueltig(null), false);
  assert.equal(opGueltig({ ...gueltig, id: "" }), false);
  assert.equal(opGueltig({ ...gueltig, id: undefined }), false); // M-4: keine id -> nie .one() erreichen
  assert.equal(opGueltig({ ...gueltig, art: 5 }), false);
  assert.equal(opGueltig({ ...gueltig, von: "niemand" }), false);
  assert.equal(opGueltig({ ...gueltig, zeit: "" }), false);
  assert.equal(opGueltig({ ...gueltig, d: null }), false);
  assert.equal(opGueltig({ ...gueltig, d: [] }), false);
  assert.equal(opGueltig({ ...gueltig, d: "text" }), false);
});

// I-5: reine Zeitvergleichs-Logik hinter der Ping-Erkennung.
test("verbindungIstLebendig: null/undefined gilt als frisch verbunden, sonst 60s-Fenster", () => {
  assert.equal(verbindungIstLebendig(null, 1_000_000), true);
  assert.equal(verbindungIstLebendig(undefined, 1_000_000), true);
  assert.equal(verbindungIstLebendig(1_000_000 - PING_TIMEOUT_MS + 1, 1_000_000), true);
  assert.equal(verbindungIstLebendig(1_000_000 - PING_TIMEOUT_MS, 1_000_000), false);
  assert.equal(verbindungIstLebendig(1_000_000 - PING_TIMEOUT_MS - 1, 1_000_000), false);
});

test("Original wird gelöscht, sobald der Partner es geholt hat und klein existiert", () => {
  const sql = raum();
  medienTeilSpeichern(sql, "m2", "original", 0, new Uint8Array([9]));
  medienFertig(sql, "m2", "original", { teile: 1, typ: "image/jpeg", bytes: 1, von: "ahmed" });
  medienTeilSpeichern(sql, "m2", "klein", 0, new Uint8Array([1]));
  medienFertig(sql, "m2", "klein", { teile: 1, typ: "image/jpeg", bytes: 1, von: "ahmed" });

  // Ahmed (der Uploader) holt weiterhin das Original.
  let g = medienLesen(sql, "m2", "ahmed");
  assert.equal(g.rolle, "original");

  // Annika (der Partner) holt es -> Original wird danach entfernt.
  g = medienLesen(sql, "m2", "annika");
  assert.equal(g.rolle, "original");
  g = medienLesen(sql, "m2", "annika");
  assert.equal(g.rolle, "klein");
});

test("Standort wird höchstens einmal pro Minute geschrieben", () => {
  const sql = raum();
  const t0 = Date.parse("2026-09-23T10:00:00.000Z");
  assert.equal(standortSchreiben(sql, "ahmed", { lat: 1, lon: 1 }, new Date(t0).toISOString(), t0), true);
  assert.equal(standortSchreiben(sql, "ahmed", { lat: 1.001, lon: 1 }, new Date(t0 + 10_000).toISOString(), t0 + 10_000), false);
  assert.equal(letzterStandort(sql, "ahmed").d.lat, 1);
  const t1 = t0 + 61_000;
  assert.equal(standortSchreiben(sql, "ahmed", { lat: 2, lon: 2 }, new Date(t1).toISOString(), t1), true);
  assert.equal(letzterStandort(sql, "ahmed").d.lat, 2);
});

test("Zufällig nah: beide frisch, unter 100 m, kein Treffen", () => {
  const jetzt = Date.parse("2026-09-23T10:00:00.000Z");
  const a = { d: { lat: 51.0, lon: 7.0 }, zeit: new Date(jetzt).toISOString() };
  const b = { d: { lat: 51.0005, lon: 7.0 }, zeit: new Date(jetzt).toISOString() }; // ~56 m
  assert.equal(zufaelligNah({ a, b, jetztMs: jetzt, heuteTreffen: false }), true);
  assert.equal(zufaelligNah({ a, b, jetztMs: jetzt, heuteTreffen: true }), false);

  const weitWeg = { d: { lat: 51.01, lon: 7.0 }, zeit: new Date(jetzt).toISOString() };
  assert.equal(zufaelligNah({ a, b: weitWeg, jetztMs: jetzt, heuteTreffen: false }), false);

  const alt = { d: { lat: 51.0005, lon: 7.0 }, zeit: new Date(jetzt - 11 * 60_000).toISOString() };
  assert.equal(zufaelligNah({ a, b: alt, jetztMs: jetzt, heuteTreffen: false }), false);
});

// Z-27.4: "Unsere Orte" -- kein Melden vor 30 min, danach jeden weiteren Aufruf, bis sie sich
// trennen oder ein Punkt zu alt wird.
test("gemeinsamPruefen: meldet erst nach 30 Minuten am Stück, nicht sofort", () => {
  const start = Date.parse("2026-09-23T10:00:00.000Z");
  const a = { d: { lat: 51.0, lon: 7.0 }, zeit: new Date(start).toISOString() };
  const b = { d: { lat: 51.0005, lon: 7.0 }, zeit: new Date(start).toISOString() }; // ~56 m
  const erster = gemeinsamPruefen({ a, b, jetztMs: start, seitMs: null });
  assert.equal(erster.nah, true);
  assert.equal(erster.melden, false);
  assert.equal(erster.seit, start);

  const nach29Min = start + 29 * 60_000;
  const noch = gemeinsamPruefen({
    a: { ...a, zeit: new Date(nach29Min).toISOString() },
    b: { ...b, zeit: new Date(nach29Min).toISOString() },
    jetztMs: nach29Min,
    seitMs: erster.seit,
  });
  assert.equal(noch.melden, false);

  const nach31Min = start + 31 * 60_000;
  const jetzt = gemeinsamPruefen({
    a: { ...a, zeit: new Date(nach31Min).toISOString() },
    b: { ...b, zeit: new Date(nach31Min).toISOString() },
    jetztMs: nach31Min,
    seitMs: erster.seit,
  });
  assert.equal(jetzt.melden, true);
  assert.equal(jetzt.seit, start); // derselbe Beginn wie beim ersten Aufruf, nicht neu gestartet
});

test("gemeinsamPruefen: außerhalb 150 m oder mit einem zu alten Punkt setzt zurück", () => {
  const jetzt = Date.parse("2026-09-23T10:00:00.000Z");
  const a = { d: { lat: 51.0, lon: 7.0 }, zeit: new Date(jetzt).toISOString() };
  const weitWeg = { d: { lat: 51.01, lon: 7.0 }, zeit: new Date(jetzt).toISOString() }; // >150 m
  assert.deepEqual(gemeinsamPruefen({ a, b: weitWeg, jetztMs: jetzt, seitMs: jetzt - 40 * 60_000 }), { nah: false, seit: null, melden: false });

  const alt = { d: { lat: 51.0005, lon: 7.0 }, zeit: new Date(jetzt - 46 * 60_000).toISOString() };
  assert.deepEqual(gemeinsamPruefen({ a, b: alt, jetztMs: jetzt, seitMs: jetzt - 40 * 60_000 }), { nah: false, seit: null, melden: false });
});

test("offeneKapseln: nur nachricht.neu mit d.kapsel.oeffnetAm, Nachrichten-id nicht Op-id", () => {
  const sql = raum();
  opEinfuegen(sql, op("op-1", "nachricht.neu", "ahmed", { id: "msg-1", text: "hi" })); // keine Kapsel
  opEinfuegen(sql, op("op-2", "nachricht.neu", "annika", { id: "msg-2", text: "geheim", kapsel: { oeffnetAm: "2026-12-24" } }));
  const kapseln = offeneKapseln(sql);
  assert.deepEqual(kapseln, [{ id: "msg-2", oeffnetAm: "2026-12-24" }]);
});

test("Spotify: Token und Cache im Merker, roundtrip", () => {
  const sql = raum();
  assert.equal(spotifyTokenLesen(sql, "ahmed"), null);
  spotifyTokenSchreiben(sql, "ahmed", { accessToken: "a", refreshToken: "r", ablaeuftMs: 123 });
  assert.deepEqual(spotifyTokenLesen(sql, "ahmed"), { accessToken: "a", refreshToken: "r", ablaeuftMs: 123 });

  assert.equal(spotifyCacheLesen(sql, "ahmed"), null);
  spotifyCacheSchreiben(sql, "ahmed", { geladenMs: 1, daten: { titel: "Song" } });
  assert.deepEqual(spotifyCacheLesen(sql, "ahmed"), { geladenMs: 1, daten: { titel: "Song" } });
});

test("offeneTreffen: neueste Fassung gewinnt, gelöschte und vergangene fallen raus", () => {
  const sql = raum();
  opEinfuegen(sql, op("t1", "treffen.setzen", "ahmed", { datum: "2026-10-25", uhrzeit: "14:00" }));
  opEinfuegen(sql, op("t1b", "treffen.setzen", "ahmed", { datum: "2026-10-25", uhrzeit: "15:00" }));
  opEinfuegen(sql, op("t2", "treffen.setzen", "annika", { datum: "2026-09-01" })); // vergangen
  opEinfuegen(sql, op("t3", "treffen.setzen", "annika", { datum: "2026-11-01" }));
  opEinfuegen(sql, op("t3del", "treffen.loeschen", "annika", { datum: "2026-11-01" }));

  const ergebnis = offeneTreffen(sql, "2026-10-01");
  assert.deepEqual(ergebnis, [{ datum: "2026-10-25", uhrzeit: "15:00" }]);
});

test("offeneTreffen: ein Cutoff auf 'gestern' liefert das gestrige Treffen noch (für die Pünktlich-Karte am Morgen danach)", () => {
  const sql = raum();
  opEinfuegen(sql, op("t1", "treffen.setzen", "ahmed", { datum: "2026-10-23" }));
  // "heute" = 2026-10-24 -> Treffen gestern ist raus, wenn man ab "heute" filtert...
  assert.deepEqual(offeneTreffen(sql, "2026-10-24"), []);
  // ...aber noch drin, wenn man ab "gestern" filtert.
  assert.deepEqual(offeneTreffen(sql, "2026-10-23"), [{ datum: "2026-10-23", uhrzeit: undefined }]);
});

test("ortInfo: neueste Fassung eines Orts, oder null", () => {
  const sql = raum();
  assert.equal(ortInfo(sql, "o1"), null);
  opEinfuegen(sql, op("s1", "ort.setzen", "ahmed", { id: "o1", name: "Zuhause", kategorie: "zuhause", melden: "beides" }));
  opEinfuegen(sql, op("s2", "ort.setzen", "ahmed", { id: "o1", name: "Zuhause", kategorie: "zuhause", melden: "nichts" }));
  assert.equal(ortInfo(sql, "o1").melden, "nichts");
});

test("offeneAngeheftet: gelöste Nachrichten fallen raus", () => {
  const sql = raum();
  opEinfuegen(sql, op("p1", "nachricht.angeheftet", "ahmed", { id: "m1", bis: "2026-10-01T00:00:00.000Z" }));
  opEinfuegen(sql, op("p2", "nachricht.angeheftet", "annika", { id: "m2", bis: "2026-10-02T00:00:00.000Z" }));
  opEinfuegen(sql, op("p2los", "nachricht.losgeloest", "annika", { id: "m2" }));

  const ergebnis = offeneAngeheftet(sql);
  assert.deepEqual(ergebnis, [{ id: "m1", bis: "2026-10-01T00:00:00.000Z", von: "ahmed" }]);
});

test("offeneSpielEinladungen: angenommene und verfallene fallen raus", () => {
  const sql = raum();
  opEinfuegen(sql, op("e1", "spiel.einladung", "ahmed", { id: "s1", bis: "2026-10-01T00:00:00.000Z" }));
  opEinfuegen(sql, op("e2", "spiel.einladung", "ahmed", { id: "s2", bis: "2026-10-01T00:00:00.000Z" }));
  opEinfuegen(sql, op("a2", "spiel.angenommen", "annika", { id: "s2" }));

  const ergebnis = offeneSpielEinladungen(sql);
  assert.deepEqual(ergebnis, [{ id: "s1", bis: "2026-10-01T00:00:00.000Z", von: "ahmed" }]);
});

test("streakLaeuftHeuteAb: gestern beide aktiv, heute noch keiner -> true", () => {
  const sql = raum();
  const snap = { snap: { bleibt: false } };
  opEinfuegen(sql, op("n1", "nachricht.neu", "ahmed", snap, "2026-10-24T10:00:00.000Z"));
  opEinfuegen(sql, op("n2", "nachricht.neu", "annika", snap, "2026-10-24T11:00:00.000Z"));
  const jetzt = Date.parse("2026-10-25T10:00:00.000Z");
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), true);

  opEinfuegen(sql, op("n3", "nachricht.neu", "ahmed", snap, "2026-10-25T09:00:00.000Z"));
  opEinfuegen(sql, op("n4", "nachricht.neu", "annika", snap, "2026-10-25T09:30:00.000Z"));
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), false);
});

// I-3: Die App zählt nur Snaps (Streak.swift), die Push-Warnung also auch.
test("streakLaeuftHeuteAb: normale Chat-Nachrichten zählen nicht, nur Snaps", () => {
  const sql = raum();
  opEinfuegen(sql, op("t1", "nachricht.neu", "ahmed", { text: "hi" }, "2026-10-24T10:00:00.000Z"));
  opEinfuegen(sql, op("t2", "nachricht.neu", "annika", { text: "hey" }, "2026-10-24T11:00:00.000Z"));
  const jetzt = Date.parse("2026-10-25T10:00:00.000Z");
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), false);

  opEinfuegen(sql, op("s1", "nachricht.neu", "ahmed", { snap: { bleibt: false } }, "2026-10-24T12:00:00.000Z"));
  opEinfuegen(sql, op("s2", "nachricht.neu", "annika", { snap: { bleibt: true } }, "2026-10-24T13:00:00.000Z"));
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), true);
  // Heute nur Text: der Snap-Streak läuft weiter ab.
  opEinfuegen(sql, op("t3", "nachricht.neu", "ahmed", { text: "morgen" }, "2026-10-25T08:00:00.000Z"));
  opEinfuegen(sql, op("t4", "nachricht.neu", "annika", { text: "morgen" }, "2026-10-25T08:30:00.000Z"));
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), true);
});

test("streakLaeuftHeuteAb: Systemnachrichten (z. B. Zufällig nah) zählen nicht als Aktivität", () => {
  const sql = raum();
  opEinfuegen(sql, op("s1", "nachricht.neu", "ahmed", { system: "nah" }, "2026-10-24T10:00:00.000Z"));
  opEinfuegen(sql, op("s2", "nachricht.neu", "annika", { system: "nah" }, "2026-10-24T11:00:00.000Z"));
  const jetzt = Date.parse("2026-10-25T10:00:00.000Z");
  // Beide "aktiv" gestern, aber nur über Systemnachrichten -> kein echter Streak-Tag.
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), false);
});

test("alarmErledigt: Markierung ist idempotent, wird gefunden, landet nicht in den Ops", () => {
  const sql = raum();
  assert.equal(alarmErledigt(sql, "frageDesTages", "2026-10-25"), false);
  alarmAlsErledigtMarkieren(sql, "frageDesTages", "2026-10-25", "2026-10-25T18:00:00.000Z");
  alarmAlsErledigtMarkieren(sql, "frageDesTages", "2026-10-25", "2026-10-25T18:00:00.000Z"); // doppelt, harmlos
  assert.equal(alarmErledigt(sql, "frageDesTages", "2026-10-25"), true);
  // Server-Buchhaltung, kein Chat-Ereignis: darf dem Client nicht als Op ankommen.
  assert.equal(opsSeit(sql, 0).ops.length, 0);
});
