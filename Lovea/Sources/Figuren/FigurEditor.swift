import SwiftUI

/// Bitmoji-style figure builder: big live full-body preview (zooms to the head for face categories),
/// category bar, option tiles drawn with the figure itself, color swatches, dice. The caller sends `figur.aussehen` in `onSave`.
struct FigurEditor: View {
    private let onSave: (FigurAussehen) -> Void
    @State private var aussehen: FigurAussehen
    @State private var kategorie = Kategorie.gesicht
    @State private var wuerfe = 0

    init(start: FigurAussehen, onSave: @escaping (FigurAussehen) -> Void) {
        _aussehen = State(initialValue: start)
        self.onSave = onSave
    }

    private static let akzent = Color(red: 1, green: 59 / 255, blue: 92 / 255)

    /// How an option tile shows the figure.
    fileprivate enum Kachel { case gesicht, kopf, koerper, koerperMitName }

    fileprivate struct Farbwahl {
        let name: String
        let farbe: FigurFarbe
        var straehne: FigurFarbe? = nil
    }

    fileprivate enum Abschnitt {
        case optionen(String, WritableKeyPath<FigurAussehen, Int>, [String], Kachel)
        case farben(String, WritableKeyPath<FigurAussehen, Int>, [Farbwahl])
        case schalter(String, WritableKeyPath<FigurAussehen, Bool>)
    }

    fileprivate enum Kategorie: String, CaseIterable, Identifiable {
        case gesicht = "Gesicht", haare = "Haare", augen = "Augen", bart = "Bart"
        case oberteil = "Oberteil", jacke = "Jacke", hose = "Hose", schuhe = "Schuhe"
        case accessoires = "Accessoires", koerper = "Körper"

        var id: String { rawValue }

        var zoomt: Bool {
            switch self {
            case .gesicht, .haare, .augen, .bart, .accessoires: true
            default: false
            }
        }

        var abschnitte: [Abschnitt] {
            typealias A = FigurAussehen
            let kleidung = A.farben.map { Farbwahl(name: $0.name, farbe: $0.farbe) }
            switch self {
            case .gesicht:
                return [
                    .optionen("Gesichtsform", \.gesichtsform, A.gesichtsformen, .gesicht),
                    .farben("Hautton", \.haut, A.hautToene.map { Farbwahl(name: $0.name, farbe: $0.farbe) }),
                    .optionen("Nase", \.nase, A.nasen, .gesicht),
                    .optionen("Mund", \.mund, A.muender, .gesicht),
                    .schalter("Sommersprossen", \.sommersprossen),
                    .schalter("Muttermal", \.muttermal),
                    .schalter("Rouge", \.rouge),
                ]
            case .haare:
                return [
                    .optionen("Frisur", \.frisur, A.frisuren, .kopf),
                    .farben("Haarfarbe", \.haarfarbe, A.haarfarben.map { Farbwahl(name: $0.name, farbe: $0.farbe, straehne: $0.straehne) }),
                ]
            case .augen:
                return [
                    .optionen("Augenform", \.augenform, A.augenformen, .gesicht),
                    .farben("Augenfarbe", \.augen, A.augenfarben.map { Farbwahl(name: $0.name, farbe: $0.farbe) }),
                    .optionen("Augenbrauen", \.brauen, A.augenbrauen, .gesicht),
                    .schalter("Wimpern", \.wimpern),
                ]
            case .bart:
                return [.optionen("Bart", \.bart, A.baerte, .gesicht)]
            case .oberteil:
                return [.optionen("Oberteil", \.oberteil, A.oberteile, .koerper), .farben("Farbe", \.oberteilfarbe, kleidung)]
            case .jacke:
                return [.optionen("Jacke", \.jacke, A.jacken, .koerper), .farben("Farbe", \.jackenfarbe, kleidung)]
            case .hose:
                return [.optionen("Hose oder Rock", \.hose, A.hosen, .koerper), .farben("Farbe", \.hosenfarbe, kleidung)]
            case .schuhe:
                return [.optionen("Schuhe", \.schuhe, A.schuhArten, .koerper), .farben("Farbe", \.schuhfarbe, kleidung)]
            case .accessoires:
                return [
                    .optionen("Brille", \.brille, A.brillen, .gesicht),
                    .optionen("Ohrringe", \.ohrringe, A.ohrringArten, .gesicht),
                    .optionen("Kopfbedeckung", \.kopfbedeckung, A.kopfbedeckungen, .kopf),
                    .farben("Farbe der Kopfbedeckung", \.muetzenfarbe, kleidung),
                ]
            case .koerper:
                return [
                    .optionen("Körperform", \.koerperform, A.koerperformen, .koerperMitName),
                    .optionen("Größe", \.groesse, A.groessen, .koerperMitName),
                ]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            vorschau
            kategorienLeiste
            Divider()
            let liste = kategorie.abschnitte
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(liste.indices, id: \.self) { i in
                        abschnitt(liste[i])
                    }
                }
                .padding()
            }
            .id(kategorie)
            Button {
                onSave(aussehen)
            } label: {
                Text("Figur sichern")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.akzent)
            .padding()
        }
        .sensoryFeedback(.selection, trigger: aussehen)
        .sensoryFeedback(.selection, trigger: kategorie)
        .sensoryFeedback(.impact(weight: .medium), trigger: wuerfe)
    }

    private var vorschau: some View {
        ZStack(alignment: .topTrailing) {
            FigurView(aussehen, zustand: .ruhig, groesse: 290, ganzkoerper: true)
                .scaleEffect(kategorie.zoomt ? 1.9 : 1, anchor: .top)
                .frame(maxWidth: .infinity)
                .frame(height: 290, alignment: .top)
                .padding(.top, 10)
                .clipped()
                .animation(.spring(duration: 0.45), value: kategorie)
                .accessibilityLabel("Vorschau deiner Figur")
            Button(action: zufall) {
                Image(systemName: "dice.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Self.akzent)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel("Zufälliger Look")
        }
        .background(LinearGradient(colors: [Self.akzent.opacity(0.16), Self.akzent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
    }

    private var kategorienLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Kategorie.allCases) { k in
                    Button(k.rawValue) {
                        withAnimation(.snappy) { kategorie = k }
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(k == kategorie ? Self.akzent.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                    .foregroundStyle(k == kategorie ? Self.akzent : Color.primary)
                    .accessibilityAddTraits(k == kategorie ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func abschnitt(_ a: Abschnitt) -> some View {
        switch a {
        case let .optionen(titel, pfad, namen, kachel):
            VStack(alignment: .leading, spacing: 10) {
                Text(titel).font(.headline)
                kacheln(pfad, namen, kachel)
            }
        case let .farben(titel, pfad, liste):
            VStack(alignment: .leading, spacing: 10) {
                Text(titel).font(.headline)
                farbReihe(pfad, liste)
            }
        case let .schalter(titel, pfad):
            Toggle(titel, isOn: $aussehen[dynamicMember: pfad])
                .font(.headline)
                .tint(Self.akzent)
        }
    }

    private func probe(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ i: Int) -> FigurAussehen {
        var a = aussehen
        a[keyPath: pfad] = i
        return a
    }

    private func kacheln(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ namen: [String], _ kachel: Kachel) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
            ForEach(namen.indices, id: \.self) { i in
                let gewaehlt = aussehen[keyPath: pfad] == i
                Button {
                    aussehen[keyPath: pfad] = i
                } label: {
                    VStack(spacing: 2) {
                        kachelBild(probe(pfad, i), kachel)
                        if kachel == .koerperMitName {
                            Text(namen[i]).font(.caption2.weight(.semibold)).padding(.bottom, 6)
                        }
                    }
                    .frame(width: 76, height: kachel == .gesicht || kachel == .kopf ? 92 : 128)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(gewaehlt ? Self.akzent : Color.clear, lineWidth: 3))
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(namen[i])
                .accessibilityAddTraits(gewaehlt ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func kachelBild(_ a: FigurAussehen, _ kachel: Kachel) -> some View {
        switch kachel {
        case .gesicht:
            FigurView(a, zustand: .ruhig, groesse: 92, animiert: false)
                .scaleEffect(1.9)
                .offset(y: 11)
                .frame(width: 76, height: 92)
                .clipped()
        case .kopf:
            FigurView(a, zustand: .ruhig, groesse: 92, animiert: false)
        case .koerper:
            FigurView(a, zustand: .ruhig, groesse: 120, animiert: false, ganzkoerper: true)
        case .koerperMitName:
            FigurView(a, zustand: .ruhig, groesse: 104, animiert: false, ganzkoerper: true)
        }
    }

    private func farbReihe(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ liste: [Farbwahl]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(liste.indices, id: \.self) { i in
                    let gewaehlt = aussehen[keyPath: pfad] == i
                    Button {
                        aussehen[keyPath: pfad] = i
                    } label: {
                        Circle()
                            .fill(liste[i].farbe.farbe)
                            .overlay {
                                if let s = liste[i].straehne {
                                    Circle().trim(from: 0.05, to: 0.3).stroke(s.farbe, lineWidth: 12)
                                }
                            }
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                            .frame(width: 38, height: 38)
                            .padding(4)
                            .overlay(Circle().strokeBorder(gewaehlt ? Self.akzent : Color.clear, lineWidth: 3))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(liste[i].name)
                    .accessibilityAddTraits(gewaehlt ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// New look: hair, clothes and accessories; face, skin and body stay.
    private func zufall() {
        typealias A = FigurAussehen
        func eins(_ n: Int) -> Int { Int.random(in: 0..<n) }
        func oftKeins(_ n: Int) -> Int { Bool.random() ? 0 : eins(n) }
        var a = aussehen
        a.frisur = eins(A.frisuren.count)
        a.haarfarbe = eins(A.haarfarben.count)
        a.oberteil = eins(A.oberteile.count)
        a.oberteilfarbe = eins(A.farben.count)
        a.jacke = oftKeins(A.jacken.count)
        a.jackenfarbe = eins(A.farben.count)
        a.hose = eins(A.hosen.count)
        a.hosenfarbe = eins(A.farben.count)
        a.schuhe = eins(A.schuhArten.count)
        a.schuhfarbe = eins(A.farben.count)
        a.kopfbedeckung = oftKeins(A.kopfbedeckungen.count)
        a.muetzenfarbe = eins(A.farben.count)
        a.brille = oftKeins(A.brillen.count)
        withAnimation(.snappy) { aussehen = a }
        wuerfe += 1
    }
}

#Preview("Editor") {
    FigurEditor(start: .standard(for: .annika)) { _ in }
}
