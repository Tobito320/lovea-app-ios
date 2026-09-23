import SwiftUI

/// Spec 8.1 Nr. 4 / 8.4: nur am Morgen nach einem Treffen (7 Tage lang), zum Bewerten des
/// Partners, wegwischbar. Wertung trägt die Figur einen Tag als Abzeichen (Block 7/Figuren liest
/// dafür `KalenderModell.zustand.puenktlich`, hier wird nur die Op gesendet).
struct PuenktlichCard: View {
    let kalender = KalenderModell.shared
    @State private var versatz: CGFloat = 0

    var body: some View {
        if let kandidat = kalender.puenktlichKandidat() {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wie pünktlich war \(kandidat.ueber.name) gestern?")
                    .font(.headline)
                HStack(spacing: 12) {
                    wertungsKnopf(kandidat, wert: "uhrwerk", zustand: .pokal, titel: "Schweizer Uhrwerk")
                    wertungsKnopf(kandidat, wert: "charmant", zustand: .lacht, titel: "Knapp aber charmant")
                    wertungsKnopf(kandidat, wert: "troedel", zustand: .ruhig, titel: kandidat.ueber == .annika ? "Trödelkönigin" : "Trödelkönig")
                }
                Text("Wegwischen zum Überspringen")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .offset(x: versatz)
            .opacity(Double(1 - min(abs(versatz) / 200, 1)))
            .gesture(
                DragGesture()
                    .onChanged { versatz = $0.translation.width }
                    .onEnded { wert in
                        if abs(wert.translation.width) > 100 {
                            wegwischen(kandidat)
                        } else {
                            withAnimation { versatz = 0 }
                        }
                    }
            )
        }
    }

    private func wertungsKnopf(_ kandidat: (datum: String, ueber: Person), wert: String, zustand: FigurZustand, titel: String) -> some View {
        Button {
            Raum.shared.senden("puenktlich.setzen", PuenktlichEintrag(datum: kandidat.datum, ueber: kandidat.ueber, wert: wert))
        } label: {
            VStack(spacing: 6) {
                FigurView(FigurenModell.shared.aussehen(kandidat.ueber), zustand: zustand, groesse: 72)
                Text(titel)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func wegwischen(_ kandidat: (datum: String, ueber: Person)) {
        Raum.shared.senden("puenktlich.setzen", PuenktlichEintrag(datum: kandidat.datum, ueber: kandidat.ueber, wert: "weg"))
        withAnimation { versatz = 500 }
    }
}
