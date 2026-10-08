import { test } from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import * as gym from "./gym.js";

const kat = gym.katalogLaden(join(import.meta.dirname, "..", "Lovea", "Sources", "Health"));
const swift = (iso) => Date.parse(iso) / 1000 - 978307200;
let n = 0;
const op = (art, zeit, d, von = "ahmed") => ({ seq: ++n, id: `op${n}`, art, von, zeit, d });
const satz = (wdh, kg, extra = {}) => ({ wdh, kg, failure: false, ok: true, ...extra });

// Latzug (Latissimus, neben Bizeps), Hammer-Curls (Bizeps, neben Unterarme) aus dem echten Katalog.
const LATZUG = "qdRxqCj";
const HAMMER = "slDvUAU";

function einheit(id, tagIso, uebungen, { tag = "T1", minuten = 60 } = {}) {
  const start = `${tagIso}T16:00:00.000Z`;
  const ops = [op("gym.checkin", start, { session: id, tag, start: swift(start) })];
  uebungen.forEach(([uebung, saetze], i) => {
    ops.push(op("gym.uebung", `${tagIso}T16:${10 + i}:00.000Z`, { session: id, plan: `p-${uebung}`, uebung, status: "satz", saetze }));
  });
  const ende = new Date(Date.parse(start) + minuten * 6e4).toISOString();
  ops.push(op("gym.checkout", ende, { session: id, ende: swift(ende), status: "ende" }));
  return ops;
}

test("Datum: Berlin, Wochentag 1 = Mo, Montag der Woche", () => {
  assert.equal(gym.datumText(new Date("2026-10-04T22:30:00Z")), "2026-10-05");
  assert.equal(gym.wochentag("2026-10-05"), 1);
  assert.equal(gym.wochentag("2026-10-04"), 7);
  assert.equal(gym.montag("2026-10-08"), "2026-10-05");
  assert.equal(gym.addTage("2026-10-05", -7), "2026-09-28");
});

test("Faltung: neuester Plan gilt, gelöschte und zurückgenommene Einheiten, Aufwärmsätze zählen nicht", () => {
  const ops = [
    op("gym.plan", "2026-10-01T10:00:00Z", { tage: [{ id: "T1", name: "Alt", wochentage: [1], uebungen: [] }] }),
    op("gym.plan", "2026-10-02T10:00:00Z", { tage: [{ id: "T2", name: "Neu", wochentage: [2], uebungen: [] }] }),
    ...einheit("A", "2026-10-05", [[LATZUG, [satz(12, 20, { typ: "w" }), satz(10, 60), satz(8, 65), { wdh: 8, kg: 65, failure: false, ok: false }]]]),
    ...einheit("B", "2026-10-06", [[HAMMER, [satz(10, 12)]]]),
    op("gym.loeschen", "2026-10-06T19:00:00Z", { session: "B" }),
    op("gym.checkin", "2026-10-07T16:00:00Z", { session: "C", start: swift("2026-10-07T16:00:00Z") }),
    op("gym.checkout", "2026-10-07T17:00:00Z", { session: "C", ende: swift("2026-10-07T17:00:00Z"), status: "ende" }),
    op("gym.checkout", "2026-10-07T17:01:00Z", { session: "C", status: "wieder" }),
  ];
  const f = gym.falten(ops);
  assert.equal(f.plan.tage[0].name, "Neu");
  assert.deepEqual(f.plaene.map((p) => p.tage[0]), ["Neu", "Alt"]);
  assert.equal(f.tagNamen.T1, "Alt");
  assert.deepEqual(f.sessions.map((s) => s.id), ["C", "A"]);
  assert.equal(f.sessions[0].ende, null, "wieder = Auschecken rückgängig");
  const a = f.sessions[1];
  assert.equal(a.laeufe[0].saetze.length, 2);
  assert.equal(a.laeufe[0].fertig, true);
  assert.equal(a.laeufe[0].ende, null, "ein Satz offen: Übung läuft noch");
  assert.equal(Math.round((a.ende - a.start) / 6e4), 60);
});

test("Faltung: weg nimmt die Übung heraus, Tausch merkt die ursprüngliche", () => {
  const ops = [
    op("gym.checkin", "2026-10-05T16:00:00Z", { session: "S", start: swift("2026-10-05T16:00:00Z") }),
    op("gym.uebung", "2026-10-05T16:01:00Z", { session: "S", plan: "p1", uebung: HAMMER, status: "satz", saetze: [satz(10, 12)] }),
    op("gym.uebung", "2026-10-05T16:02:00Z", { session: "S", plan: "p1", uebung: LATZUG, status: "satz", saetze: [satz(10, 50)], ersatzFuer: HAMMER }),
    op("gym.uebung", "2026-10-05T16:03:00Z", { session: "S", plan: "p2", uebung: HAMMER, status: "satz", saetze: [satz(10, 12)] }),
    op("gym.uebung", "2026-10-05T16:04:00Z", { session: "S", plan: "p2", status: "weg" }),
  ];
  const [s] = gym.falten(ops).sessions;
  assert.equal(s.laeufe.length, 1);
  assert.equal(s.laeufe[0].uebung, LATZUG);
  assert.equal(s.laeufe[0].ersatzFuer, HAMMER);
});

test("Muskeln: Haupt 1, Neben 0,5, Cardio nichts", () => {
  const t = gym.teile(kat.nachId.get(LATZUG));
  assert.deepEqual(t[0], ["rLat", 1]);
  assert.ok(t.some(([teil, f]) => gym.gruppeVon(teil) === "bizeps" && f === 0.5));
  assert.deepEqual(gym.teile(kat.uebungen.find((u) => u.koerper === "Cardio")), []);
});

test("Ziele wie KoerperZiele: Standard-Prio für Ahmed, Annika ohne Ziele leer", () => {
  const a = gym.ziele({}, "ahmed");
  assert.equal(a.saetze.schulter, 16);
  assert.equal(a.saetze.brust, 12);
  assert.equal(a.saetze.beine, 8);
  assert.deepEqual(gym.ziele({}, "annika"), { prio: [], saetze: {} });
  assert.equal(gym.ziele({ "ziel.prio.beine": 1, "ziel.saetze.brust": 5 }, "ahmed").saetze.beine, 12);
  assert.equal(gym.ziele({ "ziel.prio.beine": 1, "ziel.saetze.brust": 5 }, "ahmed").saetze.brust, 5);
});

test("Kraft: Epley, nächstes Mal wie KoerperLogik.naechstesMal", () => {
  assert.equal(gym.e1rm({ wdh: 1, kg: 100 }), 100);
  assert.equal(Math.round(gym.e1rm({ wdh: 10, kg: 60 })), 80);
  assert.equal(gym.e1rm({ wdh: 10 }), null);
  assert.equal(gym.naechstesMal([satz(12, 60), satz(12, 60)]), "62.5 kg × 8");
  assert.equal(gym.naechstesMal([satz(12, 60), satz(9, 60)]), "60 kg × 10");
  assert.equal(gym.naechstesMal([{ wdh: 8 }, { wdh: 7 }]), "8 Wdh");
});

test("Auswertung: Woche, Sätze je Gruppe gegen Ziel, Erholung, Plateau, Plantreue, Kraftverhältnis", () => {
  const plan = { tage: [{ id: "T1", name: "Pull", wochentage: [1], uebungen: [] }] };
  const ops = [op("gym.plan", "2026-09-01T10:00:00Z", plan)];
  // Vier Einheiten Latzug ohne Steigerung nach der ersten: Plateau.
  ["2026-09-14", "2026-09-21", "2026-09-28", "2026-10-05"].forEach((d, i) => ops.push(...einheit(`L${i}`, d, [[LATZUG, [satz(10, i === 0 ? 70 : 65), satz(10, 65)]]])));
  const KB = kat.uebungen.find((u) => u.en === "barbell full squat").id;
  const BANK = kat.uebungen.find((u) => u.en === "barbell bench press").id;
  ops.push(...einheit("K", "2026-10-06", [[KB, [satz(5, 100)]], [BANK, [satz(5, 60)]]], { tag: "X" }));
  const f = gym.falten(ops);
  const r = gym.auswerten(f, kat, { jetzt: new Date("2026-10-07T12:00:00Z"), wochen: 4, ziel: gym.ziele({}, "ahmed") });

  assert.equal(r.trainings, 5);
  assert.equal(r.serieWochen, 4);
  assert.equal(r.wochen[0].woche, "2026-10-05");
  assert.equal(r.wochen[0].trainings, 2);
  assert.equal(r.wochen[0].saetze, 4);
  assert.equal(r.saetzeJeGruppe.ruecken.dieseWoche, 2);
  assert.equal(r.saetzeJeGruppe.ruecken.ziel, 16);
  assert.ok(r.erholung.beine.prozent < 90, "Beine gestern trainiert");
  assert.equal(r.erholung.brust.tageSeitTraining, 0);
  assert.equal(r.erholung.nacken.formErhalt, "nie trainiert");

  const latzug = r.uebungen.find((u) => u.id === LATZUG);
  assert.equal(latzug.einheiten, 4);
  assert.equal(latzug.plateau, true);
  assert.equal(latzug.rekordAm, "2026-09-14");
  assert.equal(r.planTreue[0].geplant, 4);
  assert.equal(r.planTreue[0].gemacht, 4);
  assert.equal(r.planTreue[0].alsTagGewaehlt, 4);

  // Bank 60×5 = e1RM 70 gegen Soll 75 % von 116,7 = 87,5: schwach.
  assert.equal(r.kraftVerhaeltnis.basis, "kniebeuge");
  assert.equal(r.kraftVerhaeltnis.bankdruecken.stand, "schwach");
});

test("Plan prüfen: Kurzform, Namen, ids bleiben, Ruhetage als Rest", () => {
  const { plan, fehler } = gym.planPruefen(
    {
      tage: [
        { id: "T1", name: "Pull", wochentage: [2, 1], uebungen: [{ id: "U1", uebung: LATZUG, saetze: 4, wdh: 8, kg: 60, notiz: "Sitz 3" }, { uebung: "barbell full squat", saetze: [{ wdh: 5, kg: 100, typ: "w" }] }] },
        { name: "Cardio", wochentage: [4], uebungen: [{ uebung: kat.uebungen.find((u) => u.koerper === "Cardio").id }] },
        { name: "Eigen", wochentage: [], uebungen: [{ uebung: "eigen", name: "Sandsack" }] },
      ],
      splitName: "Mein Split",
    },
    kat
  );
  assert.equal(fehler, undefined);
  assert.deepEqual(plan.tage[0].wochentage, [1, 2]);
  assert.equal(plan.tage[0].id, "T1");
  assert.equal(plan.tage[0].uebungen[0].id, "U1");
  assert.deepEqual(plan.tage[0].uebungen[0].saetze[0], { wdh: 8, kg: 60, failure: false });
  assert.equal(plan.tage[0].uebungen[0].saetze.length, 4);
  assert.equal(plan.tage[0].uebungen[0].notiz, "Sitz 3");
  assert.equal(plan.tage[0].uebungen[1].uebung, kat.uebungen.find((u) => u.en === "barbell full squat").id);
  assert.equal(plan.tage[0].uebungen[1].saetze[0].typ, "w");
  assert.deepEqual(plan.tage[1].uebungen[0].saetze, []);
  assert.equal(plan.tage[1].uebungen[0].minuten, 20);
  assert.match(plan.tage[1].id, /^[0-9A-F-]{36}$/);
  assert.equal(plan.tage[2].uebungen[0].name, "Sandsack");
  assert.deepEqual(plan.ruhetage, [3, 5, 6, 7]);
  assert.equal(plan.splitName, "Mein Split");
});

test("Plan prüfen: lesbare Fehler statt kaputtem Plan", () => {
  const { fehler } = gym.planPruefen(
    { tage: [{ name: "A", wochentage: [1, 9], uebungen: [{ uebung: "gibtsnicht" }, { uebung: LATZUG, saetze: 0 }, { uebung: "eigen" }] }, { name: "B", wochentage: [1] }], ruhetage: [1] },
    kat
  );
  assert.ok(fehler.some((f) => f.includes("Wochentag 9")));
  assert.ok(fehler.some((f) => f.includes('"gibtsnicht"')));
  assert.ok(fehler.some((f) => f.includes("saetze muss")));
  assert.ok(fehler.some((f) => f.includes("eigene Übung braucht name")));
  assert.ok(fehler.some((f) => f.includes("Mo gehört schon zu A")));
  assert.ok(fehler.some((f) => f.includes("Ruhetag Mo")));
  assert.deepEqual(gym.planPruefen({}, kat).fehler, ["plan.tage fehlt"]);
});

test("Split als Plan wie SplitLogik.alsPlan, Unterschied je Tag-id", () => {
  const sp = kat.splits.find((s) => s.id === "m-ahmed01");
  const plan = gym.splitAlsPlan(sp);
  assert.equal(plan.splitName, sp.name);
  assert.equal(plan.tage.length, sp.einheiten.length);
  const z = sp.einheiten[0].uebungen[0];
  assert.equal(plan.tage[0].uebungen[0].saetze.length, z.saetze);
  assert.equal(plan.tage[0].uebungen[0].saetze[0].wdh, z.von);
  assert.equal(gym.planPruefen(plan, kat).fehler, undefined);

  const alt = { tage: [{ id: "A", name: "Push", wochentage: [1], uebungen: [] }, { id: "B", name: "Push", wochentage: [5], uebungen: [] }], ruhetage: [] };
  const neu = { tage: [{ id: "A", name: "Push", wochentage: [1], uebungen: [{ id: "x", uebung: LATZUG, saetze: [{ wdh: 8, failure: false }] }] }, { id: "C", name: "Beine", wochentage: [4], uebungen: [] }], ruhetage: [] };
  const u = gym.planUnterschied(alt, neu, kat);
  assert.equal(u.length, 3);
  assert.match(u[0], /^~ Push: Mo: leer {2}-> {2}Mo: Latzug/);
  assert.match(u[1], /^\+ Beine/);
  assert.match(u[2], /^- Push \(Fr/);
  assert.deepEqual(gym.planUnterschied(alt, alt, kat), ["keine Änderung"]);
});

test("Katalogsuche: Wörter in beiden Sprachen, Filter", () => {
  const r = gym.uebungenSuchen(kat, { suche: "bench barbell", limit: 5 });
  assert.ok(r.anzahl > 5);
  assert.equal(r.uebungen.length, 5);
  assert.ok(gym.uebungenSuchen(kat, { muskel: "latissimus", geraet: "Kabelzug" }).uebungen.every((u) => u.muskel === "Latissimus" && u.geraet === "Kabelzug"));
});
