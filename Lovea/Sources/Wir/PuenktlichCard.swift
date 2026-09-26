import SwiftUI
import UIKit

/// Spec 8.1 Nr. 4 / 8.4: nur am Morgen nach einem Treffen (7 Tage lang), zum Bewerten des
/// Partners, wegwischbar. Wertung trägt die Figur einen Tag als Abzeichen (Block 7/Figuren liest
/// dafür `KalenderModell.zustand.puenktlich`, hier wird nur die Op gesendet).
struct PuenktlichCard: View {
    let kalender = KalenderModell.shared
    @State private var versatz: CGFloat = 0
    @Environment(\.dynamicTypeSize) private var schrift

    var body: some View {
        if let kandidat = kalender.puenktlichKandidat() {
            // Drei Figuren nebeneinander passen ab AX-Größen nicht mehr, dann untereinander.
            let reihe = schrift.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            VStack(alignment: .leading, spacing: 12) {
                Text("Wie pünktlich war \(kandidat.ueber.name) gestern?")
                    .font(.headline)
                reihe {
                    wertungsKnopf(kandidat, wert: "uhrwerk", zustand: .pokal, titel: "Schweizer Uhrwerk")
                    wertungsKnopf(kandidat, wert: "charmant", zustand: .lacht, titel: "Knapp aber charmant")
                    wertungsKnopf(kandidat, wert: "troedel", zustand: .ruhig, titel: kandidat.ueber == .annika ? "Trödelkönigin" : "Trödelkönig")
                }
                // Wischen allein reicht nicht (VoiceOver, Schalterbedienung): sichtbarer Knopf dazu.
                Button("Überspringen") { wegwischen(kandidat) }
                    .font(.footnote)
                    .frame(minHeight: 44)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .offset(x: versatz)
            .opacity(Double(1 - min(abs(versatz) / 200, 1)))
            // After a skip the next unrated meeting reuses this view; start it in place again.
            .onChange(of: kandidat.datum, initial: true) { versatz = 0 }
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Raum.shared.senden("puenktlich.setzen", PuenktlichEintrag(datum: kandidat.datum, ueber: kandidat.ueber, wert: wert))
        } label: {
            VStack(spacing: 6) {
                FigurView(FigurenModell.shared.aussehen(kandidat.ueber), zustand: zustand, groesse: 72, bildrate: 20)
                Text(titel)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titel)
    }

    private func wegwischen(_ kandidat: (datum: String, ueber: Person)) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        Raum.shared.senden("puenktlich.setzen", PuenktlichEintrag(datum: kandidat.datum, ueber: kandidat.ueber, wert: "weg"))
        withAnimation { versatz = 500 }
    }
}
