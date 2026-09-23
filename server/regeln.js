// Push-Regeln: Op-Art -> Stufe, Kategorie (für einstellung.setzen
// "mitteilungen.<kategorie>") und Text (Spec 12).

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
  // Z-27.2: der Inhalt einer Zeitkapsel/eines Briefs darf nie im Push-Text stehen -- vor allen
  // anderen Feldern geprüft, auch wenn `d.text`/`d.medien` zusätzlich gesetzt sind.
  if (d.kapsel) return `${name} hat dir eine Zeitkapsel geschickt`;
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
  if (d.art === "herz") {
    return { stufe: "laut", kategorie: "geste", titel: "Lovea", text: `${name} denkt gerade an dich`, ton: "herzschlag.caf" };
  }
  // anstupsen, kuss: nur in der App.
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

// art -> (von, d) => {stufe, kategorie, titel, text, ton?} | null (keine Push)
const TABELLE = {
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
  "termin.setzen": (von) => ({ stufe: "leise", kategorie: "kalender", titel: "Lovea", text: `${NAME[von]} hat einen neuen Termin eingetragen` }),
  "frage.antwort": (von) => ({ stufe: "leise", kategorie: "frage", titel: "Lovea", text: `${NAME[von]} hat die Frage des Tages beantwortet` }),
  "snap.aufnahme": (von, d) => ({
    stufe: "leise",
    kategorie: "chat",
    titel: "Lovea",
    text: `${NAME[von]} hat ${d.art === "bildschirmaufnahme" ? "den Bildschirm aufgenommen" : "einen Screenshot gemacht"}`,
  }),
  // Z-23.2: nur bei einem Geschenk (fuer != von) - ein Kauf fuer sich selbst loest keine Push aus.
  "shop.kauf": (von, d) => (d.fuer === von ? null : { stufe: "laut", kategorie: "shop", titel: "Lovea", text: `${NAME[von]} hat dir etwas geschenkt` }),
};

// Liefert die Push-Regel für eine Op, oder null, wenn diese Art keine Push
// auslöst. `kontext` ist optionaler, von raum.js nachgeschlagener Zusatzstoff
// (z. B. der Ortsname), damit diese Datei selbst reine Logik bleibt.
export function regel(art, von, d, kontext) {
  const f = TABELLE[art];
  if (!f) return null;
  return f(von, d, kontext);
}
