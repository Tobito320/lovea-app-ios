import Foundation

/// Holt Ops ab, die `GymHeuteIntent` (`LoveaWidgets`) in die App Group geschrieben hat, weil der
/// direkte `POST /ops` fehlschlug oder die Erweiterung beendet wurde, bevor er bestätigt war
/// (Z-28.3). Läuft bei jedem `.active` (nicht nur beim Start) und nach `Raum.shared.start()`.
@MainActor
enum WidgetPendingOpsMerge {
    static func abholen() {
        guard let ordner = WidgetGruppe.pendingOrdner() else { return }
        Task { @MainActor in
            let (pendings, dateien) = await Self.gelesen(ordner)
            for pending in WidgetPendingMerge.eindeutig(pendings) {
                guard let op = Self.op(aus: pending) else { continue }
                Raum.shared.einreihen(op)
            }
            // Minor 7: erst löschen, wenn die Ops wirklich in der Warteschlange auf der Platte liegen
            // (`einreihen` schreibt über die Arbeitskette) — ein Kill dazwischen verlöre sonst den Tipp.
            await Raum.shared.leer()
            for datei in dateien { try? FileManager.default.removeItem(at: datei) }
        }
    }

    private static func gelesen(_ ordner: URL) async -> (pendings: [WidgetPendingOp], dateien: [URL]) {
        await Task.detached(priority: .utility) {
            guard let dateien = try? FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil) else {
                return ([], [])
            }
            let pendings = dateien.compactMap { url -> WidgetPendingOp? in
                guard let daten = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(WidgetPendingOp.self, from: daten)
            }
            return (pendings, dateien)
        }.value
    }

    /// Baut denselben Op-`d`-Body wie `HealthModell`s privates `HabitD` (`{art,datum,wert}`,
    /// schnittstellen.md) — bewusst eine eigene, winzige Kopie statt `HealthModell` anzufassen
    /// (E-Territorium), siehe common.md.
    private static func op(aus pending: WidgetPendingOp) -> Op? {
        guard let von = Person(rawValue: pending.von) else { return nil }
        struct HabitD: Codable { var art: String; var datum: String; var wert: Int }
        guard let d = try? JSONEncoder().encode(HabitD(art: pending.habit ?? "gym", datum: pending.datum, wert: pending.wert)) else { return nil }
        let zeit = Self.isoDatum(pending.zeit) ?? Date()
        return Op(id: pending.id, seq: nil, art: "habit.setzen", von: von, zeit: zeit, d: d)
    }

    private static func isoFormatierer(fraktional: Bool) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = fraktional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f
    }

    private static func isoDatum(_ text: String) -> Date? {
        isoFormatierer(fraktional: true).date(from: text) ?? isoFormatierer(fraktional: false).date(from: text)
    }
}
