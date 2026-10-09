// Übungskatalog (Lovea/Sources/Health/uebungen.json) für die Gym-Auswertung des Coachs.
// Lazy per dynamischem Import: der Worker lädt die ~350 KB erst bei der ersten Coach-Anfrage.
let geladen;
export function katalog() {
  geladen ??= import("../Lovea/Sources/Health/uebungen.json", { with: { type: "json" } }).then((m) => ({ nachId: new Map(m.default.map((u) => [u.id, u])) }));
  return geladen;
}
