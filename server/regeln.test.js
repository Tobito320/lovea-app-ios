import { test } from "node:test";
import assert from "node:assert/strict";
import { regel } from "./regeln.js";

test("nachricht.neu: laut, Text je Medientyp (Block-1-Beispiele)", () => {
  assert.equal(regel("nachricht.neu", "annika", { text: "Bin gleich da" }).stufe, "laut");
  assert.equal(regel("nachricht.neu", "annika", { text: "Bin gleich da" }).text, "Annika: Bin gleich da");
  assert.equal(regel("nachricht.neu", "annika", { medien: [{ typ: "foto" }] }).text, "Annika hat ein Foto geschickt");
  assert.equal(regel("nachricht.neu", "annika", { medien: [{ typ: "video" }] }).text, "Annika hat ein Video geschickt");
  assert.equal(regel("nachricht.neu", "annika", { medien: [{ typ: "sprache" }] }).text, "Annika hat eine Sprachnachricht geschickt");
  assert.equal(regel("nachricht.neu", "annika", { snap: { bleibt: true } }).text, "Annika hat einen Snap geschickt");
  assert.equal(regel("nachricht.neu", "annika", { gif: { url: "x" } }).text, "Annika hat ein GIF geschickt");
  assert.equal(regel("nachricht.neu", "annika", { sticker: { medienId: "x" } }).text, "Annika hat einen Sticker geschickt");
});

test("nachricht.neu mit langem Text wird auf 120 Zeichen gekürzt", () => {
  const lang = "x".repeat(200);
  const r = regel("nachricht.neu", "ahmed", { text: lang });
  assert.equal(r.text.length, "Ahmed: ".length + 120);
  assert.ok(r.text.endsWith("…"));
});

test("nachricht.reaktion: leise", () => {
  assert.equal(regel("nachricht.reaktion", "annika", { id: "1" }).stufe, "leise");
});

test("geste herz: laut mit Herzschlag-Ton; kuss/anstupsen: nur in der App", () => {
  const herz = regel("geste", "annika", { art: "herz" });
  assert.equal(herz.stufe, "laut");
  assert.equal(herz.text, "Annika denkt gerade an dich");
  assert.equal(herz.ton, "herzschlag.caf");

  assert.equal(regel("geste", "annika", { art: "kuss" }).stufe, "inapp");
  assert.equal(regel("geste", "annika", { art: "anstupsen" }).stufe, "inapp");
});

test("zufällig nah kommt als system-Nachricht mit laut", () => {
  const r = regel("nachricht.neu", "ahmed", { system: "nah" });
  assert.equal(r.stufe, "laut");
  assert.match(r.text, /nah/);
});

test("weitere Arten: Einladungen laut, Termin/Frage/Screenshot leise", () => {
  assert.equal(regel("zeichnung.einladung", "annika", {}).stufe, "laut");
  assert.equal(regel("spiel.einladung", "annika", {}).stufe, "laut");
  assert.equal(regel("termin.setzen", "annika", {}).stufe, "leise");
  assert.equal(regel("frage.antwort", "annika", {}).stufe, "leise");
  assert.equal(regel("snap.aufnahme", "annika", { art: "screenshot" }).stufe, "leise");
});

test("nicht gelistete Art hat keine Push", () => {
  assert.equal(regel("nachricht.gelesen", "annika", { bis: "x" }), null);
});

// Z-27.1
test("gruss: laut, Text je nach nacht/morgen, Kategorie geste", () => {
  const nacht = regel("gruss", "annika", { art: "nacht" });
  assert.equal(nacht.stufe, "laut");
  assert.equal(nacht.kategorie, "geste");
  assert.equal(nacht.text, "Annika sagt Gute Nacht");
  assert.equal(regel("gruss", "ahmed", { art: "morgen" }).text, "Ahmed sagt Guten Morgen");
});

// Z-27.2: eine Zeitkapsel/ein Brief darf ihren Inhalt nie im Push-Text preisgeben, auch wenn
// `text`/`medien` zusätzlich gesetzt sind.
test("nachricht.neu mit kapsel/brief verrät den Inhalt nicht im Push-Text", () => {
  const kapsel = regel("nachricht.neu", "annika", { text: "geheimer Inhalt", kapsel: { oeffnetAm: "2026-12-24" } });
  assert.equal(kapsel.text, "Annika hat dir eine Zeitkapsel geschickt");
  assert.doesNotMatch(kapsel.text, /geheim/);

  const brief = regel("nachricht.neu", "ahmed", { text: "ein langer Liebesbrief", brief: { titel: "Für dich" } });
  assert.equal(brief.text, "Ahmed hat dir einen Brief geschrieben");
  assert.doesNotMatch(brief.text, /Liebesbrief/);
});
