import SwiftUI
import UIKit

/// Bitmoji-style figure builder: big live full-body preview (zooms to the head for face categories),
/// category bar, option tiles drawn with the figure itself, color swatches, dice. The caller sends `figur.aussehen` in `onSave`.
/// p65 C: two halves of one editor. `.figur` (Einstellungen, "Meine Figur") is face, skin, hair, eyes, beard and
/// body shape; `.kleidung` (Profil, "Kleidung") is outfits, tops, pants, shoes, jackets and accessories.
struct FigurEditor: View {
    enum Bereich { case figur, kleidung }

    private let onSave: (FigurAussehen) -> Void
    /// The saved look right now. The shop sheet writes bag, watch, jewelry and pet straight
    /// into it while this editor holds its own older copy (`aussehen`).
    private let modell: FigurAussehen?
    private let bereich: Bereich
    @State private var aussehen: FigurAussehen
    @State private var kategorie: Kategorie
    @State private var wuerfe = 0
    @State private var shopOffen = false
    /// p71 (29): the steps before the current look, newest last. `erwartet` marks the value an undo itself sets,
    /// so it is not recorded as a new step.
    @State private var verlauf: [FigurAussehen] = []
    @State private var erwartet: FigurAussehen?
    /// p71 (26): a shop piece tried on without buying. Only drawn in the preview, never part of `aussehen`.
    @State private var anprobe: ShopArtikel?
    /// p71 (30): the before/after slider over the preview.
    @State private var vergleich = false
    /// p71 (32): which pieces the wardrobe shows.
    @State private var filter = GarderobeFilter.alle
    private let looks = LookSpeicher.shared
    /// The look when the editor opened, the "before" of the slider.
    private let start: FigurAussehen

    init(start: FigurAussehen, modell: FigurAussehen? = nil, bereich: Bereich = .figur, person: Person? = nil, onSave: @escaping (FigurAussehen) -> Void) {
        self.person = person ?? Raum.shared.ich ?? .ahmed
        self.start = start
        _aussehen = State(initialValue: start)
        _kategorie = State(initialValue: bereich == .figur ? .gesicht : .outfits)
        self.modell = modell
        self.bereich = bereich
        self.onSave = onSave
    }

    /// Tab names of one half, in display order (the tabs themselves are private to the editor).
    static func tabs(fuer person: Person, bereich: Bereich) -> [String] {
        Kategorie.sichtbar(fuer: person, bereich: bereich).map(\.rawValue)
    }

    /// The look the preview draws: the editor's own copy, with the shop pieces (bag, watch, jewelry,
    /// pet) taken from the saved look, like `onSave` does. Without this, a bag put on in the
    /// shop sheet stays invisible here until the editor is reopened.
    static func vorschauLook(_ aussehen: FigurAussehen, modell: FigurAussehen?) -> FigurAussehen {
        aussehen.mitShopTeilen(von: modell ?? aussehen)
    }

    /// An old look made valid for `person`: face and clothes that this person's filter allows.
    static func gueltig(_ a: FigurAussehen, _ person: Person) -> FigurAussehen {
        FigurAussehen.mitGueltigerKleidung(FigurAussehen.mitGueltigemGesicht(a, person), person)
    }

    /// Z-24.1: gender filter is fixed per person, no switch in this editor. p68: whose figure this is;
    /// the own account unless Ahmed edits Annika's (`FigurEditorSeite`).
    private let person: Person

    private static let akzent = Color(red: 1, green: 59 / 255, blue: 92 / 255)

    /// How an option tile shows the figure.
    /// p71: `oberteil` draws without the jacket on top; `kette`/`ring`/`armband`/`uhr` zoom onto neck, hand and wrist
    /// like the shop's close-ups; `bauch` shows the bare torso.
    fileprivate enum Kachel {
        case gesicht, kopf, koerper, koerperMitName, oberteil, bauch, kette, ring, armband, uhr

        /// Small, head-sized tiles; the rest are full-body tiles.
        var klein: Bool {
            switch self {
            case .gesicht, .kopf, .kette, .ring, .armband, .uhr: true
            default: false
            }
        }

        var mitName: Bool { self == .koerperMitName || self == .bauch }
    }

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
        /// p65 C2: the shop pieces of one part, under the free ones. Owned ones tap to wear, the rest opens the shop.
        case shop(ShopFeld)
        /// p71 (27): today's outfit of both, with a heart for the other one's.
        case tagesOutfit
        /// p71 (28): five stored looks, one tap puts one on.
        case looks

        var shopFeld: ShopFeld? {
            guard case let .shop(feld) = self else { return nil }
            return feld
        }
    }

    fileprivate enum Kategorie: String, CaseIterable, Identifiable {
        case outfits = "Outfits"
        case gesicht = "Gesicht", haare = "Haare", augen = "Augen", bart = "Bart"
        case oberteil = "Oberteile", jacke = "Jacken", hose = "Hosen", schuhe = "Schuhe"
        case accessoires = "Accessoires", schmuck = "Schmuck", koerper = "Körper"

        var id: String { rawValue }

        var zoomt: Bool {
            switch self {
            case .gesicht, .haare, .augen, .bart, .accessoires: true
            default: false
            }
        }

        /// p65 C: the tabs of each half, in the order the wardrobe shows them (Oberteile, Hosen, Schuhe, Jacken,
        /// Accessoires; Outfits first as the quick start, Schmuck last). Bart only makes sense for Ahmed
        /// (männlich) — Annika would see just "Keiner".
        static func sichtbar(fuer person: Person, bereich: Bereich) -> [Kategorie] {
            let liste: [Kategorie] = bereich == .figur
                ? [.gesicht, .haare, .augen, .bart, .koerper]
                : [.outfits, .oberteil, .hose, .schuhe, .jacke, .accessoires, .schmuck]
            return person.figurGeschlecht == .m ? liste : liste.filter { $0 != .bart }
        }

        func abschnitte(fuer person: Person, eigeneFigur: Bool) -> [Abschnitt] {
            typealias A = FigurAussehen
            let kleidung = A.farben.map { Farbwahl(name: $0.name, farbe: $0.farbe) }
            switch self {
            case .gesicht:
                return [
                    .optionen("Gesichtsform", \.gesichtsform, A.gesichtsformen, .gesicht, erlaubte: A.gesichter(fuer: person)),
                    .farben("Hautton", \.haut, A.hautToene.map { Farbwahl(name: $0.name, farbe: $0.farbe) }, hexPfad: nil),
                    .optionen("Nase", \.nase, A.nasen, .gesicht, erlaubte: nil),
                    .optionen("Mund", \.mund, A.muender, .gesicht, erlaubte: nil),
                    .schalter("Sommersprossen", \.sommersprossen),
                    .schalter("Muttermal", \.muttermal),
                    .schalter("Mehrere Muttermale", \.muttermale),
                    .schalter("Rouge", \.rouge),
                ]
            case .haare:
                return [
                    .optionen("Frisur", \.frisur, A.frisuren, .kopf, erlaubte: A.frisurenAuswahl(fuer: person)),
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
                // p71: day outfit and stored looks are the own account's; Ahmed editing Annika sees only the presets.
                var liste: [Abschnitt] = [.outfits(A.outfits(fuer: person))]
                if eigeneFigur { liste += [.tagesOutfit, .looks] }
                return liste
            case .bart:
                return [
                    .optionen("Bart", \.bart, A.baerte, .gesicht, erlaubte: A.erlaubt(A.baerte, geschlecht: A.baerteGeschlecht, fuer: person)),
                    .optionen("Kinnbart", \.kinnbart, A.kinnbaerte, .gesicht, erlaubte: nil),
                ]
            case .oberteil:
                return [
                    .optionen("Oberteil", \.oberteil, A.oberteile, .oberteil, erlaubte: A.erlaubt(A.oberteile, geschlecht: A.oberteileGeschlecht, shop: A.oberteileShop, fuer: person)),
                    .farben("Farbe", \.oberteilfarbe, kleidung, hexPfad: \.oberteilfarbeHex),
                    .shop(.oberteil),
                ]
            case .jacke:
                return [
                    .optionen("Jacke", \.jacke, A.jacken, .koerper, erlaubte: A.erlaubt(A.jacken, geschlecht: A.jackenGeschlecht, shop: A.jackenShop, fuer: person)),
                    .farben("Farbe", \.jackenfarbe, kleidung, hexPfad: \.jackenfarbeHex),
                    .shop(.jacke),
                ]
            case .hose:
                return [
                    .optionen("Hose oder Rock", \.hose, A.hosen, .koerper, erlaubte: A.erlaubt(A.hosen, geschlecht: A.hosenGeschlecht, shop: A.hosenShop, fuer: person)),
                    .farben("Farbe", \.hosenfarbe, kleidung, hexPfad: \.hosenfarbeHex),
                    .shop(.hose),
                ]
            case .schuhe:
                return [
                    .optionen("Schuhe", \.schuhe, A.schuhArten, .koerper, erlaubte: A.erlaubt(A.schuhArten, geschlecht: A.schuheGeschlecht, shop: A.schuheShop, fuer: person)),
                    .farben("Farbe", \.schuhfarbe, kleidung, hexPfad: \.schuhfarbeHex),
                    .shop(.schuhe),
                ]
            case .accessoires:
                return [
                    .optionen("Brille", \.brille, A.brillen, .gesicht, erlaubte: A.erlaubt(A.brillen, geschlecht: A.brillenGeschlecht, shop: A.brillenShop, fuer: person)),
                    .optionen("Ohrringe", \.ohrringe, A.ohrringArten, .gesicht, erlaubte: A.erlaubt(A.ohrringArten, geschlecht: A.ohrringeGeschlecht, fuer: person)),
                    .optionen("Kopfbedeckung", \.kopfbedeckung, A.kopfbedeckungen, .kopf, erlaubte: A.erlaubt(A.kopfbedeckungen, geschlecht: A.kopfbedeckungenGeschlecht, fuer: person)),
                    .farben("Farbe der Kopfbedeckung", \.muetzenfarbe, kleidung, hexPfad: nil),
                    .schalter("AirPods", \.airpods),
                    .shop(.brille),
                ]
            case .schmuck:
                // Z-39.3: free everyday jewelry; luxury pieces come from the shop.
                return [
                    .optionen("Kette", \.kette, A.ketten, .kette, erlaubte: A.erlaubt(A.ketten, geschlecht: A.kettenGeschlecht, fuer: person)),
                    .optionen("Ring", \.ring, A.ringe, .ring, erlaubte: A.erlaubt(A.ringe, geschlecht: A.ringeGeschlecht, fuer: person)),
                    .optionen("Armband", \.armband, A.armbaender, .armband, erlaubte: A.erlaubt(A.armbaender, geschlecht: A.armbaenderGeschlecht, fuer: person)),
                    .optionen("Uhr", \.uhrAlltag, A.uhrenAlltag, .uhr, erlaubte: nil),
                ]
            case .koerper:
                // Z-38.2: body types per person; "Normal" stays for old looks but is hidden.
                let formen = A.erlaubt(A.koerperformen, geschlecht: A.koerperformenGeschlecht, shop: A.koerperformenVersteckt, fuer: person)
                var liste: [Abschnitt] = [
                    .optionen("Körperform", \.koerperform, A.koerperformen, .koerperMitName, erlaubte: formen),
                    .optionen("Größe", \.groesse, A.groessen, .koerperMitName, erlaubte: nil),
                ]
                // p71: the belly choice (abs) is Ahmed's.
                if person.figurGeschlecht == .m {
                    liste.append(.optionen("Bauch", \.bauchStufe, A.bauchNamen, .bauch, erlaubte: nil))
                }
                return liste
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            vorschau
            kategorienLeiste
            Divider()
            let liste = kategorie.abschnitte(fuer: person, eigeneFigur: !fremdeFigur)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let feld = liste.compactMap(\.shopFeld).first { filterLeiste(feld) }
                    ForEach(liste.indices, id: \.self) { i in
                        // The shop filter hides the free pieces; the shop row itself always stays.
                        if filter.zeigtFreies || liste[i].shopFeld != nil { abschnitt(liste[i]) }
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .id(kategorie)
        }
        // p71: the save button sits in the bottom safe area, so the last tiles scroll clear of it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                onSave(aussehen)
            } label: {
                Text(bereich == .figur ? "Figur sichern" : "Kleidung sichern")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Self.akzent)
            .padding()
            .background(.bar)
        }
        .sensoryFeedback(.selection, trigger: aussehen)
        .sensoryFeedback(.selection, trigger: kategorie)
        .sensoryFeedback(.impact(weight: .medium), trigger: wuerfe)
        .onAppear {
            let tabs = Kategorie.sichtbar(fuer: person, bereich: bereich)
            if !tabs.contains(kategorie), let erster = tabs.first { kategorie = erster }
            let gueltig = Self.gueltig(aussehen, person)
            if gueltig != aussehen {
                erwartet = gueltig // fixing up an old look is not a step to undo
                aussehen = gueltig
            }
        }
        .onChange(of: aussehen) { alt, neu in
            anprobe = nil
            if neu == erwartet { erwartet = nil; return }
            verlauf.append(alt)
            if verlauf.count > 40 { verlauf.removeFirst() }
        }
        .onChange(of: kategorie) {
            anprobe = nil
            filter = .alle
        }
        .sheet(isPresented: $shopOffen) { ShopView(ziel: person) }
    }

    /// What the preview draws: the editor's look, plus a shop piece that is only tried on (26).
    private var vorschauAussehen: FigurAussehen {
        let a = Self.vorschauLook(aussehen, modell: modell)
        guard let art = anprobe else { return a }
        let b = a.mitVorschau(art)
        return FigurAussehen.shopTeile[art.id]?.feld == .oberteil ? Self.ohneJacke(b) : b
    }

    /// p71 (30): Ahmed editing Annika's figure can slide between the look before and after.
    private var fremdeFigur: Bool { person != Raum.shared.ich }

    private var vorschau: some View {
        ZStack(alignment: .topTrailing) {
            if vergleich {
                VorherNachherView(vorher: Self.vorschauLook(Self.gueltig(start, person), modell: modell), nachher: Self.vorschauLook(aussehen, modell: modell))
                    .padding(.top, 10)
            } else {
                FigurView(vorschauAussehen, zustand: .ruhig, groesse: 290, ganzkoerper: true)
                    .scaleEffect(kategorie.zoomt ? 1.9 : 1, anchor: .top)
                    .frame(maxWidth: .infinity)
                    .frame(height: 290, alignment: .top)
                    .padding(.top, 10)
                    .clipped()
                    .animation(.spring(duration: 0.45), value: kategorie)
                    .accessibilityLabel("Vorschau deiner Figur")
            }
            VStack(spacing: 8) {
                vorschauTaste("dice.fill", "Zufälliger Look", aktion: zufall)
                vorschauTaste("arrow.uturn.backward", "Rückgängig", aktiv: !verlauf.isEmpty, aktion: zurueck)
                if fremdeFigur, vergleich || aussehen != Self.gueltig(start, person) {
                    vorschauTaste(vergleich ? "person.fill" : "slider.horizontal.below.rectangle", vergleich ? "Vergleich beenden" : "Vorher und nachher", aktion: { withAnimation(.snappy) { vergleich.toggle() } })
                }
            }
            .padding(12)
        }
        .overlay(alignment: .bottom) { anprobeKapsel }
        .background(LinearGradient(colors: [Self.akzent.opacity(0.16), Self.akzent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
    }

    private func vorschauTaste(_ symbol: String, _ beschriftung: String, aktiv: Bool = true, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(aktiv ? Self.akzent : Color.secondary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!aktiv)
        .accessibilityLabel(beschriftung)
    }

    /// p71 (26): a piece tried on without buying says so and offers the shop.
    @ViewBuilder
    private var anprobeKapsel: some View {
        if let art = anprobe {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Anprobe: \(art.name)").font(.footnote.weight(.semibold)).lineLimit(1)
                    Text("\(art.preis) Punkte, noch nicht gekauft").font(.caption2).foregroundStyle(.secondary)
                }
                Button("Kaufen") { shopOffen = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.akzent)
                    .controlSize(.small)
                Button { anprobe = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Anprobe beenden")
            }
            .padding(.leading, 14)
            .padding(.trailing, 2)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 8)
        }
    }

    /// p71 (29): one step back. The restored value is marked in `erwartet`, so it is not recorded as a new step.
    private func zurueck() {
        guard let letzter = verlauf.popLast() else { return }
        erwartet = letzter
        withAnimation(Feder.weich) { aussehen = letzter }
    }

    private var kategorienLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Kategorie.sichtbar(fuer: person, bereich: bereich)) { k in
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
        case let .shop(feld):
            shopReihe(feld)
        case .tagesOutfit:
            tagesOutfitAnsicht
        case .looks:
            looksAnsicht
        }
    }

    // MARK: - p71: Filter, Anprobe, Looks, Outfit des Tages

    /// All shop pieces of one part, owned ones first (see `GarderobeLogik.shopStuecke`).
    private func stuecke(_ feld: ShopFeld) -> [GarderobeStueck] {
        let besitz = PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis }).besitz
        return GarderobeLogik.shopStuecke(feld: feld, person: person, besitzt: { besitz.besitzt($0, person) })
    }

    private var markeAktiv: String? {
        if case let .marke(m) = filter { return m }
        return nil
    }

    private func chip(_ text: String, aktiv: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(aktiv ? Self.akzent.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
            .foregroundStyle(aktiv ? Self.akzent : Color.primary)
    }

    private func filterChip(_ text: String, _ wert: GarderobeFilter) -> some View {
        Button { filter = wert } label: { chip(text, aktiv: filter == wert) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(filter == wert ? .isSelected : [])
    }

    /// p71 (32): all / owned / shop / one brand.
    private func filterLeiste(_ feld: ShopFeld) -> some View {
        let marken = GarderobeFilter.marken(stuecke(feld))
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Alle", .alle)
                filterChip("Meine", .meine)
                filterChip("Shop", .shop)
                if !marken.isEmpty {
                    Menu {
                        ForEach(marken, id: \.self) { m in
                            Button(m) { filter = .marke(m) }
                        }
                    } label: {
                        chip(markeAktiv ?? "Marke", aktiv: markeAktiv != nil)
                    }
                }
            }
        }
    }

    /// p71 (28): five stored looks. A filled tile puts its clothes on, an empty one stores the current outfit;
    /// the context menu stores over a filled one.
    private var looksAnsicht: some View {
        let gespeichert = looks.plaetze(person)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Meine Looks").font(.headline)
            Text("Tippen zieht den Look an. Leere Plätze speichern das aktuelle Outfit, gedrückt halten überschreibt.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(0..<LookLogik.plaetze, id: \.self) { i in
                    platzKachel(i, gespeichert[i])
                }
            }
        }
    }

    private func platzKachel(_ i: Int, _ look: FigurAussehen?) -> some View {
        let probe = look.map { aussehen.mitKleidung(von: $0) }
        let gewaehlt = probe == aussehen
        return Button {
            if let probe {
                withAnimation(Feder.weich) { aussehen = probe }
            } else {
                looks.platzSichern(i, aussehen)
            }
        } label: {
            VStack(spacing: 2) {
                if let probe {
                    FigurView(Self.vorschauLook(probe, modell: modell), zustand: .ruhig, groesse: 120, animiert: false, ganzkoerper: true)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.title)
                        .foregroundStyle(Self.akzent)
                        .frame(width: 96, height: 120)
                }
                Text(look == nil ? "Speichern" : "Look \(i + 1)")
                    .font(.caption2.weight(.semibold))
                    .padding(.bottom, 6)
            }
            .frame(width: 96, height: 150)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(gewaehlt ? Self.akzent : Color.clear, lineWidth: 3))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.federnd)
        .contextMenu {
            Button("Aktuelles Outfit hier speichern", systemImage: "square.and.arrow.down") { looks.platzSichern(i, aussehen) }
        }
        .accessibilityLabel(look == nil ? "Platz \(i + 1), leer, aktuelles Outfit speichern" : "Look \(i + 1) anziehen")
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    /// p71 (27): each of us picks a look for today, the other sees it and can give a heart.
    private var tagesOutfitAnsicht: some View {
        let heute = Datum.text(Date())
        let partner = person.partner
        let eigenes = looks.stand.tagesLook(person, tag: heute)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Outfit des Tages").font(.headline)
            HStack(alignment: .top, spacing: 12) {
                tagesKachel("Du", eigenes, von: person, heute: heute)
                tagesKachel(partner.name, looks.stand.tagesLook(partner, tag: heute), von: partner, heute: heute)
            }
            Button(eigenes == nil ? "Dieses Outfit für heute wählen" : "Heutiges Outfit ändern") {
                looks.tagesOutfitSetzen(Self.vorschauLook(aussehen, modell: modell), tag: heute)
            }
            .buttonStyle(.bordered)
            .tint(Self.akzent)
            .frame(minHeight: 44)
        }
    }

    private func tagesKachel(_ titel: String, _ look: FigurAussehen?, von wer: Person, heute: String) -> some View {
        let eigene = wer == person
        return VStack(spacing: 4) {
            if let look {
                FigurView(FigurenModell.shared.aussehen(wer).mitKleidung(von: look), zustand: .ruhig, groesse: 120, animiert: false, ganzkoerper: true)
            } else {
                Image(systemName: "hanger").font(.title).foregroundStyle(.secondary).frame(width: 96, height: 120)
            }
            Text(look == nil ? (eigene ? "Noch keins gewählt" : "\(titel) hat noch keins gewählt") : titel)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
            if look != nil {
                tagesHerz(eigene: eigene, wer: wer, heute: heute)
            }
        }
        .frame(width: 120)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Own tile: shows a heart that the other gave. The other one's tile: the button that gives it.
    @ViewBuilder
    private func tagesHerz(eigene: Bool, wer: Person, heute: String) -> some View {
        if eigene {
            if looks.stand.herz(von: wer.partner, fuer: wer, tag: heute) {
                Label("\(wer.partner.name) mag es", systemImage: "heart.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Self.akzent)
            }
        } else {
            let gegeben = looks.stand.herz(von: person, fuer: wer, tag: heute)
            Button {
                looks.herzGeben(fuer: wer, tag: heute)
            } label: {
                Label(gegeben ? "Herz gegeben" : "Herz geben", systemImage: gegeben ? "heart.fill" : "heart")
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Self.akzent)
            .disabled(gegeben)
        }
    }

    /// p65 C2: shop pieces of one part under the free ones. Worn ones carry a ring, owned ones a check mark,
    /// the rest their price; an unowned piece opens the shop. A shop piece lives in the same index as a
    /// free one, so wearing it here changes this editor's copy and is saved with "Kleidung sichern".
    @ViewBuilder
    private func shopReihe(_ feld: ShopFeld) -> some View {
        let alle = stuecke(feld)
        let sichtbar = alle.filter { filter.laesst($0) }
        if !alle.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Aus dem Shop").font(.headline)
                    Spacer()
                    Button("Shop öffnen") { shopOffen = true }
                        .font(.subheadline.weight(.semibold))
                        .tint(Self.akzent)
                        .frame(minHeight: 44)
                }
                if sichtbar.isEmpty {
                    Text("Nichts in dieser Auswahl").font(.subheadline).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 14) {
                    ForEach(sichtbar) { s in
                        let getragen = aussehen.traegt(s.artikel)
                        let anprobiert = anprobe == s.artikel
                        Button {
                            // p71 (26): a piece you do not own is tried on first; "Kaufen" in the preview opens the shop.
                            if s.besitzt { tragen(s.artikel) } else { anprobe = anprobiert ? nil : s.artikel }
                        } label: {
                            ArtikelKachel(artikel: s.artikel, besitzt: s.besitzt, vorschauAussehen: shopVorschau(feld, s.artikel))
                                .overlay(alignment: .top) {
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(getragen || anprobiert ? Self.akzent : Color.clear, lineWidth: 3)
                                        .frame(width: 84, height: 96)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(getragen || anprobiert ? .isSelected : [])
                        .accessibilityHint(s.besitzt ? "" : "Probiert das Teil an, ohne es zu kaufen")
                    }
                }
            }
        }
    }

    private static func ohneJacke(_ a: FigurAussehen) -> FigurAussehen {
        var b = a
        b.jacke = 0
        return b
    }

    /// The bare torso (Oberteil 33, "Oben ohne"), so the belly choice shows.
    private static func obenOhne(_ a: FigurAussehen) -> FigurAussehen {
        var b = ohneJacke(a)
        b.oberteil = 33
        return b
    }

    /// A top from the shop is shown without the jacket over it, like the free tops.
    private func shopVorschau(_ feld: ShopFeld, _ artikel: ShopArtikel) -> FigurAussehen {
        let a = aussehen.mitVorschau(artikel)
        return feld == .oberteil ? Self.ohneJacke(a) : a
    }

    private func tragen(_ artikel: ShopArtikel) {
        withAnimation(Feder.weich) {
            if aussehen.traegt(artikel) { aussehen.ausziehen(artikel, person: person) } else { aussehen.anziehen(artikel) }
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
                        if kachel.mitName {
                            Text(namen[i]).font(.caption2.weight(.semibold)).padding(.bottom, 6)
                        }
                    }
                    .frame(width: 76, height: kachel.klein ? 92 : 128)
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
        case .oberteil:
            // The jacket would cover the top that the tile is about.
            FigurView(Self.ohneJacke(a), zustand: .ruhig, groesse: 120, animiert: false, ganzkoerper: true)
        case .bauch:
            FigurView(Self.obenOhne(a), zustand: .ruhig, groesse: 104, animiert: false, ganzkoerper: true)
        case .kette:
            schmuckNah(alltagsKetten, a.kette)
        case .ring:
            schmuckNah(alltagsRinge, a.ring)
        case .armband:
            schmuckNah(alltagsArmbaender, a.armband)
        case .uhr:
            if alltagsUhren.indices.contains(a.uhrAlltag - 1) {
                let u = alltagsUhren[a.uhrAlltag - 1]
                let haut = FigurAussehen.hautToene.wahl(a.haut).farbe
                NahFeld { zeichneUhrGross($0, u.stil, band: u.band, gehaeuse: u.gehaeuse, haut: haut) }
                    .frame(width: 76, height: 92)
            } else {
                keinSchmuck
            }
        }
    }

    /// p71: the piece large, with the same drawing the shop uses for its jewelry close-ups.
    @ViewBuilder
    private func schmuckNah(_ tabelle: [SchmuckEintrag], _ i: Int) -> some View {
        if tabelle.indices.contains(i - 1) {
            let e = tabelle[i - 1]
            NahFeld { zeichneSchmuckGross($0, e.stil, e.farbe) }
                .frame(width: 76, height: 92)
        } else {
            keinSchmuck
        }
    }

    private var keinSchmuck: some View {
        Image(systemName: "nosign")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(width: 76, height: 92)
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

    /// New look: in the figure half only hair, in the wardrobe only clothes and accessories; face, skin and
    /// body stay. Only picks options this person's gender filter allows, and never a shop-only item
    /// (that would make buying pointless).
    private func zufall() {
        typealias A = FigurAussehen
        func eins(_ erlaubte: [Int]) -> Int { erlaubte.randomElement() ?? 0 }
        func oftKeins(_ erlaubte: [Int]) -> Int { Bool.random() ? 0 : eins(erlaubte) }
        var a = aussehen
        if bereich == .figur {
            a.frisur = eins(A.frisurenAuswahl(fuer: person))
            a.haarfarbe = eins(Array(A.haarfarben.indices))
            a.haarfarbeHex = nil
            withAnimation(.snappy) { aussehen = a }
            wuerfe += 1
            return
        }
        a.oberteil = eins(A.erlaubt(A.oberteile, geschlecht: A.oberteileGeschlecht, shop: A.oberteileShop, fuer: person))
        a.oberteilfarbe = eins(Array(A.farben.indices))
        a.oberteilfarbeHex = nil
        a.jacke = oftKeins(A.erlaubt(A.jacken, geschlecht: A.jackenGeschlecht, shop: A.jackenShop, fuer: person))
        a.jackenfarbe = eins(Array(A.farben.indices))
        a.jackenfarbeHex = nil
        a.hose = eins(A.erlaubt(A.hosen, geschlecht: A.hosenGeschlecht, shop: A.hosenShop, fuer: person))
        a.hosenfarbe = eins(Array(A.farben.indices))
        a.hosenfarbeHex = nil
        a.schuhe = eins(A.erlaubt(A.schuhArten, geschlecht: A.schuheGeschlecht, shop: A.schuheShop, fuer: person))
        a.schuhfarbe = eins(Array(A.farben.indices))
        a.schuhfarbeHex = nil
        a.kopfbedeckung = oftKeins(A.erlaubt(A.kopfbedeckungen, geschlecht: A.kopfbedeckungenGeschlecht, fuer: person))
        a.muetzenfarbe = eins(Array(A.farben.indices))
        a.brille = oftKeins(A.erlaubt(A.brillen, geschlecht: A.brillenGeschlecht, shop: A.brillenShop, fuer: person))
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
