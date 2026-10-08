import Foundation
import Observation
import SwiftUI

/// p69 (48): which new kinds of sync op this build understands, told to the partner.
/// An old build ignores a kind of op it does not know. `figur.aussehenFuer` (p68, Ahmed changes Annika's figure)
/// is such a kind: on an old phone the change simply never shows and nothing says why. A build that knows the
/// kind sends `app.kann` (the list in `eigene`) once, and again whenever the list grows; an old build never
/// sends it. So a partner without the list is on an old build.
/// The op log is never trimmed, so it goes out once per change of the list, not once per start.
@MainActor @Observable
final class AppKann {
    static let shared = AppKann()
    nonisolated static let art = "app.kann"
    nonisolated static let figurFuerPartner = "figur.aussehenFuer"
    /// Kinds of op this build understands that older builds ignore. Add one with every new kind that has to
    /// reach the partner.
    nonisolated static let eigene = [figurFuerPartner]

    struct Liste: Codable, Sendable, Equatable { var kann: [String] }

    /// The list each person last told us (kept on the phone too, so the answer is there before the log is read).
    private(set) var vonPerson: [Person: [String]] = [:]

    private init() {
        for p in Person.allCases {
            if let liste = UserDefaults.standard.stringArray(forKey: Self.schluessel(p)) { vonPerson[p] = liste }
        }
        Raum.shared.beobachten([Self.art]) { [weak self] op in
            guard let kann = op.daten(Liste.self)?.kann else { return }
            self?.gelernt(op.von, kann)
        }
    }

    private static func schluessel(_ p: Person) -> String { "appKann.\(p.rawValue)" }
    private static let gesendetSchluessel = "appKann.gesendet"

    private func gelernt(_ p: Person, _ kann: [String]) {
        vonPerson[p] = kann
        UserDefaults.standard.set(kann, forKey: Self.schluessel(p))
    }

    /// Tells the partner what this build can do, when that differs from what was told last.
    func melden() {
        guard UserDefaults.standard.stringArray(forKey: Self.gesendetSchluessel) != Self.eigene else { return }
        Raum.shared.senden(Self.art, Liste(kann: Self.eigene))
        UserDefaults.standard.set(Self.eigene, forKey: Self.gesendetSchluessel)
    }

    /// Pure: no list at all means an old build.
    nonisolated static func versteht(_ kann: [String]?, _ art: String) -> Bool { kann?.contains(art) ?? false }

    /// Pure: the notice for Ahmed about a partner who cannot take over his change, nil when she can.
    nonisolated static func updateHinweis(_ p: Person, kann: [String]?) -> String? {
        versteht(kann, figurFuerPartner) ? nil : "\(p.name) hat noch die alte App und sieht deine Änderung erst nach dem Update. Bitte sag ihr: updaten."
    }

    func updateHinweis(_ p: Person) -> String? { Self.updateHinweis(p, kann: vonPerson[p]) }
}

/// p69 (48): the notice under "Figur" and "Kleidung" on the partner's profile.
struct AppKannHinweis: View {
    let person: Person

    var body: some View {
        if let text = AppKann.shared.updateHinweis(person) {
            Label(text, systemImage: "arrow.down.app")
                .font(.footnote)
                .foregroundStyle(.orange)
                .padding(.horizontal, 4)
        }
    }
}
