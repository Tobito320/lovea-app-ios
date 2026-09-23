import { test } from "node:test";
import assert from "node:assert/strict";
import { fakeSql } from "./fake-sql.js";
import {
  initSchema,
  opEinfuegen,
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
  opEinfuegen(sql, op("n1", "nachricht.neu", "ahmed", {}, "2026-10-24T10:00:00.000Z"));
  opEinfuegen(sql, op("n2", "nachricht.neu", "annika", {}, "2026-10-24T11:00:00.000Z"));
  const jetzt = Date.parse("2026-10-25T10:00:00.000Z");
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), true);

  opEinfuegen(sql, op("n3", "nachricht.neu", "ahmed", {}, "2026-10-25T09:00:00.000Z"));
  opEinfuegen(sql, op("n4", "nachricht.neu", "annika", {}, "2026-10-25T09:30:00.000Z"));
  assert.equal(streakLaeuftHeuteAb(sql, jetzt), false);
});

test("alarmErledigt: Markierung ist idempotent und wird gefunden", () => {
  const sql = raum();
  assert.equal(alarmErledigt(sql, "frageDesTages", "2026-10-25"), false);
  alarmAlsErledigtMarkieren(sql, "frageDesTages", "2026-10-25", "2026-10-25T18:00:00.000Z");
  alarmAlsErledigtMarkieren(sql, "frageDesTages", "2026-10-25", "2026-10-25T18:00:00.000Z"); // doppelt, harmlos
  assert.equal(alarmErledigt(sql, "frageDesTages", "2026-10-25"), true);
  assert.equal(opsSeit(sql, 0).ops.length, 1);
});
