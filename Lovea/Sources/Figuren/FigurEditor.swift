import SwiftUI
import UIKit

/// Bitmoji-style figure builder: big live full-body preview (zooms to the head for face categories),
/// category bar, option tiles drawn with the figure itself, color swatches, dice. The caller sends `figur.aussehen` in `onSave`.
struct FigurEditor: View {
    private let onSave: (FigurAussehen) -> Void
    @State private var aussehen: FigurAussehen
    @State private var kategorie = Kategorie.outfits
    @State private var wuerfe = 0

    init(start: FigurAussehen, onSave: @escaping (FigurAussehen) -> Void) {
        _aussehen = State(initialValue: start)
        self.onSave = onSave
    }

    /// Z-24.1: gender filter is fixed per person, no switch in this editor — derived from the own
    /// account rather than a parameter, so callers (Profil, Einstellungen) stay unchanged.
    private var person: Person { Raum.shared.ich ?? .ahmed }

    private static let akzent = Color(red: 1, green: 59 / 255, blue: 92 / 255)

    /// How an option tile shows the figure.
    fileprivate enum Kachel { case gesicht, kopf, koerper, koerperMitName, schmuck }

    fileprivate struct Farbwahl {
        let name: String
        let farbe: FigurFarbe
        var straehne: FigurFarbe? = nil
    }

    fileprivate enum Abschnitt {
        /// `erlaubte`: indices this person may pick (gender + shop filter), `nil` = every index.
        case optionen(String, WritableKeyPath<FigurAussehen, Int>, [String], Kachel, erlaubte: [Int]?)
        /// `hexPfad`: free-color override field, `nil` = swatches only (no `ColorPicker`).
        case farben(String, WritableKeyPath<FigurAussehen, Int>, [Farbwahl], hexPfad: WritableKeyPath<FigurAussehen, String?>?)
        case schalter(String, WritableKeyPath<FigurAussehen, Bool>)
        /// Fix round 3: one-tap outfit presets.
        case outfits([FigurOutfit])
    }

    fileprivate enum Kategorie: String, CaseIterable, Identifiable {
        case outfits = "Outfits"
        case gesicht = "Gesicht", haare = "Haare", augen = "Augen", bart = "Bart"
        case oberteil = "Oberteil", jacke = "Jacke", hose = "Hose", schuhe = "Schuhe"
        case accessoires = "Accessoires", schmuck = "Schmuck", koerper = "Körper"

        var id: String { rawValue }

        var zoomt: Bool {
            switch self {
            case .gesicht, .haare, .augen, .bart, .accessoires: true
            default: false
            }
        }

        /// Bart only makes sense for Ahmed (männlich) — Annika would see just "Keiner".
        static func sichtbar(fuer person: Person) -> [Kategorie] {
            person.figurGeschlecht == .m ? allCases : allCases.filter { $0 != .bart }
        }

        func abschnitte(fuer person: Person) -> [Abschnitt] {
            typealias A = FigurAussehen
            let kleidung = A.farben.map { Farbwahl(name: $0.name, farbe: $0.farbe) }
            switch self {
            case .gesicht:
                return [
                    .optionen("Gesichtsform", \.gesichtsform, A.gesichtsformen, .gesicht, erlaubte: nil),
                    .farben("Hautton", \.haut, A.hautToene.map { Farbwahl(name: $0.name, farbe: $0.farbe) }, hexPfad: nil),
                    .optionen("Nase", \.nase, A.nasen, .gesicht, erlaubte: nil),
                    .optionen("Mund", \.mund, A.muender, .gesicht, erlaubte: nil),
                    .schalter("Sommersprossen", \.sommersprossen),
                    .schalter("Muttermal", \.muttermal),
                    .schalter("Rouge", \.rouge),
                ]
            case .haare:
                return [
                    .optionen("Frisur", \.frisur, A.frisuren, .kopf, erlaubte: A.erlaubt(A.frisuren, geschlecht: A.frisurenGeschlecht, fuer: person)),
                    .farben("Haarfarbe", \.haarfarbe, A.haarfarben.map { Farbwahl(name: $0.name, farbe: $0.farbe, straehne: $0.straehne) }, hexPfad: \.haarfarbeHex),
                ]
            case .augen:
                return [
                    .optionen("Augenform", \.augenform, A.augenformen, .gesicht, erlaubte: nil),
                    .farben("Augenfarbe", \.augen, A.augenfarben.map { Farbwahl(name: $0.name, farbe: $0.farbe) }, hexPfad: nil),
                    .optionen("Augenbrauen", \.brauen, A.augenbrauen, .gesicht, erlaubte: nil),
                    .schalter("Wimpern", \.wimpern),
                ]
            case .outfits:
                return [.outfits(A.outfits(fuer: person))]
            case .bart:
                return [
                    .optionen("Bart", \.bart, A.baerte, .gesicht, erlaubte: A.erlaubt(A.baerte, geschlecht: A.baerteGeschlecht, fuer: person)),
                    .optionen("Kinnbart", \.kinnbart, A.kinnbaerte, .gesicht, erlaubte: nil),
                ]
            case .oberteil:
                return [
                    .optionen("Oberteil", \.oberteil, A.oberteile, .koerper, erlaubte: A.erlaubt(A.oberteile, geschlecht: A.oberteileGeschlecht, shop: A.oberteileShop, fuer: person)),
                    .farben("Farbe", \.oberteilfarbe, kleidung, hexPfad: \.oberteilfarbeHex),
                ]
            case .jacke:
                return [
                    .optionen("Jacke", \.jacke, A.jacken, .koerper, erlaubte: A.erlaubt(A.jacken, shop: A.jackenShop, fuer: person)),
                    .farben("Farbe", \.jackenfarbe, kleidung, hexPfad: \.jackenfarbeHex),
                ]
            case .hose:
                return [
                    .optionen("Hose oder Rock", \.hose, A.hosen, .koerper, erlaubte: A.erlaubt(A.hosen, geschlecht: A.hosenGeschlecht, shop: A.hosenShop, fuer: person)),
                    .farben("Farbe", \.hosenfarbe, kleidung, hexPfad: \.hosenfarbeHex),
                ]
            case .schuhe:
                return [
                    .optionen("Schuhe", \.schuhe, A.schuhArten, .koerper, erlaubte: A.erlaubt(A.schuhArten, shop: A.schuheShop, fuer: person)),
                    .farben("Farbe", \.schuhfarbe, kleidung, hexPfad: \.schuhfarbeHex),
                ]
            case .accessoires:
                return [
                    .optionen("Brille", \.brille, A.brillen, .gesicht, erlaubte: A.erlaubt(A.brillen, shop: A.brillenShop, fuer: person)),
                    .optionen("Ohrringe", \.ohrringe, A.ohrringArten, .gesicht, erlaubte: A.erlaubt(A.ohrringArten, geschlecht: A.ohrringeGeschlecht, fuer: person)),
                    .optionen("Kopfbedeckung", \.kopfbedeckung, A.kopfbedeckungen, .kopf, erlaubte: nil),
                    .farben("Farbe der Kopfbedeckung", \.muetzenfarbe, kleidung, hexPfad: nil),
                ]
            case .schmuck:
                // Z-39.3: free everyday jewelry; luxury pieces come from the shop.
                return [
                    .optionen("Kette", \.kette, A.ketten, .schmuck, erlaubte: A.erlaubt(A.ketten, geschlecht: A.kettenGeschlecht, fuer: person)),
                    .optionen("Ring", \.ring, A.ringe, .schmuck, erlaubte: A.erlaubt(A.ringe, geschlecht: A.ringeGeschlecht, fuer: person)),
                    .optionen("Armband", \.armband, A.armbaender, .schmuck, erlaubte: A.erlaubt(A.armbaender, geschlecht: A.armbaenderGeschlecht, fuer: person)),
                    .optionen("Uhr", \.uhrAlltag, A.uhrenAlltag, .schmuck, erlaubte: nil),
                ]
            case .koerper:
                // Z-38.2: body types per person; "Normal" stays for old looks but is hidden.
                let formen = A.erlaubt(A.koerperformen, geschlecht: A.koerperformenGeschlecht, shop: A.koerperformenVersteckt, fuer: person)
                return [
                    .optionen("Körperform", \.koerperform, A.koerperformen, .koerperMitName, erlaubte: formen),
                    .optionen("Größe", \.groesse, A.groessen, .koerperMitName, erlaubte: nil),
                ]
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            vorschau
            kategorienLeiste
            Divider()
            let liste = kategorie.abschnitte(fuer: person)
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
        .onAppear {
            if !Kategorie.sichtbar(fuer: person).contains(kategorie) { kategorie = .gesicht }
        }
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
        .overlay(alignment: .topLeading) { bitmojiKnopf }
        .background(LinearGradient(colors: [Self.akzent.opacity(0.16), Self.akzent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
    }

    private var bitmojiKnopf: some View {
        Button(action: wieBitmoji) {
            Label("Wie mein Bitmoji", systemImage: "person.crop.circle.badge.checkmark")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.federnd)
        .foregroundStyle(Self.akzent)
        .padding(12)
    }

    /// Z-38.4: back to the Bitmoji look; bought shop pieces stay on.
    private func wieBitmoji() {
        var a = FigurAussehen.standard(for: person)
        a.tasche = aussehen.tasche
        a.uhr = aussehen.uhr
        a.schmuck = aussehen.schmuck
        a.pose = aussehen.pose
        a.tier = aussehen.tier
        withAnimation(Feder.weich) { aussehen = a }
    }

    private var kategorienLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Kategorie.sichtbar(fuer: person)) { k in
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
        case let .optionen(titel, pfad, namen, kachel, erlaubte):
            VStack(alignment: .leading, spacing: 10) {
                Text(titel).font(.headline)
                kacheln(pfad, namen, kachel, erlaubte ?? Array(namen.indices))
            }
        case let .farben(titel, pfad, liste, hexPfad):
            VStack(alignment: .leading, spacing: 10) {
                Text(titel).font(.headline)
                farbReihe(pfad, liste, hexPfad)
            }
        case let .schalter(titel, pfad):
            Toggle(titel, isOn: $aussehen[dynamicMember: pfad])
                .font(.headline)
                .tint(Self.akzent)
        case let .outfits(liste):
            VStack(alignment: .leading, spacing: 10) {
                Text("Outfits").font(.headline)
                outfitKacheln(liste)
            }
        }
    }

    /// Fix round 3: each preset as a live full-body preview; applying one keeps face and hair.
    private func outfitKacheln(_ liste: [FigurOutfit]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(liste) { o in
                OutfitKachel(outfit: o, aussehen: aussehen, gewaehlt: aussehen.traegt(outfit: o), akzent: Self.akzent) {
                    withAnimation(Feder.weich) { aussehen.anziehen(outfit: o) }
                }
            }
        }
    }

    private func probe(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ i: Int) -> FigurAussehen {
        var a = aussehen
        a[keyPath: pfad] = i
        return a
    }

    private func kacheln(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ namen: [String], _ kachel: Kachel, _ erlaubte: [Int]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
            ForEach(erlaubte, id: \.self) { i in
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
                    .frame(width: 76, height: kachel == .gesicht || kachel == .kopf || kachel == .schmuck ? 92 : 128)
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
        case .schmuck:
            // Chest to hands of a larger full body, so rings and bracelets are visible.
            FigurView(a, zustand: .ruhig, groesse: 230, animiert: false, ganzkoerper: true)
                .frame(width: 76, height: 92)
                .clipped()
        }
    }

    private func farbReihe(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ liste: [Farbwahl], _ hexPfad: WritableKeyPath<FigurAussehen, String?>?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(liste.indices, id: \.self) { i in
                    let hexAktiv = hexPfad.map { aussehen[keyPath: $0] != nil } ?? false
                    let gewaehlt = !hexAktiv && aussehen[keyPath: pfad] == i
                    Button {
                        aussehen[keyPath: pfad] = i
                        if let hexPfad { aussehen[keyPath: hexPfad] = nil }
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
                if let hexPfad {
                    freieFarbe(pfad, liste, hexPfad)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// Z-24.1: free color picker for Haare/Kleidung — writes a hex string, clearing it falls back
    /// to the swatch index above.
    private func freieFarbe(_ pfad: WritableKeyPath<FigurAussehen, Int>, _ liste: [Farbwahl], _ hexPfad: WritableKeyPath<FigurAussehen, String?>) -> some View {
        let hexAktiv = aussehen[keyPath: hexPfad]
        let binding = Binding<Color>(
            get: {
                if let hexAktiv, let f = FigurFarbe(hex: hexAktiv) { return f.farbe }
                let i = min(max(aussehen[keyPath: pfad], 0), liste.count - 1)
                return liste[i].farbe.farbe
            },
            set: { neu in aussehen[keyPath: hexPfad] = hexVon(neu) }
        )
        return ColorPicker("Freie Farbe", selection: binding, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 38, height: 38)
            .padding(4)
            .overlay(Circle().strokeBorder(hexAktiv != nil ? Self.akzent : Color.clear, lineWidth: 3))
            .frame(width: 48, height: 48)
            .accessibilityLabel("Freie Farbe wählen")
    }

    /// `ColorPicker` can hand back extended-sRGB/P3 components outside 0...1 — clamp before hex.
    private func hexVon(_ farbe: Color) -> String {
        let ui = UIColor(farbe)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func kanal(_ x: CGFloat) -> String { String(format: "%02X", Int((min(max(x, 0), 1) * 255).rounded())) }
        return kanal(r) + kanal(g) + kanal(b)
    }

    /// New look: hair, clothes and accessories; face, skin and body stay. Only picks options this
    /// person's gender filter allows, and never a shop-only item (that would make buying pointless).
    private func zufall() {
        typealias A = FigurAussehen
        func eins(_ erlaubte: [Int]) -> Int { erlaubte.randomElement() ?? 0 }
        func oftKeins(_ erlaubte: [Int]) -> Int { Bool.random() ? 0 : eins(erlaubte) }
        var a = aussehen
        a.frisur = eins(A.erlaubt(A.frisuren, geschlecht: A.frisurenGeschlecht, fuer: person))
        a.haarfarbe = eins(Array(A.haarfarben.indices))
        a.haarfarbeHex = nil
        a.oberteil = eins(A.erlaubt(A.oberteile, geschlecht: A.oberteileGeschlecht, shop: A.oberteileShop, fuer: person))
        a.oberteilfarbe = eins(Array(A.farben.indices))
        a.oberteilfarbeHex = nil
        a.jacke = oftKeins(A.erlaubt(A.jacken, shop: A.jackenShop, fuer: person))
        a.jackenfarbe = eins(Array(A.farben.indices))
        a.jackenfarbeHex = nil
        a.hose = eins(A.erlaubt(A.hosen, geschlecht: A.hosenGeschlecht, shop: A.hosenShop, fuer: person))
        a.hosenfarbe = eins(Array(A.farben.indices))
        a.hosenfarbeHex = nil
        a.schuhe = eins(A.erlaubt(A.schuhArten, shop: A.schuheShop, fuer: person))
        a.schuhfarbe = eins(Array(A.farben.indices))
        a.schuhfarbeHex = nil
        a.kopfbedeckung = oftKeins(Array(A.kopfbedeckungen.indices))
        a.muetzenfarbe = eins(Array(A.farben.indices))
        a.brille = oftKeins(A.erlaubt(A.brillen, shop: A.brillenShop, fuer: person))
        withAnimation(.snappy) { aussehen = a }
        wuerfe += 1
    }
}

/// One outfit preset tile: the figure wearing it, its name, marked when worn.
private struct OutfitKachel: View {
    let outfit: FigurOutfit
    let aussehen: FigurAussehen
    let gewaehlt: Bool
    let akzent: Color
    let anziehen: () -> Void

    var body: some View {
        Button(action: anziehen) {
            VStack(spacing: 2) {
                FigurView(probe, zustand: .ruhig, groesse: 120, animiert: false, ganzkoerper: true)
                Text(outfit.name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 6)
            }
            .frame(width: 96, height: 150)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(gewaehlt ? akzent : Color.clear, lineWidth: 3))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.federnd)
        .accessibilityLabel("Outfit \(outfit.name)")
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    private var probe: FigurAussehen {
        var a = aussehen
        a.anziehen(outfit: outfit)
        return a
    }
}

#Preview("Editor") {
    FigurEditor(start: .standard(for: .annika)) { _ in }
}
