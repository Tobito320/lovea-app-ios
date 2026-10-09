import SwiftUI

// MARK: - Previews

private func variante(_ a: FigurAussehen, _ k: WritableKeyPath<FigurAussehen, Int>, _ n: Int) -> FigurAussehen {
    var b = a
    b[keyPath: k] = n
    return b
}

private struct AlleOptionenVorschau: View {
    var body: some View {
        let basis = FigurAussehen.standard(for: .annika)
        let reihen: [(String, WritableKeyPath<FigurAussehen, Int>, Int, Bool)] = [
            ("Gesichtsform", \.gesichtsform, FigurAussehen.gesichtsformen.count, false),
            ("Haut", \.haut, FigurAussehen.hautToene.count, false),
            ("Frisur", \.frisur, FigurAussehen.frisuren.count, false),
            ("Haarfarbe", \.haarfarbe, FigurAussehen.haarfarben.count, false),
            ("Augenform", \.augenform, FigurAussehen.augenformen.count, false),
            ("Augenbrauen", \.brauen, FigurAussehen.augenbrauen.count, false),
            ("Nase", \.nase, FigurAussehen.nasen.count, false),
            ("Mund", \.mund, FigurAussehen.muender.count, false),
            ("Brille", \.brille, FigurAussehen.brillen.count, false),
            ("Bart", \.bart, FigurAussehen.baerte.count, false),
            ("Ohrringe", \.ohrringe, FigurAussehen.ohrringArten.count, false),
            ("Kopfbedeckung", \.kopfbedeckung, FigurAussehen.kopfbedeckungen.count, false),
            ("Oberteil", \.oberteil, FigurAussehen.oberteile.count, true),
            ("Jacke", \.jacke, FigurAussehen.jacken.count, true),
            ("Hose", \.hose, FigurAussehen.hosen.count, true),
            ("Schuhe", \.schuhe, FigurAussehen.schuhArten.count, true),
            ("Körperform", \.koerperform, FigurAussehen.koerperformen.count, true),
            ("Größe", \.groesse, FigurAussehen.groessen.count, true),
        ]
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(reihen.indices, id: \.self) { i in
                    Text(reihen[i].0).font(.headline)
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(0..<reihen[i].2, id: \.self) { n in
                                FigurView(variante(basis, reihen[i].1, n), zustand: .ruhig, groesse: reihen[i].3 ? 160 : 96, animiert: false, ganzkoerper: reihen[i].3)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Aussehen-Optionen") {
    AlleOptionenVorschau()
}

#Preview("Alle Zustände") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 16) {
            ForEach(FigurZustand.allCases, id: \.self) { z in
                VStack {
                    FigurView(.standard(for: .ahmed), zustand: z, groesse: 132)
                    Text(z.titel).font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("Ganzkörper") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
            ForEach(FigurZustand.allCases, id: \.self) { z in
                VStack {
                    FigurView(.standard(for: .annika), zustand: z, groesse: 200, ganzkoerper: true)
                    Text(z.titel).font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview("Abzeichen") {
    HStack {
        FigurView(.standard(for: .annika), zustand: .gut, abzeichen: ["partyhut", "herzaugen"], groesse: 220)
        FigurView(.standard(for: .ahmed), zustand: .ruhig, abzeichen: ["outfit", "uhrwerk", "krone"], groesse: 220)
    }
}
