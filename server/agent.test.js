import { test } from "node:test";
import assert from "node:assert/strict";
import { fakeSql } from "./fake-sql.js";
import { initSchema, opEinfuegenMitStatus, merkerSchreiben } from "./raum-logic.js";
import { agentStatistik, agentOps, agentMerker } from "./agent.js";

function raumMit(ops) {
  const sql = fakeSql();
  initSchema(sql);
  for (const [i, op] of ops.entries()) opEinfuegenMitStatus(sql, { id: `op${i}`, zeit: `2026-10-0${i + 1}T10:00:00Z`, ...op });
  return sql;
}

test("Statistik zählt Ops je Art und Person, ohne Inhalte", () => {
  const sql = raumMit([
    { art: "nachricht.neu", von: "ahmed", d: { text: "hallo" } },
    { art: "nachricht.neu", von: "annika", d: { text: "hi" } },
    { art: "gym.satz", von: "ahmed", d: { kg: 50 } },
  ]);
  const s = agentStatistik(sql);
  assert.equal(s.ops.anzahl, 3);
  assert.equal(s.ops.letzteSeq, 3);
  assert.deepEqual(s.ops.jePerson, { ahmed: 2, annika: 1 });
  const nachricht = s.ops.jeArt.find((a) => a.art === "nachricht.neu");
  assert.equal(nachricht.anzahl, 2);
  assert.equal(nachricht.letzte, "2026-10-02T10:00:00Z");
  assert.ok(nachricht.bytes > 0);
  assert.ok(!JSON.stringify(s).includes("hallo"));
});

test("Statistik zeigt Medien, Geräte und Merker nur als Kennzahlen", () => {
  const sql = raumMit([]);
  sql.exec(`INSERT INTO medien_info (id, rolle, typ, teile, bytes, von, fertig) VALUES ('m1', 'original', 'image/jpeg', 1, 4, 'ahmed', 1)`);
  sql.exec(`INSERT INTO medien_info (id, rolle, typ, teile, bytes, von, fertig) VALUES ('m2', 'original', 'video/mp4', 2, 9, 'annika', 0)`);
  sql.exec(`INSERT INTO medien (id, rolle, teil, daten) VALUES ('m1', 'original', 0, x'01020304')`);
  sql.exec(`INSERT INTO geraete (person, token) VALUES ('ahmed', 'geheim-token')`);
  merkerSchreiben(sql, "spotify.token.ahmed", JSON.stringify({ accessToken: "geheim" }));
  const s = agentStatistik(sql);
  assert.equal(s.medien.eintraege, 2);
  assert.equal(s.medien.unfertig, 1);
  assert.equal(s.medien.gespeichertBytes, 4);
  assert.deepEqual(s.geraete, { ahmed: true, annika: false });
  assert.deepEqual(s.merker, ["spotify.token.ahmed"]);
  assert.ok(!JSON.stringify(s).includes("geheim"));
});

test("Ops filtert nach Art-Präfix, Person, Text und liefert neueste zuerst", () => {
  const sql = raumMit([
    { art: "gym.satz", von: "ahmed", d: { kg: 50 } },
    { art: "gym.checkout", von: "ahmed", d: { status: "ende" } },
    { art: "nachricht.neu", von: "annika", d: { text: "Pizza heute?" } },
    { art: "gym.satz", von: "annika", d: { kg: 20 } },
  ]);
  assert.deepEqual(agentOps(sql, { art: "gym." }, "ahmed").ops.map((o) => o.seq), [4, 2, 1]);
  assert.deepEqual(agentOps(sql, { art: "gym.", von: "ahmed", limit: 1 }, "ahmed").ops.map((o) => o.seq), [2]);
  assert.equal(agentOps(sql, { art: "gym.", von: "ahmed", limit: 1 }, "ahmed").mehr, true);
  assert.deepEqual(agentOps(sql, { suche: "pizza" }, "ahmed").ops.map((o) => o.seq), [3]);
  assert.deepEqual(agentOps(sql, { seit: 2, aufsteigend: true }, "ahmed").ops.map((o) => o.seq), [3, 4]);
  assert.deepEqual(agentOps(sql, { ab: "2026-10-02", bis: "2026-10-03T23:59:59Z" }, "ahmed").ops.map((o) => o.seq), [3, 2]);
});

test("Ops kürzt große Inhalte, außer voll ist gesetzt", () => {
  const sql = raumMit([{ art: "zeichnung.strich", von: "ahmed", d: { punkte: "x".repeat(5000) } }]);
  const kurz = agentOps(sql, {}, "ahmed").ops[0];
  assert.equal(kurz.d._gekuerzt, true);
  assert.ok(kurz.d.bytes > 5000);
  assert.ok(kurz.d.anfang.length <= 300);
  assert.equal(agentOps(sql, { voll: true }, "ahmed").ops[0].d.punkte.length, 5000);
});

test("Ops zeigt private Arten der anderen Person nicht", () => {
  const sql = raumMit([
    { art: "entwurf.setzen", von: "annika", d: { geheim: 1 } },
    { art: "galerie.neu", von: "annika", d: {} },
    { art: "entwurf.setzen", von: "ahmed", d: {} },
    { art: "geschenkbox.setzen", von: "annika", d: { text: "Ring" } },
  ]);
  assert.deepEqual(agentOps(sql, {}, "ahmed").ops.map((o) => o.seq), [3]);
});

test("Coach: coach.nachricht der anderen Person bleibt unsichtbar -- Ops, Statistik und Merker", () => {
  const sql = raumMit([
    { art: "coach.nachricht", von: "annika", d: { rolle: "du", text: "GEHEIM-COACH", tag: "2026-10-08" } },
    { art: "coach.nachricht", von: "ahmed", d: { rolle: "du", text: "meine Frage", tag: "2026-10-08" } },
    { art: "nachricht.neu", von: "annika", d: { text: "offen" } },
  ]);
  assert.deepEqual(agentOps(sql, {}, "ahmed").ops.map((o) => o.seq), [3, 2]);
  assert.deepEqual(agentOps(sql, { art: "coach.", von: "annika" }, "ahmed").ops, []);
  assert.deepEqual(agentOps(sql, { suche: "GEHEIM-COACH" }, "ahmed").ops, []);
  assert.deepEqual(agentOps(sql, { art: "coach." }, "annika").ops.map((o) => o.seq), [1]);
  merkerSchreiben(sql, "coach.nutzung.annika.2026-10-08", "3");
  merkerSchreiben(sql, "alarm.coachMorgen.annika.2026-10-08", "2026-10-08T06:00:00Z");
  merkerSchreiben(sql, "alarm.vorabend", "2026-10-07");
  const s = agentStatistik(sql);
  assert.ok(!s.ops.jeArt.some((r) => r.art.startsWith("coach.")), "keine Coach-Zeile in der Statistik");
  assert.deepEqual(s.merker, ["alarm.vorabend"]);
  assert.deepEqual(agentMerker(sql, "coach.nutzung.annika.2026-10-08"), { fehler: "gesperrt" });
  assert.deepEqual(agentMerker(sql, "alarm.coachMorgen.annika.2026-10-08"), { fehler: "gesperrt" });
  assert.equal(agentMerker(sql, "alarm.vorabend").wert, "2026-10-07");
});

test("Limit wird auf 1 bis 200 geklemmt", () => {
  const sql = raumMit(Array.from({ length: 3 }, () => ({ art: "a", von: "ahmed", d: {} })));
  assert.equal(agentOps(sql, { limit: 0 }, "ahmed").ops.length, 1);
  assert.equal(agentOps(sql, { limit: 9999 }, "ahmed").ops.length, 3);
});

test("Merker liest Werte, Spotify-Token nie", () => {
  const sql = raumMit([]);
  merkerSchreiben(sql, "alarm.vorabend", "2026-10-07");
  merkerSchreiben(sql, "spotify.token.annika", "geheim");
  assert.deepEqual(agentMerker(sql, "alarm.vorabend"), { schluessel: "alarm.vorabend", wert: "2026-10-07" });
  assert.deepEqual(agentMerker(sql, "spotify.token.annika"), { fehler: "gesperrt" });
  assert.deepEqual(agentMerker(sql, "gibtsnicht"), { schluessel: "gibtsnicht", wert: null });
});
