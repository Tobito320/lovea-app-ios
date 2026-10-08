import SwiftUI

/// Kleiner Herzregen über der ganzen App, wenn ein "Denk an dich" ankommt oder gesendet wird
/// (`FigurenModell.herzEreignis`). Fasst nichts an (`allowsHitTesting(false)`), läuft nur in der
/// Vordergrund-App, ein Durchlauf dauert gut zwei Sekunden und räumt sich danach selbst weg.
struct HerzRegen: View {
    private struct Welle: Identifiable { let id = UUID() }

    @State private var wellen: [Welle] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(wellen) { _ in HerzWelle() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: FigurenModell.shared.herzEreignis) { _, _ in
            guard !reduceMotion else { return }
            let welle = Welle()
            wellen.append(welle)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                wellen.removeAll { $0.id == welle.id }
            }
        }
    }
}

private struct HerzWelle: View {
    private struct Herz: Identifiable {
        let id = UUID()
        let versatz: CGFloat
        let groesse: CGFloat
        let verzoegerung: Double
    }

    @State private var oben = false
    @State private var herzen: [Herz] = (0..<9).map { _ in
        Herz(versatz: CGFloat.random(in: -140...140), groesse: CGFloat.random(in: 18...34), verzoegerung: Double.random(in: 0...0.5))
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(herzen) { herz in
                Image(systemName: "heart.fill")
                    .font(.system(size: herz.groesse))
                    .foregroundStyle(Color.loveaRose)
                    .position(x: geo.size.width / 2 + herz.versatz, y: oben ? geo.size.height * 0.3 : geo.size.height * 0.85)
                    .opacity(oben ? 0 : 0.95)
                    .animation(.easeOut(duration: 2.2).delay(herz.verzoegerung), value: oben)
            }
        }
        .onAppear { oben = true }
    }
}
