import SwiftUI

/// Figure builder with live preview. The caller sends `figur.aussehen` in `onSave`.
struct FigurEditor: View {
    private let onSave: (FigurAussehen) -> Void
    @State private var aussehen: FigurAussehen
    @State private var bereich = Bereich.haut

    init(start: FigurAussehen, onSave: @escaping (FigurAussehen) -> Void) {
        _aussehen = State(initialValue: start)
        self.onSave = onSave
    }

    private static let akzent = Color(red: 1, green: 59 / 255, blue: 92 / 255)

    fileprivate enum Bereich: String, CaseIterable, Identifiable {
        case haut = "Haut", frisur = "Frisur", haarfarbe = "Haarfarbe", augen = "Augen"
        case brille = "Brille", bart = "Bart", oberteil = "Oberteil", oberteilfarbe = "Farbe"

        var id: String { rawValue }

        var pfad: WritableKeyPath<FigurAussehen, Int> {
            switch self {
            case .haut: \.haut
            case .frisur: \.frisur
            case .haarfarbe: \.haarfarbe
            case .augen: \.augen
            case .brille: \.brille
            case .bart: \.bart
            case .oberteil: \.oberteil
            case .oberteilfarbe: \.oberteilfarbe
            }
        }

        var namen: [String] {
            switch self {
            case .haut: FigurAussehen.hautToene.map { $0.name }
            case .frisur: FigurAussehen.frisuren
            case .haarfarbe: FigurAussehen.haarfarben.map { $0.name }
            case .augen: FigurAussehen.augenfarben.map { $0.name }
            case .brille: FigurAussehen.brillen
            case .bart: FigurAussehen.baerte
            case .oberteil: FigurAussehen.oberteile
            case .oberteilfarbe: FigurAussehen.oberteilfarben.map { $0.name }
            }
        }

        var farben: [FigurFarbe]? {
            switch self {
            case .haut: FigurAussehen.hautToene.map { $0.farbe }
            case .haarfarbe: FigurAussehen.haarfarben.map { $0.farbe }
            case .augen: FigurAussehen.augenfarben.map { $0.farbe }
            case .oberteilfarbe: FigurAussehen.oberteilfarben.map { $0.farbe }
            default: nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            FigurView(aussehen, zustand: .gut, groesse: 200)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .accessibilityLabel("Vorschau deiner Figur")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Bereich.allCases) { b in
                        Button(b.rawValue) { bereich = b }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(b == bereich ? Self.akzent.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                            .foregroundStyle(b == bereich ? Self.akzent : Color.primary)
                            .accessibilityAddTraits(b == bereich ? .isSelected : [])
                    }
                }
                .padding(.horizontal)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 12)], spacing: 12) {
                    ForEach(bereich.namen.indices, id: \.self) { i in
                        option(i)
                    }
                }
                .padding(.horizontal)
            }

            Button {
                onSave(aussehen)
            } label: {
                Text("Figur sichern")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.akzent)
            .padding([.horizontal, .bottom])
        }
    }

    private func probe(_ i: Int) -> FigurAussehen {
        var a = aussehen
        a[keyPath: bereich.pfad] = i
        return a
    }

    private func option(_ i: Int) -> some View {
        let gewaehlt = aussehen[keyPath: bereich.pfad] == i
        return Button {
            aussehen[keyPath: bereich.pfad] = i
        } label: {
            Group {
                if let farben = bereich.farben {
                    Circle().fill(farben[i].farbe).frame(width: 50, height: 50)
                } else {
                    FigurView(probe(i), zustand: .ruhig, groesse: 80, animiert: false)
                }
            }
            .frame(width: 76, height: 86)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(gewaehlt ? Self.akzent : Color.clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bereich.namen[i])
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}

#Preview("Editor") {
    FigurEditor(start: .standard(for: .annika)) { _ in }
}
