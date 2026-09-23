import { test } from "node:test";
import assert from "node:assert/strict";
import { vorabendZeit, stundeVorherZeit, puenktlichZeit, naechsteTageszeit, naechsteFaelligeTageszeit, naechsterAlarm } from "./zeitplan.js";

// Review-Fokus 4: Tageswechsel in Europe/Berlin über die Zeitumstellung
// 25.10.2026 (03:00 CEST -> 02:00 CET, Uhren eine Stunde zurück).

test("Vorabend 20 Uhr: Treffen am Tag der Umstellung selbst (Vortag noch Sommerzeit)", () => {
  // Vortag 24.10. 20:00 Berlin ist noch CEST (UTC+2) -> 18:00 UTC.
  assert.equal(new Date(vorabendZeit("2026-10-25")).toISOString(), "2026-10-24T18:00:00.000Z");
});

test("Vorabend 20 Uhr: Treffen am Tag nach der Umstellung (Vortag schon Winterzeit)", () => {
  // Vortag 25.10. 20:00 Berlin ist schon CET (UTC+1) -> 19:00 UTC.
  assert.equal(new Date(vorabendZeit("2026-10-26")).toISOString(), "2026-10-25T19:00:00.000Z");
});

test("1h vorher: Treffen-Uhrzeit nach der Umstellung rechnet mit Winterzeit", () => {
  // 14:00 Berlin am 25.10. ist bereits CET (UTC+1) -> 13:00 UTC, minus 1h -> 12:00 UTC.
  assert.equal(new Date(stundeVorherZeit("2026-10-25", "14:00")).toISOString(), "2026-10-25T12:00:00.000Z");
});

test("Pünktlich-Karte am Morgen danach liegt im neuen Kalendertag", () => {
  const ms = puenktlichZeit("2026-10-24");
  const berlin = new Intl.DateTimeFormat("de-DE", { timeZone: "Europe/Berlin", dateStyle: "short", timeStyle: "short" }).format(ms);
  assert.match(berlin, /^25\.10\.(20)?26, 09:00$/);
});

test("naechsteTageszeit: heute, falls noch nicht vorbei, sonst morgen", () => {
  const heute0930 = Date.parse("2026-06-15T07:00:00.000Z"); // 09:00 Berlin (Sommerzeit, UTC+2)
  const heute18 = naechsteTageszeit(heute0930, 18, 0);
  assert.equal(new Date(heute18).toISOString(), "2026-06-15T16:00:00.000Z");

  const nach18 = Date.parse("2026-06-15T17:00:00.000Z"); // 19:00 Berlin
  const morgen18 = naechsteTageszeit(nach18, 18, 0);
  assert.equal(new Date(morgen18).toISOString(), "2026-06-16T16:00:00.000Z");
});

test("naechsterAlarm: findet fällige und nächste Ereignisse, dedupliziert per erinnerungenHeute", () => {
  const jetzt = Date.parse("2026-10-25T10:00:00.000Z");
  const kontext = {
    treffen: [{ datum: "2026-10-25", uhrzeit: "14:00" }],
    angeheftet: [{ id: "p1", bis: "2026-10-25T09:00:00.000Z" }], // schon fällig
    spielEinladungen: [{ id: "s1", bis: "2026-10-25T11:00:00.000Z" }], // noch nicht
    streakLaeuftHeuteAb: true,
    erinnerungenHeute: { frage: true, streak: false },
  };
  const { faellig, naechste } = naechsterAlarm(kontext, jetzt);
  assert.ok(faellig.some((f) => f.art === "nachrichtLoesen" && f.id === "p1"));
  assert.ok(!faellig.some((f) => f.art === "frageDesTages"));
  assert.ok(naechste !== null && naechste > jetzt);
});

// Regressionstest: naechsteTageszeit lieferte früher IMMER einen Zeitpunkt in
// der Zukunft, auch wenn das Ereignis heute noch nicht erledigt war -- die
// Frage des Tages (18 Uhr) und die Streak-Warnung (21 Uhr) sind dadurch nie
// ausgelöst worden, ein Alarm um 18:00 hat einfach auf "morgen 18:00"
// umgeplant. naechsteFaelligeTageszeit muss den heutigen, ggf. schon
// vergangenen Zeitpunkt liefern, solange er nicht erledigt ist.
test("naechsteFaelligeTageszeit: heute (auch rückwirkend), solange nicht erledigt; sonst morgen", () => {
  const nach18 = Date.parse("2026-06-15T17:00:00.000Z"); // 19:00 Berlin, also nach 18:00
  const heuteNochOffen = naechsteFaelligeTageszeit(nach18, 18, 0, false);
  assert.equal(new Date(heuteNochOffen).toISOString(), "2026-06-15T16:00:00.000Z"); // 18:00 Berlin, heute, in der Vergangenheit
  assert.ok(heuteNochOffen <= nach18); // -> in naechsterAlarm().faellig

  const heuteErledigt = naechsteFaelligeTageszeit(nach18, 18, 0, true);
  assert.equal(new Date(heuteErledigt).toISOString(), "2026-06-16T16:00:00.000Z"); // morgen
});

test("naechsterAlarm: Frage des Tages wird fällig, wenn 18 Uhr vorbei und noch nicht erledigt", () => {
  const nach18 = Date.parse("2026-06-15T17:30:00.000Z"); // 19:30 Berlin
  const kontext = { erinnerungenHeute: { frage: false, streak: false }, streakLaeuftHeuteAb: false };
  const { faellig } = naechsterAlarm(kontext, nach18);
  assert.ok(faellig.some((f) => f.art === "frageDesTages"));
});

test("naechsterAlarm: bleibt nie ohne nächsten Wach-Zeitpunkt (frageDesTages ist immer ein Kandidat)", () => {
  // Alles für heute schon erledigt, nichts anderes ansteht -> trotzdem muss
  // ein "naechste" für morgen 18 Uhr geplant sein, sonst wacht der DO-Alarm
  // nie wieder von selbst auf.
  const heuteFrueh = Date.parse("2026-06-15T05:00:00.000Z"); // 07:00 Berlin
  const kontext = { erinnerungenHeute: { frage: true, streak: true }, streakLaeuftHeuteAb: false };
  const { faellig, naechste } = naechsterAlarm(kontext, heuteFrueh);
  assert.equal(faellig.length, 0);
  assert.ok(naechste !== null);
});

test("naechsterAlarm: Pünktlich-Karte wird am Morgen nach einem (auch gestrigen) Treffen fällig", () => {
  const morgenDanach = Date.parse("2026-10-24T08:00:00.000Z"); // 25.10. ist ein Sonntag danach; hier: Treffen am Vortag
  const kontext = {
    treffen: [{ datum: "2026-10-23" }], // "gestern" relativ zu morgenDanach (24.10.)
    erinnerungenHeute: { frage: true, streak: true },
    streakLaeuftHeuteAb: false,
  };
  const { faellig } = naechsterAlarm(kontext, morgenDanach);
  assert.ok(faellig.some((f) => f.art === "puenktlichKarte" && f.datum === "2026-10-23"));
});
