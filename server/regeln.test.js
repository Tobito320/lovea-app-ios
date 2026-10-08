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

test("geste herz, kuss, anstupsen: laut mit eigenem Ton", () => {
  const herz = regel("geste", "annika", { art: "herz" });
  assert.equal(herz.stufe, "laut");
  assert.equal(herz.text, "Annika denkt gerade an dich");
  assert.equal(herz.ton, "herzschlag.wav");

  const kuss = regel("geste", "annika", { art: "kuss" });
  assert.equal(kuss.stufe, "laut");
  assert.equal(kuss.text, "Annika hat dir einen Kuss geschickt");
  assert.equal(kuss.ton, "kuss_mitteilung.wav");
  const stups = regel("geste", "ahmed", { art: "anstupsen" });
  assert.equal(stups.text, "Ahmed hat dich angestupst");
  assert.equal(stups.ton, "anstupsen.wav");
});

test("geste herz aus der Lampe: still, ohne Text und Ton", () => {
  const lampe = regel("geste", "annika", { art: "herz", quelle: "lampe" });
  assert.equal(lampe.stufe, "still");
  assert.equal(lampe.kategorie, "geste");
  assert.equal(lampe.text, null);
  assert.equal(lampe.ton, undefined);
  assert.equal(regel("geste", "annika", { art: "herz", quelle: "widget" }).stufe, "laut");
});

test("Stimmung, Geschenkbox, Zimmer-Signale lösen keine eigene Push aus", () => {
  assert.equal(regel("gefuehl.setzen", "annika", { art: "muede" }), null);
  assert.equal(regel("geschenkbox.setzen", "annika", { id: "x", text: "Ring" }), null);
});

test("laute Mitteilungen haben immer einen Ton, leise keinen", () => {
  assert.equal(regel("nachricht.neu", "ahmed", { text: "hi" }).ton, "nachricht.wav");
  assert.equal(regel("ort.ereignis", "ahmed", { art: "ankunft" }, { ortName: "Gym" }).ton, "ort.wav");
  assert.equal(regel("nachricht.reaktion", "ahmed", { id: "1" }).ton, undefined);
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
  assert.equal(regel("termin.setzen", "annika", {}).text, "Annika hat einen Termin eingetragen oder geändert");
  assert.equal(regel("frage.antwort", "annika", {}).stufe, "leise");
  assert.equal(regel("snap.aufnahme", "annika", { art: "screenshot" }).stufe, "leise");
});

test("nicht gelistete Art hat keine Push", () => {
  assert.equal(regel("nachricht.gelesen", "annika", { bis: "x" }), null);
});

test("shop.kauf: Geschenk (fuer != von) ist laut, eigener Kauf keine Push", () => {
  const geschenk = regel("shop.kauf", "ahmed", { id: "k1", artikel: "tasche.gucci-tasche", fuer: "annika" });
  assert.equal(geschenk.stufe, "laut");
  assert.equal(geschenk.text, "Ahmed hat dir etwas geschenkt");
  assert.equal(geschenk.kategorie, "shop");
  assert.equal(regel("shop.kauf", "ahmed", { id: "k2", artikel: "socken", fuer: "ahmed" }), null);
});

// Z-27.1
test("gruss: laut, Text je nach nacht/morgen, Kategorie geste", () => {
  const nacht = regel("gruss", "annika", { art: "nacht" });
  assert.equal(nacht.stufe, "laut");
  assert.equal(nacht.kategorie, "geste");
  assert.equal(nacht.text, "Annika sagt Gute Nacht");
  assert.equal(regel("gruss", "ahmed", { art: "morgen" }).text, "Ahmed sagt Guten Morgen");
});

// p64: Wärmflasche und Tee. Leise, ohne Ton, und der Text verrät nichts über den Grund.
test("waerme.setzen: nur bei an eine leise Push ohne Zyklus-Wörter", () => {
  const an = regel("waerme.setzen", "annika", { tag: "2026-10-08", an: true });
  assert.equal(an.stufe, "leise");
  assert.equal(an.kategorie, "geste");
  assert.equal(an.text, "Annika könnte heute etwas Süßes und Warmes brauchen");
  assert.doesNotMatch(an.text, /Periode|Zyklus|Regel|Krämpfe|Blutung|Schmerz/i);
  assert.equal(regel("waerme.setzen", "annika", { tag: "2026-10-08", an: false }), null);
});

// Z-27.2: ein Brief darf seinen Inhalt nie im Push-Text preisgeben, auch wenn `text`/`medien`
// zusätzlich gesetzt sind.
test("nachricht.neu mit brief verrät den Inhalt nicht im Push-Text", () => {
  const brief = regel("nachricht.neu", "ahmed", { text: "ein langer Liebesbrief", brief: { titel: "Für dich" } });
  assert.equal(brief.text, "Ahmed hat dir einen Brief geschrieben");
  assert.doesNotMatch(brief.text, /Liebesbrief/);
});

// Z-31.4: die Zeitkapsel ist weg (Spec 2.10) -- `kapsel` von einem älteren Build ist eine normale Nachricht.
test("nachricht.neu mit kapsel bekommt den normalen Nachrichten-Text", () => {
  const r = regel("nachricht.neu", "annika", { text: "Bin gleich da", kapsel: { oeffnetAm: "2026-12-24" } });
  assert.equal(r.stufe, "laut");
  assert.equal(r.text, "Annika: Bin gleich da");
});

test("gym.checkout: Push nur beim echten Beenden, nicht bei Zeitkorrektur oder Rückgängig", () => {
  const r = regel("gym.checkout", "ahmed", { session: "s", ende: "2026-10-01T17:00:00Z", status: "ende", minuten: 58, zahl: 12 });
  assert.equal(r.stufe, "leise");
  assert.equal(r.kategorie, "gym");
  assert.equal(r.text, "Ahmed war 58 min im Gym · 12 Sätze");
  assert.equal(r.ton, undefined);
  assert.equal(regel("gym.checkout", "annika", { session: "s", status: "ende", minuten: 40, zahl: 1 }).text, "Annika war 40 min im Gym · 1 Satz");
  assert.equal(regel("gym.checkout", "annika", { session: "s", status: "ende" }).text, "Annika hat das Training beendet");
  assert.equal(regel("gym.checkout", "ahmed", { session: "s", ende: "2026-10-01T17:00:00Z" }), null); // Zeiten korrigiert
  assert.equal(regel("gym.checkout", "ahmed", { session: "s", status: "wieder" }), null); // Auschecken rückgängig
});

test("gym.checkout: Rekorde stehen am Ende des Textes", () => {
  assert.equal(regel("gym.checkout", "ahmed", { status: "ende", minuten: 58, zahl: 12, rekorde: 2 }).text, "Ahmed war 58 min im Gym · 12 Sätze · 2 Rekorde");
  assert.equal(regel("gym.checkout", "ahmed", { status: "ende", minuten: 58, zahl: 12, rekorde: 1 }).text, "Ahmed war 58 min im Gym · 12 Sätze · 1 Rekord");
  assert.equal(regel("gym.checkout", "ahmed", { status: "ende", minuten: 58, zahl: 12, rekorde: 0 }).text, "Ahmed war 58 min im Gym · 12 Sätze");
});

test("sprachpost.neu und brief.neu: leise, Kategorie chat, kein Ton", () => {
  const s = regel("sprachpost.neu", "ahmed", { id: "s1" });
  assert.equal(s.stufe, "leise");
  assert.equal(s.kategorie, "chat");
  assert.equal(s.text, "Neue Sprachpost von Ahmed");
  assert.equal(s.ton, undefined);
  const b = regel("brief.neu", "ahmed", { id: "b1" });
  assert.equal(b.stufe, "leise");
  assert.equal(b.text, "Ahmed hat einen Brief für dich versiegelt");
  assert.equal(regel("sprachpost.gehoert", "annika", { id: "s1" }), null);
  assert.equal(regel("brief.geoeffnet", "annika", { id: "b1" }), null);
});
