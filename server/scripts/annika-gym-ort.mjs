// One-off data fix (kein Feature, keine UI): legt Annikas Gym "Absolut Fit and Dance" als
// `Ort` an, per POST /ops (Z-1.9 Umzugs-Endpunkt, siehe raum.js #opsBatch / opGueltig).
//
// Koordinaten: Nominatim-POI-Suche nach dem Namen fand nichts. Adresssuche (frei und
// strukturiert street=/postalcode=/city=) fuer Hausnummer 22-24 loeste ebenfalls nichts auf,
// Overpass-Suche nach leisure=fitness_centre und nach addr:housenumber 22|24 im Umkreis fand
// keine Treffer. Einzig verwertbares Ergebnis bleibt die Strassenmitte (Fallback aus der
// Aufgabe): 50.9158711, 6.1459052. Die Strasse ist laut Nominatim-Bounding-Box rund 670 m lang,
// die Mitte trifft die Hausnummer 22-24 also nicht zuverlaessig -- Radius deshalb auf 350 m
// statt der sonst ueblichen 100 m gesetzt, um den echten Standort mit abzudecken.
//
// Aufruf: node server/scripts/annika-gym-ort.mjs <https://lovea-live....workers.dev>
// Braucht den Worker-Schluessel in der Umgebungsvariable LOVEA_APP_KEY (nie ausgeben/loggen).
// Feste ids (`fix:annika-gym` / `annika-gym`): ein zweiter Lauf ueberschreibt denselben Ort
// (INSERT OR IGNORE bei gleicher Op-id, ort.setzen ist idempotent ueber die Ort-id) statt einen
// zweiten Gym-Eintrag anzulegen.
const basisUrl = process.argv[2];
if (!basisUrl) {
  console.error("Aufruf: node server/scripts/annika-gym-ort.mjs <https://lovea-live....workers.dev>");
  process.exit(1);
}
const schluessel = process.env.LOVEA_APP_KEY;
if (!schluessel) {
  console.error("LOVEA_APP_KEY ist nicht gesetzt.");
  process.exit(1);
}

const ort = {
  id: "annika-gym",
  person: "annika",
  name: "Absolut Fit and Dance",
  kategorie: "gym",
  lat: 50.9158711,
  lon: 6.1459052,
  radius: 350,
  melden: "beides",
};

const op = { id: "fix:annika-gym", art: "ort.setzen", von: "annika", zeit: new Date().toISOString(), d: ort };

const res = await fetch(`${basisUrl}/ops`, {
  method: "POST",
  headers: { "X-Lovea-Key": schluessel, "X-Lovea-Person": "annika", "content-type": "application/json" },
  body: JSON.stringify({ ops: [op] }),
});
const body = res.ok ? await res.json() : null;
if (!res.ok || !body || body.uebersprungen > 0) {
  console.error(`POST /ops fehlgeschlagen: status=${res.status} body=${JSON.stringify(body)}`);
  process.exit(1);
}
console.log(`ort.setzen gesendet: ${ort.name} (${ort.id}), seq=${body.seq}`);
