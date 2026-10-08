import SwiftUI

/// Z-23.2: categories, grid of item previews (each tile a live "try-on" on the target figure), a bigger live preview + buy/wear sheet, gift mode.
/// Reachable from the own profile (Profile/) and the figure editor (Einstellungen/).
struct ShopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kategorie = ShopKategorie.mode
    @State private var geschenkModus = false
    @State private var ausgewaehlt: ShopArtikel?
    @State private var gekauft = 0

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var ziel: Person { geschenkModus ? ich.partner : ich }

    /// One fold per render instead of one per tile (20 items) — see `PunkteModell.einkaufsStand`.
    private var stand: (verfuegbar: [Person: Int], besitz: BesitzLogik.Ergebnis) {
        PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis })
    }

    var body: some View {
        NavigationStack {
            let info = stand
            VStack(spacing: 0) {
                kopf(info)
                kategorienLeiste
                ScrollView { gitter(info).padding(Abstand.l) }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .sensoryFeedback(.success, trigger: gekauft)
            .sheet(item: $ausgewaehlt) { artikel in
                ArtikelDetail(
                    artikel: artikel, ziel: fuer(artikel), istEigeneFigur: fuer(artikel) == ich,
                    besitzt: besitzt(artikel, stand.besitz), verfuegbar: stand.verfuegbar[ich] ?? 0,
                    onKauf: { kaufen(artikel) }, onAnziehen: { anziehen(artikel) }, onAusziehen: { ausziehen(artikel) }
                )
            }
        }
    }

    // MARK: - Kopf

    private func kopf(_ info: (verfuegbar: [Person: Int], besitz: BesitzLogik.Ergebnis)) -> some View {
        HStack {
            Label("\(info.verfuegbar[ich] ?? 0) Punkte", systemImage: "sparkles")
                .font(.headline)
            Spacer()
            Button {
                withAnimation(.snappy) { geschenkModus.toggle() }
            } label: {
                Label(geschenkModus ? "Für \(ich.partner.name)" : "Für mich", systemImage: geschenkModus ? "gift.fill" : "gift")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Capsule().fill(geschenkModus ? Color.loveaRose.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                    .foregroundStyle(geschenkModus ? Color.loveaRose : Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(geschenkModus ? "Geschenk-Modus an, für \(ich.partner.name)" : "Geschenk-Modus aus")
        }
        .padding(.horizontal, Abstand.l)
        .padding(.top, Abstand.s)
        .padding(.bottom, Abstand.xs)
    }

    /// p56: nur Gruppen mit Teilen für die Figur, die gerade eingekleidet wird (Ahmed hat keinen Schmuck).
    private var kategorien: [ShopKategorie] {
        ShopKategorie.allCases.filter { k in
            ShopKatalog.alle.contains { $0.kategorie == k.rawValue && $0.sichtbar(fuer: ziel) }
        }
    }

    private var kategorienLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kategorien) { k in
                    Button {
                        withAnimation(.snappy) { kategorie = k }
                    } label: {
                        Label(k.titel, systemImage: k.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(k == kategorie ? Color.loveaRose.opacity(0.18) : Color(uiColor: .secondarySystemBackground)))
                            .foregroundStyle(k == kategorie ? Color.loveaRose : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(k == kategorie ? .isSelected : [])
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
        }
    }

    // MARK: - Gitter

    private func gitter(_ info: (verfuegbar: [Person: Int], besitz: BesitzLogik.Ergebnis)) -> some View {
        let artikel = ShopKatalog.alle.filter { $0.kategorie == kategorie.rawValue && $0.sichtbar(fuer: ziel) }
        let aussehenZiel = FigurenModell.shared.aussehen(ziel)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Abstand.m)], spacing: Abstand.m) {
            ForEach(artikel) { a in
                Button { ausgewaehlt = a } label: {
                    ArtikelKachel(artikel: a, besitzt: besitzt(a, info.besitz), vorschauAussehen: aussehenZiel.mitVorschau(a))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Aktionen

    /// p61: the room is shared. A room piece is always bought for oneself (no gift mode) and counts
    /// as owned when either of them owns it.
    private func fuer(_ a: ShopArtikel) -> Person { a.kategorie == ShopKategorie.zimmer.rawValue ? ich : ziel }

    private func besitzt(_ a: ShopArtikel, _ besitz: BesitzLogik.Ergebnis) -> Bool {
        a.kategorie == ShopKategorie.zimmer.rawValue ? ZimmerWahl.gehoert(a.id, besitz: besitz) : besitz.besitzt(a.id, ziel)
    }

    private func kaufen(_ artikel: ShopArtikel) {
        guard PunkteModell.shared.kaufen(artikel: artikel.id, fuer: fuer(artikel), preis: { ShopKatalog.artikel($0)?.preis }) else { return }
        gekauft += 1
    }

    private func anziehen(_ artikel: ShopArtikel) {
        guard artikel.kategorie != ShopKategorie.zimmer.rawValue else { return ZimmerWahl.aktuell.einrichten(artikel.id).sichern() }
        var a = FigurenModell.shared.aussehen(ich)
        a.anziehen(artikel)
        FigurenModell.shared.aussehenSichern(a)
    }

    private func ausziehen(_ artikel: ShopArtikel) {
        guard artikel.kategorie != ShopKategorie.zimmer.rawValue else { return ZimmerWahl.aktuell.wegraeumen(artikel.id).sichern() }
        var a = FigurenModell.shared.aussehen(ich)
        a.ausziehen(artikel, person: ich)
        FigurenModell.shared.aussehenSichern(a)
    }
}

/// p47: der Shop hat nur noch diese Gruppen; p56 bringt den Schmuck zurück (neue `juwel.*`-IDs). p61: dazu "Zimmer" (Wandfarbe, Teppich, Bettwäsche, Lampe).
enum ShopKategorie: String, CaseIterable, Identifiable {
    case mode, schmuck, tasche, tier, zimmer
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .mode: "Mode"
        case .schmuck: "Schmuck"
        case .tasche: "Taschen"
        case .tier: "Haustiere"
        case .zimmer: "Zimmer"
        }
    }

    var symbol: String {
        switch self {
        case .mode: "tshirt"
        case .schmuck: "sparkle"
        case .tasche: "bag"
        case .tier: "pawprint"
        case .zimmer: "house"
        }
    }
}

/// One grid tile: a live preview (figure try-on).
struct ArtikelKachel: View {
    let artikel: ShopArtikel
    let besitzt: Bool
    let vorschauAussehen: FigurAussehen

    var body: some View {
        VStack(spacing: 4) {
            vorschau
                .frame(width: 84, height: 96)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(.loveaKarte)
                .overlay(alignment: .topTrailing) {
                    if besitzt {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .padding(5)
                    } else if artikel.exklusiv {
                        Image(systemName: "lock.fill").foregroundStyle(.white, .black.opacity(0.5)).padding(5)
                    }
                }
            Text(artikel.name).font(.caption2.weight(.semibold)).lineLimit(1)
            if !besitzt {
                Text("\(artikel.preis)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 84)
        .opacity(artikel.exklusiv && !besitzt ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(artikel.name), \(besitzt ? "besitzt du schon" : "\(artikel.preis) Punkte")")
    }

    /// p56: Schmuck ist an der ganzen Figur zu klein für die Kachel, hier steht das Stück groß.
    @ViewBuilder private var vorschau: some View {
        if artikel.kategorie == ShopKategorie.zimmer.rawValue {
            ZimmerTeilVorschau(id: artikel.id)
        } else if schmuckKatalog[artikel.id] != nil {
            Nahaufnahme(id: artikel.id)
        } else {
            FigurView(vorschauAussehen, zustand: .ruhig, groesse: 118, animiert: false, ganzkoerper: true)
        }
    }
}

/// Buy/wear sheet: bigger live preview, price, confirm-before-buy, "Nicht genug Punkte", Anziehen/Ausziehen.
private struct ArtikelDetail: View {
    let artikel: ShopArtikel
    let ziel: Person
    /// Wear/unwear only makes sense on the device's OWN figure — in gift mode you can't dress the partner.
    let istEigeneFigur: Bool
    let besitzt: Bool
    let verfuegbar: Int
    let onKauf: () -> Void
    let onAnziehen: () -> Void
    let onAusziehen: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var bestaetigen = false

    /// Computed, not passed in: re-reads `FigurenModell` (`@Observable`) each render, so the
    /// preview and the Anziehen/Ausziehen label update right after a wear toggle without closing
    /// the sheet — an op sent via `aussehenSichern` applies optimistically before confirmation.
    private var vorschauAussehen: FigurAussehen { FigurenModell.shared.aussehen(ziel).mitVorschau(artikel) }
    private var fehlend: Int { max(0, artikel.preis - verfuegbar) }
    private var zimmer: Bool { artikel.kategorie == ShopKategorie.zimmer.rawValue }
    private var getragen: Bool { zimmer ? ZimmerWahl.aktuell.traegt(artikel.id) : FigurenModell.shared.aussehen(ziel).traegt(artikel) }

    var body: some View {
        VStack(spacing: 18) {
            ArtikelBild(id: artikel.id, aussehen: vorschauAussehen)
            VStack(spacing: 4) {
                if let marke = artikel.marke { Text(marke).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                Text(artikel.name).font(.title3.bold())
                if !besitzt { Text("\(artikel.preis) Punkte").font(.headline).foregroundStyle(Color.loveaRose) }
            }
            aktion
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .medium), trigger: getragen)
        .confirmationDialog("„\(artikel.name)“ für \(artikel.preis) Punkte kaufen?", isPresented: $bestaetigen, titleVisibility: .visible) {
            Button("Kaufen") { onKauf(); dismiss() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    @ViewBuilder private var vorschau: some View {
        if zimmer {
            ZimmerTeilVorschau(id: artikel.id).clipShape(.loveaKarte)
        } else {
            ArtikelBild(id: artikel.id, aussehen: vorschauAussehen)
        }
    }

    @ViewBuilder private var aktion: some View {
        if besitzt {
            if istEigeneFigur {
                Button(zimmer ? (getragen ? "Wegräumen" : "Einrichten") : (getragen ? "Ausziehen" : "Anziehen")) {
                    getragen ? onAusziehen() : onAnziehen()
                }
                .buttonStyle(.borderedProminent)
                .tint(getragen ? Color(uiColor: .systemGray) : Color.loveaRose)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            } else {
                Label(istEigeneFigur ? "Du besitzt das schon" : "\(ziel.name) besitzt das schon", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        } else if artikel.exklusiv {
            Text("Nur als Belohnung für die Challenge „Gemeinsam Monat“ zu bekommen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        } else {
            Button {
                bestaetigen = true
            } label: {
                Text(fehlend > 0 ? "Nicht genug Punkte – dir fehlen \(fehlend)" : "Für \(artikel.preis) Punkte kaufen")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.loveaRose)
            .disabled(fehlend > 0)
            .padding(.horizontal, 24)
        }
    }
}

/// Vorschau im Detail: die Figur groß; p56: bei der Jeans (Blumen auf den Gesäßtaschen) und beim Schmuck daneben die Nahaufnahme.
struct ArtikelBild: View {
    let id: String
    let aussehen: FigurAussehen

    var body: some View {
        HStack(spacing: 12) {
            FigurView(aussehen, zustand: .ruhig, groesse: 300, animiert: false, ganzkoerper: true)
            if id == "mode.blumen-jeans" || schmuckKatalog[id] != nil {
                Nahaufnahme(id: id)
                    .frame(width: 180, height: 234)
                    .background(Color(uiColor: .secondarySystemBackground), in: .loveaKarte)
            }
        }
        .frame(height: 300)
    }
}

/// p56: Jeans von hinten und Schmuck groß, mit den Zeichnern der Figur (Vektor, scharf in jeder Größe). Feld 200 x 260.
struct Nahaufnahme: View {
    let id: String

    var body: some View {
        Canvas { c, s in
            let k = min(s.width / 200, s.height / 260)
            var g = c
            g.translateBy(x: (s.width - 200 * k) / 2, y: (s.height - 260 * k) / 2)
            g.scaleBy(x: k, y: k)
            guard let e = schmuckKatalog[id] else { return zeichneJeansRueckseite(g, farbe: FigurFarbe(0x3F6EAF)) }
            if e.stil.ort == .ohr {
                // Ein Ohr, groß: (42, 117) wandert in die Feldmitte.
                g.translateBy(x: 100, y: 130)
                g.scaleBy(x: 7, y: 7)
                g.translateBy(x: -42, y: -117)
                zeichneOhrschmuck(g, id: id)
            } else {
                let z: CGFloat = e.stil.ort == .hals ? 5 : e.stil.ort == .hand ? 12 : 7
                zeichneSchmuck(g, e.stil, e.farbe, hals: P(100, 70), arm: (ellbogen: P(100, 30), hand: P(100, 130)), bei: 1, groesse: z)
            }
        }
    }
}
