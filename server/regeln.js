// Push-Regeln: Op-Art -> Stufe, Kategorie (für einstellung.setzen
// "mitteilungen.<kategorie>") und Text (Spec 12).

// Gleiche Texte wie ChatHinweis.text in der App.
const AUFNAHME_TEXT = {
  bildschirmaufnahme: "hat den Bildschirm aufgenommen",
  chatScreenshot: "hat einen Screenshot vom Chat gemacht",
  chatAufnahme: "nimmt den Chat auf",
  gespeichertFoto: "hat ein Bild in Aufnahmen gespeichert",
  gespeichertVideo: "hat ein Video in Aufnahmen gespeichert",
  profilScreenshot: "hat einen Screenshot von deinem Profil gemacht",
  profilAufnahme: "nimmt dein Profil auf",
  stickerScreenshot: "hat einen Screenshot von einem Sticker gemacht",
  stickerAufnahme: "nimmt einen Sticker auf",
  fotoScreenshot: "hat einen Screenshot von deinem Foto gemacht",
  fotoAufnahme: "nimmt dein Foto auf",
  videoScreenshot: "hat einen Screenshot von deinem Video gemacht",
  videoAufnahme: "nimmt dein Video auf",
  chatFotoScreenshot: "hat einen Screenshot von einem Foto im Chat gemacht",
  chatFotoAufnahme: "nimmt ein Foto im Chat auf",
  chatVideoScreenshot: "hat einen Screenshot von einem Video im Chat gemacht",
  chatVideoAufnahme: "nimmt ein Video im Chat auf",
};

const NAME = { ahmed: "Ahmed", annika: "Annika" };

function kuerzen(text, n = 120) {
  if (!text) return "";
  return text.length > n ? `${text.slice(0, n - 1)}…` : text;
}

const SYSTEM_TEXT = {
  nah: "Ihr seid gerade zufällig ganz nah beieinander",
};

function nachrichtText(von, d) {
  const name = NAME[von];
  if (d.system) return SYSTEM_TEXT[d.system] ?? `${name} hat dir geschrieben`;
  // Z-27.2: der Inhalt eines Briefs darf nie im Push-Text stehen -- vor allen anderen Feldern
  // geprüft, auch wenn `d.text`/`d.medien` zusätzlich gesetzt sind. `d.kapsel` zählt seit Runde 3
  // nicht mehr (Spec 2.10), so eine Nachricht bekommt den normalen Text.
  if (d.brief) return `${name} hat dir einen Brief geschrieben`;
  const typ = d.medien?.[0]?.typ;
  if (typ === "foto") return `${name} hat ein Foto geschickt`;
  if (typ === "video") return `${name} hat ein Video geschickt`;
  if (typ === "sprache") return `${name} hat eine Sprachnachricht geschickt`;
  if (d.snap) return `${name} hat einen Snap geschickt`;
  if (d.gif) return `${name} hat ein GIF geschickt`;
  if (d.sticker) return `${name} hat einen Sticker geschickt`;
  if (d.text) return `${name}: ${kuerzen(d.text)}`;
  return `${name} hat dir geschrieben`;
}

function gesteRegel(von, d) {
  const name = NAME[von];
  // Lampe im Zimmer (Paar-Signale): derselbe Herz-Tipp, aber ohne Text und Ton -- die Lampe leuchtet nur.
  if (d.art === "herz" && d.quelle === "lampe") return { stufe: "still", kategorie: "geste", titel: "Lovea", text: null };
  if (d.art === "herz") {
    return { stufe: "laut", kategorie: "geste", titel: "Lovea", text: `${name} denkt gerade an dich`, ton: "herzschlag.wav" };
  }
  // 25.09.: Kuss und Anstupsen kommen auch als Mitteilung, mit eigenem verspielten Ton.
  if (d.art === "kuss") {
    return { stufe: "laut", kategorie: "geste", titel: "Lovea", text: `${name} hat dir einen Kuss geschickt`, ton: "kuss_mitteilung.wav" };
  }
  if (d.art === "anstupsen") {
    return { stufe: "laut", kategorie: "geste", titel: "Lovea", text: `${name} hat dich angestupst`, ton: "anstupsen.wav" };
  }
  return { stufe: "inapp", kategorie: "geste", titel: "Lovea", text: null };
}

// Z-27.1: eigene Funktion (nicht in TABELLE inline), damit Block F "shop.kauf" daneben ergänzen
// kann, ohne dieselbe Zeile zu berühren. Kategorie "geste" -- passt zur bestehenden Einstellung,
// keine eigene "gruss"-Kategorie nötig.
function grussRegel(von, d) {
  const name = NAME[von];
  const text = d.art === "nacht" ? `${name} sagt Gute Nacht` : `${name} sagt Guten Morgen`;
  return { stufe: "laut", kategorie: "geste", titel: "Lovea", text };
}

// Nur das echte Beenden eines Trainings (status "ende", von der App beim Auschecken gesetzt).
// Zeiten korrigieren und "Auschecken rückgängig" senden auch `gym.checkout`, aber ohne diesen Status.
function gymEndeRegel(von, d) {
  if (d.status !== "ende") return null;
  const dauer = Number.isFinite(d.minuten) && d.minuten > 0 ? ` war ${d.minuten} min im Gym` : " hat das Training beendet";
  const saetze = Number.isFinite(d.zahl) && d.zahl > 0 ? ` · ${d.zahl} ${d.zahl === 1 ? "Satz" : "Sätze"}` : "";
  const rekorde = Number.isFinite(d.rekorde) && d.rekorde > 0 ? ` · ${d.rekorde} ${d.rekorde === 1 ? "Rekord" : "Rekorde"}` : "";
  return { stufe: "leise", kategorie: "gym", titel: "Lovea", text: `${NAME[von]}${dauer}${saetze}${rekorde}` };
}

// art -> (von, d) => {stufe, kategorie, titel, text, ton?} | null (keine Push)
const TABELLE = {
  "gym.checkout": gymEndeRegel,
  "nachricht.neu": (von, d) => ({ stufe: "laut", kategorie: "chat", titel: "Lovea", text: nachrichtText(von, d) }),
  "nachricht.reaktion": (von) => ({ stufe: "leise", kategorie: "chat", titel: "Lovea", text: `${NAME[von]} hat reagiert` }),
  "geste": gesteRegel,
  "gruss": grussRegel,
  "zeichnung.einladung": (von) => ({ stufe: "laut", kategorie: "zeichnen", titel: "Lovea", text: `${NAME[von]} lädt dich zum Mitzeichnen ein` }),
  "spiel.einladung": (von) => ({ stufe: "laut", kategorie: "spiel", titel: "Lovea", text: `${NAME[von]} hat dich zu einem Spiel eingeladen` }),
  "ort.ereignis": (von, d, kontext) => ({
    stufe: "laut",
    kategorie: "orte",
    titel: "Lovea",
    text: `${NAME[von]} ist ${d.art === "ankunft" ? "bei" : "weg von"} ${kontext?.ortName ?? "einem Ort"} ${d.art === "ankunft" ? "angekommen" : ""}`.trim(),
  }),
  "termin.setzen": (von) => ({ stufe: "leise", kategorie: "kalender", titel: "Lovea", text: `${NAME[von]} hat einen Termin eingetragen oder geändert` }),
  "frage.antwort": (von) => ({ stufe: "leise", kategorie: "frage", titel: "Lovea", text: `${NAME[von]} hat die Frage des Tages beantwortet` }),
  "snap.wiederholt": (von, d) => ({ stufe: "leise", kategorie: "chat", titel: "Lovea", text: d.anzahl > 1 ? `${NAME[von]} hat den Snap ${d.anzahl}-mal wiederholt` : `${NAME[von]} hat den Snap wiederholt` }),
  "snap.aufnahme": (von, d) => ({
    stufe: "leise",
    kategorie: "chat",
    titel: "Lovea",
    text: `${NAME[von]} ${AUFNAHME_TEXT[d.art] ?? "hat einen Screenshot gemacht"}`,
  }),
  // Nähe: leise, ohne Ton. Die Sprachpost spielt nie von allein ab, die Push sagt nur, dass etwas wartet.
  "sprachpost.neu": (von) => ({ stufe: "leise", kategorie: "chat", titel: "Lovea", text: `Neue Sprachpost von ${NAME[von]}` }),
  // Langsam gesendet (`ankunft` = Epochensekunden in der Zukunft): keine Push beim Versiegeln, der Brief ist noch unterwegs.
  "brief.neu": (von, d) => (d && d.ankunft * 1000 > Date.now() ? null : { stufe: "leise", kategorie: "chat", titel: "Lovea", text: `${NAME[von]} hat einen Brief für dich versiegelt` }),
  // Z-23.2: nur bei einem Geschenk (fuer != von) - ein Kauf fuer sich selbst loest keine Push aus.
  "shop.kauf": (von, d) => (d.fuer === von ? null : { stufe: "laut", kategorie: "shop", titel: "Lovea", text: `${NAME[von]} hat dir etwas geschenkt` }),
  // p64: Wärmflasche und Tee. Die Op sagt nur Tag und an/aus; der Text nennt den Grund nie. "aus" bleibt still.
  "waerme.setzen": (von, d) => (d.an === true ? { stufe: "leise", kategorie: "geste", titel: "Lovea", text: `${NAME[von]} könnte heute etwas Süßes und Warmes brauchen` } : null),
};

// Liefert die Push-Regel für eine Op, oder null, wenn diese Art keine Push
// auslöst. `kontext` ist optionaler, von raum.js nachgeschlagener Zusatzstoff
// (z. B. der Ortsname), damit diese Datei selbst reine Logik bleibt.
export function regel(art, von, d, kontext) {
  const f = TABELLE[art];
  if (!f) return null;
  const r = f(von, d, kontext);
  // 25.09.: laute Mitteilungen hatten nie einen Ton. Orte klingen gleich, alles andere wie eine Nachricht.
  // Die Dateien liegen in der App (Lovea/Sources/App/Toene), sonst spielt iOS nichts.
  if (r && r.stufe === "laut" && !r.ton) r.ton = r.kategorie === "orte" ? "ort.wav" : "nachricht.wav";
  return r;
}
