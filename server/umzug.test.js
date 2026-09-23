import { test } from "node:test";
import assert from "node:assert/strict";
import { zeileZuEintraege, termineZuOps, zaehlung, pruefeOps } from "./umzug.mjs";

const GEAENDERT = "2026-09-01T10:00:00.000Z";

test("kalender/ mit Treffen, Notizen und Stimmung -> treffen.setzen, notiz.setzen, stimmung.setzen", () => {
  const { ops, medien } = zeileZuEintraege({
    key: "kalender/2026-09-10",
    geaendert: GEAENDERT,
    wert: {
      herz: true,
      uhrzeit: "18:00",
      von: "ahmed",
      gemeinsam: "Kino",
      notizen: { ahmed: "Freu mich", annika: "Ich auch" },
      stimmung: { ahmed: "gut", annika: "mittel" },
    },
  });
  assert.equal(medien.length, 0);
  assert.deepEqual(
    ops.find((o) => o.art === "treffen.setzen").d,
    { datum: "2026-09-10", uhrzeit: "18:00", wasMachenWir: "Kino" }
  );
  assert.equal(ops.filter((o) => o.art === "notiz.setzen").length, 2);
  assert.equal(ops.filter((o) => o.art === "stimmung.setzen").length, 2);
  const ahmedStimmung = ops.find((o) => o.art === "stimmung.setzen" && o.von === "ahmed");
  assert.deepEqual(ahmedStimmung.d, { datum: "2026-09-10", stimmung: "gut" });
});

test("kalender/ ohne Treffen (herz false) und ohne Inhalt legt nichts an", () => {
  const { ops } = zeileZuEintraege({
    key: "kalender/2026-09-11",
    geaendert: GEAENDERT,
    wert: { herz: false, uhrzeit: null, von: null, gemeinsam: "", notizen: {}, stimmung: {} },
  });
  assert.equal(ops.length, 0);
});

test("kalender/ mit gemeinsam-Text aber herz:false legt trotzdem treffen.setzen an (einziges Ziel dafür)", () => {
  const { ops } = zeileZuEintraege({
    key: "kalender/2026-09-12",
    geaendert: GEAENDERT,
    wert: { herz: false, uhrzeit: null, von: null, gemeinsam: "vielleicht Kino", notizen: {}, stimmung: {} },
  });
  assert.equal(ops.length, 1);
  assert.equal(ops[0].art, "treffen.setzen");
  assert.equal(ops[0].von, "ahmed"); // kein von im alten Datensatz -> ponytail-Fallback
  assert.deepEqual(ops[0].d, { datum: "2026-09-12", wasMachenWir: "vielleicht Kino" });
});

test("puenktlich/ mappt perfekt/passt/zuspaet/skip auf uhrwerk/charmant/troedel/weg", () => {
  const { ops } = zeileZuEintraege({
    key: "puenktlich/2026-09-10",
    geaendert: GEAENDERT,
    wert: { vonAhmed: "perfekt", vonAnnika: "skip" },
  });
  assert.equal(ops.length, 2);
  const vonAhmed = ops.find((o) => o.von === "ahmed");
  assert.deepEqual(vonAhmed.d, { datum: "2026-09-10", ueber: "annika", wert: "uhrwerk" });
  const vonAnnika = ops.find((o) => o.von === "annika");
  assert.deepEqual(vonAnnika.d, { datum: "2026-09-10", ueber: "ahmed", wert: "weg" });
});

test("antwort/<frageId>/<person> -> frage.antwort", () => {
  const { ops } = zeileZuEintraege({
    key: "antwort/t2026-09-10/ahmed",
    geaendert: GEAENDERT,
    wert: { text: "Meine Antwort", zeit: "2026-09-10T09:00:00.000Z" },
  });
  assert.equal(ops.length, 1);
  assert.equal(ops[0].art, "frage.antwort");
  assert.equal(ops[0].von, "ahmed");
  assert.deepEqual(ops[0].d, { frageId: "t2026-09-10", text: "Meine Antwort" });
});

test("frage/<id> -> frage.eigene", () => {
  const { ops } = zeileZuEintraege({
    key: "frage/eabc123",
    geaendert: GEAENDERT,
    wert: { id: "eabc123", text: "Magst du Winter?", von: "annika", zeit: "2026-09-10T09:00:00.000Z" },
  });
  assert.equal(ops[0].art, "frage.eigene");
  assert.deepEqual(ops[0].d, { id: "eabc123", text: "Magst du Winter?", kategorie: null });
});

test("thema/<id> -> thema.setzen", () => {
  const { ops } = zeileZuEintraege({
    key: "thema/xyz",
    geaendert: GEAENDERT,
    wert: { id: "xyz", text: "Urlaub planen", von: "ahmed", zeit: "2026-09-10T09:00:00.000Z", besprochen: "2026-09-11" },
  });
  assert.deepEqual(ops[0].d, { id: "xyz", text: "Urlaub planen", besprochen: "2026-09-11" });
});

test("zukunft/<id> -> liste.setzen", () => {
  const { ops } = zeileZuEintraege({
    key: "zukunft/abc",
    geaendert: GEAENDERT,
    wert: { id: "abc", text: "Nach Rom", von: "annika", zeit: "2026-09-10T09:00:00.000Z", geschafft: null, geschafftVon: null },
  });
  assert.equal(ops[0].art, "liste.setzen");
  assert.deepEqual(ops[0].d, { id: "abc", text: "Nach Rom", geschafft: null });
});

test("date/<id> -> idee.neu", () => {
  const { ops } = zeileZuEintraege({
    key: "date/abc",
    geaendert: GEAENDERT,
    wert: { id: "abc", text: "Picknick", von: "ahmed", zeit: "2026-09-10T09:00:00.000Z" },
  });
  assert.equal(ops[0].art, "idee.neu");
  assert.deepEqual(ops[0].d, { id: "abc", text: "Picknick" });
});

test("plan/<planId>/<id> -> checkliste.setzen am Plan-Datum, bekannter Plan", () => {
  const { ops } = zeileZuEintraege({
    key: "plan/halloween/p1",
    geaendert: GEAENDERT,
    wert: { id: "p1", text: "Kostüm kaufen", erledigt: true, zeit: "2026-09-10T09:00:00.000Z" },
  });
  assert.equal(ops[0].art, "checkliste.setzen");
  assert.equal(ops[0].von, "annika");
  assert.deepEqual(ops[0].d, { datum: "2026-10-31", id: "p1", text: "Kostüm kaufen", erledigt: true });
});

test("plan/<unbekannt>/<id> wird ausgelassen statt geraten", () => {
  const { ops } = zeileZuEintraege({
    key: "plan/unbekannt/p1",
    geaendert: GEAENDERT,
    wert: { id: "p1", text: "x", erledigt: false, zeit: GEAENDERT },
  });
  assert.equal(ops.length, 0);
});

const PNG_1X1 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";

test("zeichnung/<id> -> Medium + nachricht.neu mit Bildmassen und alter Zeit", () => {
  const { ops, medien } = zeileZuEintraege({
    key: "zeichnung/abc",
    geaendert: GEAENDERT,
    wert: { id: "abc", von: "ahmed", zeit: "2026-09-10T09:00:00.000Z", bild: PNG_1X1, gelesen: true },
  });
  assert.equal(medien.length, 1);
  assert.equal(medien[0].von, "ahmed");
  assert.match(medien[0].id, /^[A-Za-z0-9_-]+$/); // muss slash-frei sein: läuft als URL-Segment in PUT /medien/<id>/...
  assert.equal(ops[0].art, "nachricht.neu");
  assert.equal(ops[0].zeit, "2026-09-10T09:00:00.000Z");
  assert.equal(ops[0].d.medien[0].typ, "foto");
  assert.equal(ops[0].d.medien[0].breite, 1);
  assert.equal(ops[0].d.medien[0].hoehe, 1);
});

test("galerie/<person>/<id> -> umzug.galerie mit einer Medium-Ebene je Ebene", () => {
  const { ops, medien } = zeileZuEintraege({
    key: "galerie/annika/g1",
    geaendert: GEAENDERT,
    wert: {
      id: "g1",
      name: "Skizze",
      format: "quadrat",
      papier: "weiss",
      zeit: "2026-09-10T09:00:00.000Z",
      ebenen: [{ name: "Ebene 1", bild: PNG_1X1, deckkraft: 0.8, modus: "source-over", clip: false, schuetzt: true, sichtbar: true }],
    },
  });
  assert.equal(medien.length, 1);
  assert.equal(ops[0].art, "umzug.galerie");
  assert.equal(ops[0].von, "annika");
  assert.equal(ops[0].d.ebenen.length, 1);
  assert.equal(ops[0].d.ebenen[0].medienId, medien[0].id);
  assert.match(medien[0].id, /^[A-Za-z0-9_-]+$/);
  assert.equal(ops[0].d.ebenen[0].deckkraft, 0.8);
});

test("aufkleber/<person>/<id> -> umzug.aufkleber mit einem Medium", () => {
  const { ops, medien } = zeileZuEintraege({
    key: "aufkleber/ahmed/s1",
    geaendert: GEAENDERT,
    wert: { id: "s1", name: "Herz", bild: PNG_1X1, zeit: "2026-09-10T09:00:00.000Z" },
  });
  assert.equal(medien.length, 1);
  assert.equal(ops[0].art, "umzug.aufkleber");
  assert.equal(ops[0].d.medienId, medien[0].id);
  assert.match(medien[0].id, /^[A-Za-z0-9_-]+$/);
});

test("unbekannter Schluessel wird ignoriert (keine Ops, kein Fehler)", () => {
  const { ops, medien } = zeileZuEintraege({ key: "brauche/ahmed", geaendert: GEAENDERT, wert: { iso: "2026-09-10", stufe: "naehe" } });
  assert.equal(ops.length, 0);
  assert.equal(medien.length, 0);
});

test("dieselbe Zeile liefert zweimal dieselben Op-Ids (deterministisch fuer Rerun-Dedup)", () => {
  const zeile = { key: "date/abc", geaendert: GEAENDERT, wert: { id: "abc", text: "Picknick", von: "ahmed", zeit: GEAENDERT } };
  const a = zeileZuEintraege(zeile);
  const b = zeileZuEintraege(zeile);
  assert.deepEqual(a.ops.map((o) => o.id), b.ops.map((o) => o.id));
});

test("termineZuOps -> termin.setzen, 'wir' wird zu fuer:[ahmed,annika]", () => {
  const ops = termineZuOps(
    [
      { iso: "2026-09-30", t: "AP1-Prüfung", wer: "ahmed" },
      { iso: "2026-10-31", t: "Halloween mit Annikas Geschwistern", wer: "wir" },
    ],
    GEAENDERT
  );
  assert.equal(ops.length, 2);
  assert.deepEqual(ops[0].d.fuer, ["ahmed"]);
  assert.deepEqual(ops[1].d.fuer, ["ahmed", "annika"]);
  assert.equal(ops[0].art, "termin.setzen");
});

test("pruefeOps meldet fehlende/ungueltige von und zeit", () => {
  assert.deepEqual(pruefeOps([{ id: "a", art: "x", von: "ahmed", zeit: GEAENDERT, d: {} }]), []);
  const fehler = pruefeOps([
    { id: "b", art: "x", von: "niemand", zeit: GEAENDERT, d: {} },
    { id: "c", art: "y", von: "annika", zeit: "kein datum", d: {} },
    { id: "", art: "z", von: "ahmed", zeit: GEAENDERT, d: {} },
  ]);
  assert.equal(fehler.length, 3);
});

test("zaehlung gruppiert Ops nach Art", () => {
  const arten = zaehlung([
    { art: "notiz.setzen" },
    { art: "notiz.setzen" },
    { art: "idee.neu" },
  ]);
  assert.equal(arten.get("notiz.setzen"), 2);
  assert.equal(arten.get("idee.neu"), 1);
});
