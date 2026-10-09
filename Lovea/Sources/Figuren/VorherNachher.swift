import SwiftUI

/// p71: Vorher/Nachher als Schieberegler. Links vom Griff steht der Look vor der Änderung, rechts der neue.
/// Ahmed sieht so, was er an Annikas Figur ändert, bevor er sichert.
struct VorherNachherView: View {
    let vorher: FigurAussehen
    let nachher: FigurAussehen
    var groesse: CGFloat = 290
    @State private var anteil: CGFloat

    init(vorher: FigurAussehen, nachher: FigurAussehen, groesse: CGFloat = 290, anteil: CGFloat = 0.5) {
        self.vorher = vorher
        self.nachher = nachher
        self.groesse = groesse
        _anteil = State(initialValue: anteil)
    }

    var body: some View {
        GeometryReader { geo in
            let breite = geo.size.width
            let x = breite * anteil
            ZStack(alignment: .topLeading) {
                figur(vorher, geo.size)
                figur(nachher, geo.size)
                    .mask(alignment: .trailing) { Rectangle().frame(width: breite - x) }
                Rectangle()
                    .fill(.white)
                    .frame(width: 3, height: geo.size.height)
                    .shadow(color: .black.opacity(0.35), radius: 2)
                    .offset(x: x - 1.5)
                Image(systemName: "arrow.left.and.right.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white, Color.black.opacity(0.55))
                    .shadow(radius: 2)
                    .offset(x: x - 17, y: geo.size.height / 2 - 17)
                beschriftung("Vorher").offset(x: 12, y: 8)
                beschriftung("Nachher").frame(width: breite - 12, alignment: .trailing).offset(y: 8)
            }
            .frame(width: breite, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { w in
                anteil = min(max(w.location.x / max(breite, 1), 0.02), 0.98)
            })
        }
        .frame(height: groesse)
        .accessibilityElement()
        .accessibilityLabel("Vorher und nachher")
        .accessibilityValue("\(Int((anteil * 100).rounded())) Prozent vorher")
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: anteil = min(anteil + 0.1, 0.98)
            case .decrement: anteil = max(anteil - 0.1, 0.02)
            @unknown default: break
            }
        }
    }

    private func figur(_ a: FigurAussehen, _ groesseGesamt: CGSize) -> some View {
        FigurView(a, zustand: .ruhig, groesse: groesse, animiert: false, ganzkoerper: true)
            .frame(width: groesseGesamt.width, height: groesseGesamt.height, alignment: .top)
    }

    private func beschriftung(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: Capsule())
    }
}
