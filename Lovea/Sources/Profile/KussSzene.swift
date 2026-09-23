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
            if kuesst {
                if let bild = UIImage(named: "kuss-szene") {
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                if !reduceMotion { SteigendeHerzen().transition(.opacity) }
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
                for k in 0..<12 {
                    let p = (t * 0.32 + Double(k) / 12).truncatingRemainder(dividingBy: 1)
                    let basis = groesse.width * (0.25 + 0.5 * Double((k * 37) % 10) / 10)
                    let x = basis + sin(t * 2.2 + Double(k)) * 10
                    let herz = g.resolve(Text(Image(systemName: "heart.fill"))
                        .font(.system(size: CGFloat(16 + (k * 7) % 16)))
                        .foregroundColor(k % 3 == 0 ? .red : .pink))
                    g.opacity = 1 - p
                    g.draw(herz, at: CGPoint(x: x, y: groesse.height * (0.85 - 0.8 * p)))
                }
            }
        }
    }
}
