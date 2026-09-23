import SwiftUI

/// Z-40.3: solange einer der beiden gerade küsst (dasselbe 4-s-Fenster wie die Figuren-Animation,
/// auch beim nachgeholten Kuss), blendet über dem Figurenpaar die gezeichnete Szene `kuss-szene`
/// ein und Herzen steigen. Fehlt das Bild, bleibt es bei der bisherigen Figuren-Animation.
struct KussSzene: View {
    let person: Person
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let modell = FigurenModell.shared
        let kuesst = modell.anzeige(person).haupt == .kuss || modell.anzeige(person.partner).haupt == .kuss
        ZStack {
            if kuesst, let bild = UIImage(named: "kuss-szene") {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                if !reduceMotion { SteigendeHerzen() }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: kuesst)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SteigendeHerzen: View {
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { kontext in
            let t = kontext.date.timeIntervalSince(start)
            Canvas { g, groesse in
                let herz = g.resolve(Text(Image(systemName: "heart.fill")).foregroundColor(.pink))
                for k in 0..<8 {
                    let p = (t * 0.35 + Double(k) / 8).truncatingRemainder(dividingBy: 1)
                    let x = groesse.width * (0.2 + 0.6 * Double((k * 37) % 10) / 10)
                    g.opacity = 1 - p
                    g.draw(herz, at: CGPoint(x: x, y: groesse.height * (1 - p)))
                }
            }
        }
    }
}
