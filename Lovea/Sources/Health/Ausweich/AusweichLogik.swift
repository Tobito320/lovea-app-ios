import Foundation

/// Kuratierte Alternativen (`ausweich.json`): Alle Wörter von `muster` müssen im normalisierten
/// Übungsnamen stehen, keines von `ohne`. `alternativen` sind Katalog-ids.
struct AusweichEintrag: Codable, Equatable, Sendable {
    let muster: [String]
    var ohne: [String]? = nil
    let alternativen: [String]

    func passt(_ name: String) -> Bool {
        let n = UebungsKatalog.normal(name)
        return muster.allSatisfy { n.contains(UebungsKatalog.normal($0)) }
            && !(ohne ?? []).contains { n.contains(UebungsKatalog.normal($0)) }
    }
}

/// "Gerät besetzt?": 1 bis 2 Alternativen mit gleicher Hauptmuskelgruppe, bevorzugt an einem anderen
/// Gerät, und der Tausch im laufenden Training. Der Tausch ändert nur die Katalog-Übung des Laufs;
/// Plan-Id und `ersatzFuer` halten die Zuordnung (`TrainingLogik.session`).
enum AusweichLogik {
    static let hoechstens = 2

    /// `Bundle(for:)` statt `.main`: im XCTest ist `.main` leer.
    static let eintraege: [AusweichEintrag] = laden(Bundle(for: AusweichMarke.self))

    static func laden(_ bundle: Bundle) -> [AusweichEintrag] {
        guard let url = bundle.url(forResource: "ausweich", withExtension: "json")
                ?? bundle.url(forResource: "ausweich", withExtension: "json", subdirectory: "Health/Ausweich"),
              let daten = try? Data(contentsOf: url),
              let liste = try? JSONDecoder().decode([AusweichEintrag].self, from: daten) else { return [] }
        return liste
    }

    /// Welches Gerät zuerst kommt, wenn der Katalog automatisch wählt.
    private static let geraeteRang = ["Kurzhantel", "Maschine", "Kabelzug", "Langhantel", "Multipresse", "Körpergewicht"]

    /// Die Alternativen zu `u`: erst die kuratierten (gleicher `muskel`, nicht `u` selbst, anderes Gerät
    /// zuerst), dann aus dem Katalog nach gleichem `muskel` und anderem `geraet`. Immer dieselbe
    /// Reihenfolge. Cardio und eigene Übungen: keine.
    static func alternativen(fuer u: Uebung, eintraege: [AusweichEintrag] = AusweichLogik.eintraege, katalog: [Uebung] = UebungsKatalog.alle) -> [Uebung] {
        guard !u.istCardio, u.id != PlanUebung.eigen else { return [] }
        let name = UebungsKatalog.normal(u.name)
        func zulaessig(_ a: Uebung) -> Bool {
            a.id != u.id && a.muskel == u.muskel && !a.istCardio && UebungsKatalog.normal(a.name) != name
        }
        var liste: [Uebung] = []
        func nehmen(_ a: Uebung) {
            if zulaessig(a), !liste.contains(where: { $0.id == a.id }) { liste.append(a) }
        }
        if let e = eintraege.first(where: { $0.passt(u.name) }) {
            let kuratiert = e.alternativen.compactMap { id in katalog.first { $0.id == id } }.filter(zulaessig)
            (kuratiert.filter { $0.geraet != u.geraet } + kuratiert.filter { $0.geraet == u.geraet }).forEach(nehmen)
        }
        if liste.count < hoechstens {
            let rest = katalog.filter { zulaessig($0) && $0.geraet != u.geraet && !liste.contains($0) }
                .sorted { Self.vor($0, $1) }
            var gesehen = Set(liste.map(\.geraet))
            for a in rest where gesehen.insert(a.geraet).inserted { nehmen(a) }
            for a in rest { nehmen(a) }
        }
        return Array(liste.prefix(hoechstens))
    }

    private static func vor(_ a: Uebung, _ b: Uebung) -> Bool {
        let ra = geraeteRang.firstIndex(of: a.geraet) ?? geraeteRang.count
        let rb = geraeteRang.firstIndex(of: b.geraet) ?? geraeteRang.count
        if ra != rb { return ra < rb }
        if a.name.count != b.name.count { return a.name.count < b.name.count }
        if a.name != b.name { return a.name < b.name }
        return a.id < b.id
    }

    /// Tauschen geht nur vor dem ersten Haken, nicht bei Cardio und nicht bei eigenen Übungen.
    static func tauschbar(_ u: WorkoutUebung, saetze: [PlanSatz]) -> Bool {
        !u.planUebung.istCardio && u.planUebung.uebung != PlanUebung.eigen && u.planUebung.katalog != nil
            && !saetze.contains { $0.ok == true }
    }

    /// Die ursprüngliche Plan-Übung, nach einem Tausch auch über `ersatzFuer`.
    static func original(_ u: WorkoutUebung) -> String { u.ersatzFuer ?? u.planUebung.uebung }

    /// Die Satzzeilen nach dem Tausch: gleiche Anzahl und Typen, Gewicht und Wiederholungen aus der
    /// letzten Einheit der neuen Übung (`vorher`). Ohne Vorgeschichte kein Gewicht, ein anderes Gerät
    /// verträgt nicht dasselbe.
    static func saetzeNachTausch(_ aktuell: [PlanSatz], vorher: [PlanSatz]) -> [PlanSatz] {
        aktuell.enumerated().map { i, s in
            var neu = s.alsPlan
            if vorher.indices.contains(i) {
                neu.kg = vorher[i].kg
                neu.wdh = vorher[i].wdh
            } else {
                neu.kg = nil
            }
            return neu
        }
    }
}

private final class AusweichMarke {}
