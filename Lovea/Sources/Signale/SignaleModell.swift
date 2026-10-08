import Foundation
import Observation

/// Welches Blatt die Signale-Ebene im Zimmer gerade zeigt. Der Zustand liegt im Profil (`ProfilInhalt`),
/// je Profil-Ansicht einer: Tab und Partner-Sheet leben gleichzeitig und dürfen nicht beide präsentieren.
enum SignaleBlatt: Identifiable, Hashable {
    case stimmung, brief(Brief), liebesbrief, zettel, geschenke

    var id: String {
        switch self {
        case .stimmung: "stimmung"
        case .brief(let b): "brief-" + b.id
        case .liebesbrief: "liebesbrief"
        case .zettel: "zettel"
        case .geschenke: "geschenke"
        }
    }
}

/// Stand der Paar-Signale (Stimmung, Geschenkbox). Gespeichert wird im Op-Log wie bei den Briefen,
/// `Raum.beobachtenStapel` spielt beim ersten Zugriff alles ein. Nichts läuft von allein.
@MainActor @Observable
final class SignaleSpeicher {
    static let shared = SignaleSpeicher()

    private(set) var stand = SignaleStand()

    @ObservationIgnored private let wer: () -> Person?
    @ObservationIgnored private let senden: (Op) -> Void

    init(ich: @escaping () -> Person?, senden: @escaping (Op) -> Void) {
        self.wer = ich
        self.senden = senden
    }

    private convenience init() {
        self.init(ich: { Raum.shared.ich }, senden: { Raum.shared.einreihen($0) })
        Raum.shared.beobachtenStapel(SignaleLogik.arten) { [weak self] ops in self?.einarbeiten(ops) }
    }

    func einarbeiten(_ ops: [Op]) { stand = SignaleLogik.anwenden(ops, auf: stand) }

    var ich: Person? { wer() }

    // MARK: Stimmung

    func stimmung(von person: Person, jetzt: Date = Date()) -> Stimmung? {
        SignaleLogik.stimmung(stand, von: person, jetzt: jetzt)
    }

    /// Setzt die eigene Stimmung, `nil` nimmt die Blase wieder weg.
    func stimmungSetzen(_ art: Stimmung?) {
        guard let ich = wer() else { return }
        absenden(Op.neu(SignaleLogik.artStimmung, SignaleLogik.StimmungD(art: art?.rawValue), von: ich))
    }

    // MARK: Geschenkbox (nur ich sehe meine Einträge, der Server liefert sie nie an die andere Person)

    var geschenke: [Geschenk] { wer().map { SignaleLogik.geschenke(stand, von: $0) } ?? [] }

    @discardableResult
    func geschenkMerken(_ eingabe: String) -> Bool {
        guard let text = SignaleLogik.kurz(eingabe, hoechstens: SignaleLogik.geschenkMaxZeichen), let ich = wer() else { return false }
        absenden(Op.neu(SignaleLogik.artGeschenk, SignaleLogik.GeschenkD(id: "gb-" + UUID().uuidString, text: text, erledigt: false), von: ich))
        return true
    }

    /// Hakt eine Idee ab ("schon geschenkt") oder macht den Haken wieder weg.
    func geschenkAbhaken(_ g: Geschenk) {
        guard let ich = wer(), g.von == ich else { return }
        absenden(Op.neu(SignaleLogik.artGeschenk, SignaleLogik.GeschenkD(id: g.id, text: g.text, erledigt: !g.erledigt), von: ich))
    }

    func geschenkLoeschen(_ g: Geschenk) {
        guard let ich = wer(), g.von == ich else { return }
        absenden(Op.neu(SignaleLogik.artGeschenkWeg, SignaleLogik.GeschenkWegD(id: g.id), von: ich))
    }

    private func absenden(_ op: Op) {
        stand = SignaleLogik.anwenden([op], auf: stand)
        senden(op)
    }
}
