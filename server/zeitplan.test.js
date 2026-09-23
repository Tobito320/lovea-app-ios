import { test } from "node:test";
import assert from "node:assert/strict";
import {
  vorabendZeit, stundeVorherZeit, puenktlichZeit, naechsteTageszeit, naechsteFaelligeTageszeit, naechsterAlarm,
  challengeEndspurtWocheZeit, challengeEndeWocheZeit, challengeEndspurtMonatZeit, challengeEndeMonatZeit,
} from "./zeitplan.js";

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
    erinnerungenHeute: { frage: true },
  };
  const { faellig, naechste } = naechsterAlarm(kontext, jetzt);
  assert.ok(faellig.some((f) => f.art === "nachrichtLoesen" && f.id === "p1"));
  assert.ok(!faellig.some((f) => f.art === "frageDesTages"));
  assert.ok(naechste !== null && naechste > jetzt);
});

// `uhrzeit: ""` heißt "ohne Uhrzeit" (neuer Client): kein "In einer Stunde", Vorabend und Pünktlich bleiben.
test("naechsterAlarm: Treffen mit leerer Uhrzeit plant kein stundeVorher", () => {
  const kontext = { treffen: [{ datum: "2026-10-25", uhrzeit: "" }], erinnerungenHeute: {} };
  const { faellig } = naechsterAlarm(kontext, Date.parse("2026-10-26T12:00:00.000Z"));
  const arten = faellig.filter((f) => f.datum === "2026-10-25").map((f) => f.art).sort();
  assert.deepEqual(arten, ["puenktlichKarte", "vorabend"]);
});

// Regressionstest: naechsteTageszeit lieferte früher IMMER einen Zeitpunkt in
// der Zukunft, auch wenn das Ereignis heute noch nicht erledigt war -- die
// Frage des Tages (18 Uhr) ist dadurch nie ausgelöst worden, ein Alarm um
// 18:00 hat einfach auf "morgen 18:00" umgeplant. naechsteFaelligeTageszeit muss den heutigen, ggf. schon
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
  const kontext = { erinnerungenHeute: { frage: false } };
  const { faellig } = naechsterAlarm(kontext, nach18);
  assert.ok(faellig.some((f) => f.art === "frageDesTages"));
});

test("naechsterAlarm: bleibt nie ohne nächsten Wach-Zeitpunkt (frageDesTages ist immer ein Kandidat)", () => {
  // Alles für heute schon erledigt, nichts anderes ansteht -> trotzdem muss
  // ein "naechste" für morgen 18 Uhr geplant sein, sonst wacht der DO-Alarm
  // nie wieder von selbst auf.
  const heuteFrueh = Date.parse("2026-06-15T05:00:00.000Z"); // 07:00 Berlin
  const kontext = { erinnerungenHeute: { frage: true } };
  const { faellig, naechste } = naechsterAlarm(kontext, heuteFrueh);
  assert.equal(faellig.length, 0);
  assert.ok(naechste !== null);
});

test("naechsterAlarm: Pünktlich-Karte wird am Morgen nach einem (auch gestrigen) Treffen fällig", () => {
  const morgenDanach = Date.parse("2026-10-24T08:00:00.000Z"); // 25.10. ist ein Sonntag danach; hier: Treffen am Vortag
  const kontext = {
    treffen: [{ datum: "2026-10-23" }], // "gestern" relativ zu morgenDanach (24.10.)
    erinnerungenHeute: { frage: true },
  };
  const { faellig } = naechsterAlarm(kontext, morgenDanach);
  assert.ok(faellig.some((f) => f.art === "puenktlichKarte" && f.datum === "2026-10-23"));
});

// Z-22.3: Endspurt-Mitteilung am letzten Challenge-Tag (18 Uhr) + Mitteilung bei Challenge-Ende.

test("challengeEndspurtWocheZeit: Sonntag 25.10. selbst ist schon Winterzeit", () => {
  assert.equal(new Date(challengeEndspurtWocheZeit("2026-10-19")).toISOString(), "2026-10-25T17:00:00.000Z");
});

test("challengeEndspurtWocheZeit: Sommer-Sonntag ist noch Sommerzeit", () => {
  assert.equal(new Date(challengeEndspurtWocheZeit("2026-09-21")).toISOString(), "2026-09-27T16:00:00.000Z");
});

// Final-Review I-3: früher lieferte der Montag 19.10. selbst schon den 26.10. -- genau der Fehler,
// durch den "Ende" beim Wecken am Montag nie fällig war. Jetzt: Montag an oder nach heute.
test("challengeEndeWocheZeit: Montag an oder nach heute, 09:00 Berlin", () => {
  assert.equal(new Date(challengeEndeWocheZeit("2026-10-20")).toISOString(), "2026-10-26T08:00:00.000Z"); // Di -> Mo danach (CET)
  assert.equal(new Date(challengeEndeWocheZeit("2026-10-25")).toISOString(), "2026-10-26T08:00:00.000Z"); // So -> Mo danach
  assert.equal(new Date(challengeEndeWocheZeit("2026-10-26")).toISOString(), "2026-10-26T08:00:00.000Z"); // Mo -> derselbe Mo
  assert.equal(new Date(challengeEndeWocheZeit("2026-09-28")).toISOString(), "2026-09-28T07:00:00.000Z"); // Mo, noch CEST
});

test("challengeEndspurtMonatZeit: 31.10. 18 Uhr ist schon Winterzeit", () => {
  assert.equal(new Date(challengeEndspurtMonatZeit("2026-10-05")).toISOString(), "2026-10-31T17:00:00.000Z");
});

test("challengeEndeMonatZeit: der 1. an oder nach heute, 09:00 Berlin", () => {
  assert.equal(new Date(challengeEndeMonatZeit("2026-10-05")).toISOString(), "2026-11-01T08:00:00.000Z");
  assert.equal(new Date(challengeEndeMonatZeit("2026-11-01")).toISOString(), "2026-11-01T08:00:00.000Z");
  assert.equal(new Date(challengeEndeMonatZeit("2026-10-01")).toISOString(), "2026-10-01T07:00:00.000Z");
  assert.equal(new Date(challengeEndeMonatZeit("2026-12-15")).toISOString(), "2027-01-01T08:00:00.000Z");
});

test("naechsterAlarm: Challenge-Kandidaten laufen immer mit, auch ohne Op-Kontext", () => {
  const montagFrueh = Date.parse("2026-09-21T06:00:00.000Z"); // Mo 08:00 Berlin, vor dem 09-Uhr-"Ende" (I-3)
  const { faellig, naechste } = naechsterAlarm({ erinnerungenHeute: {} }, montagFrueh);
  assert.ok(!faellig.some((f) => f.art.startsWith("challenge")), "so früh in der Woche ist noch nichts fällig");
  assert.ok(naechste !== null);
});

test("naechsterAlarm: eine schon erledigte Challenge-Periode wird nicht nochmal fällig", () => {
  const sonntagAbend = Date.parse("2026-09-27T17:30:00.000Z"); // 19:30 Berlin, nach dem 18-Uhr-Endspurt
  const kontext = { erinnerungenHeute: {}, challengeErledigt: { endspurtWoche: true } };
  const { faellig } = naechsterAlarm(kontext, sonntagAbend);
  assert.ok(!faellig.some((f) => f.art === "challengeEndspurtWoche"));
});

// Final-Review I-3: die "Ende"-Mitteilungen müssen beim Wecken wirklich fällig sein -- gegen den echten
// naechsterAlarm geprüft, nicht nur die Zeitfunktion (daran ist der alte Test vorbeigegangen).
function faelligeArten(jetztIso, challengeErledigt = {}) {
  return naechsterAlarm({ erinnerungenHeute: {}, challengeErledigt }, Date.parse(jetztIso)).faellig.map((f) => f.art);
}

test("naechsterAlarm: challengeEndeWoche ist Montag 09:05 fällig (Sommerzeit)", () => {
  assert.ok(faelligeArten("2026-09-28T07:05:00.000Z").includes("challengeEndeWoche")); // Mo 28.09. 09:05 CEST
});

test("naechsterAlarm: challengeEndeWoche ist Montag 09:05 fällig, Woche mit Zeitumstellung", () => {
  assert.ok(faelligeArten("2026-10-26T08:05:00.000Z").includes("challengeEndeWoche")); // Mo 26.10. 09:05 CET
  assert.ok(faelligeArten("2026-10-26T22:59:00.000Z").includes("challengeEndeWoche"), "auch spät am Montag noch fällig");
});

test("naechsterAlarm: challengeEndeMonat ist am 1. um 09:05 fällig, vor und nach der Zeitumstellung", () => {
  assert.ok(faelligeArten("2026-10-01T07:05:00.000Z").includes("challengeEndeMonat")); // 01.10. 09:05 CEST
  assert.ok(faelligeArten("2026-11-01T08:05:00.000Z").includes("challengeEndeMonat")); // 01.11. 09:05 CET
});

test("naechsterAlarm: nach dem Feuern (erledigt) ist Ende erst nächsten Montag wieder dran", () => {
  const jetzt = Date.parse("2026-10-26T08:05:00.000Z");
  const arten = faelligeArten("2026-10-26T08:05:00.000Z", { endeWoche: true });
  assert.ok(!arten.includes("challengeEndeWoche"));
  const { naechste } = naechsterAlarm({ erinnerungenHeute: { frage: true }, challengeErledigt: { endeWoche: true } }, jetzt);
  assert.ok(naechste > jetzt);
});

test("naechsterAlarm: mitten in Woche und Monat ist nichts 'vorbei' (kein falscher Push beim Erststart)", () => {
  const arten = faelligeArten("2026-09-30T10:00:00.000Z"); // Mi 30.09. 12:00, nichts erledigt
  assert.ok(!arten.includes("challengeEndeWoche"));
  assert.ok(!arten.includes("challengeEndeMonat"));
});

// Z-31.4 und Controller-Entscheid: Zeitkapsel und Streak sind weg (Spec 2.10) -- auch ein alter
// Kontext plant weder den Kapsel-Alarm noch die 21-Uhr-Streak-Warnung.
test("naechsterAlarm: keine kapselOeffnet- und streakWarnung-Kandidaten mehr", () => {
  const kontext = { erinnerungenHeute: {}, streakLaeuftHeuteAb: true, kapseln: [{ id: "msg-1", oeffnetAm: "2026-09-01" }] };
  const { faellig } = naechsterAlarm(kontext, Date.parse("2026-09-23T19:30:00.000Z")); // 21:30 Berlin
  assert.ok(!faellig.some((f) => f.art === "kapselOeffnet" || f.art === "streakWarnung"));
});
