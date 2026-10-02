import SwiftUI

// Platzhalter mit den festen Signaturen. Teil 3 (Ortssuche) ersetzt nur die Rümpfe.

struct OrtWahlZeile: View {
    @Binding var ort: PunktOrt?

    init(ort: Binding<PunktOrt?>) { _ort = ort }

    var body: some View {
        Text(ort?.name ?? "Ort wählen")
    }
}

struct OrtVorschau: View {
    let ort: PunktOrt

    init(ort: PunktOrt) { self.ort = ort }

    var body: some View {
        Text(ort.name)
    }
}
