import Foundation

/// Z-32.2: FaceTime links from the partner's `kontakt.facetime` (phone number or Apple-ID mail).
enum FaceTime {
    /// Spaces, brackets and hyphens go, "+" stays; a mail address stays as typed. Empty → nil.
    static func url(audio: Bool, kontakt: String) -> URL? {
        let wert = kontakt.trimmingCharacters(in: .whitespacesAndNewlines)
        let ziel = wert.contains("@") ? wert : wert.filter { ($0.isASCII && $0.isNumber) || $0 == "+" }
        guard !ziel.isEmpty else { return nil }
        return URL(string: (audio ? "facetime-audio://" : "facetime://") + ziel)
    }

    /// The person's own entry; a Runde-2 `telefon` number still counts until they enter one.
    @MainActor
    static func kontakt(von person: Person) -> String {
        let eintrag = EinstellungenModell.shared.string("kontakt.facetime", default: "", von: person)
        return eintrag.isEmpty ? EinstellungenModell.shared.string("telefon", default: "", von: person) : eintrag
    }
}
