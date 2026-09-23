import SwiftUI

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

/// Einstellungen row (Z-32.2): the own FaceTime number or Apple ID, saved on submit and on leaving.
struct FaceTimeKontaktZeile: View {
    @State private var wert = ""
    @State private var geladen = false

    var body: some View {
        TextField("FaceTime (Nummer oder Apple-ID)", text: $wert)
            .textContentType(.telephoneNumber)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit(sichern)
            .onDisappear(perform: sichern)
            .onAppear {
                guard !geladen else { return }
                geladen = true
                wert = EinstellungenModell.shared.string("kontakt.facetime", default: "")
            }
    }

    private func sichern() {
        let neu = wert.trimmingCharacters(in: .whitespacesAndNewlines)
        guard geladen, neu != EinstellungenModell.shared.string("kontakt.facetime", default: "") else { return }
        EinstellungenModell.shared.setzen("kontakt.facetime", .string(neu))
    }
}
