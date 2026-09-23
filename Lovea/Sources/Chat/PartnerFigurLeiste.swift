import SwiftUI

/// Partner figure above the input, shown while the partner is doing something chat-shaped
/// (Spec 4.2, Z-4.5). Slides in and out as that stops being true.
struct PartnerFigurLeiste: View {
    let partner: Person

    private static let sichtbareZustaende: Set<FigurZustand> = [.imChat, .tippt, .kamera, .sprache, .liest, .schautBild, .schautVideo]

    private var zustand: FigurenModell.Zustand? {
        let z = FigurenModell.shared.anzeige(partner)
        return Self.sichtbareZustaende.contains(z.haupt) ? z : nil
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if let zustand {
                HStack(spacing: 8) {
                    FigurView(FigurenModell.shared.aussehen(partner), zustand: zustand.haupt, abzeichen: zustand.abzeichen, groesse: 44)
                    Text(zustand.haupt.titel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                // One element: figure + its state as text, not "Figur" followed by the same state twice.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(partner.name): \(zustand.haupt.titel)")
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: zustand?.haupt)
    }
}
