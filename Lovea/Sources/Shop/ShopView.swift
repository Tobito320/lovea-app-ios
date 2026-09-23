import SwiftUI

/// Z-23.2: categories, grid of item previews (each tile a live "try-on" on the target figure, or
/// the theme/flame/backdrop's own preview), a bigger live preview + buy/wear sheet, gift mode.
/// Reachable from the own profile (Profile/) and the figure editor (Einstellungen/).
struct ShopView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kategorie = ShopKategorie.mode
    @State private var geschenkModus = false
    @State private var ausgewaehlt: ShopArtikel?
    @State private var gekauft = 0

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var ziel: Person { geschenkModus ? ich.partner : ich }

    /// One fold per render instead of one per tile (80+ items) — see `PunkteModell.einkaufsStand`.
    private var stand: (verfuegbar: [Person: Int], besitz: BesitzLogik.Ergebnis) {
        PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis })
    }

    var body: some View {
        NavigationStack {
            let info = stand
            VStack(spacing: 0) {
                kopf(info)
                kategorienLeiste
                Divider()
                ScrollView { gitter(info).padding(16) }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .sensoryFeedback(.success, trigger: gekauft)
            .sheet(item: $ausgewaehlt) { artikel in
                ArtikelDetail(
                    artikel: artikel, ziel: ziel, istEigeneFigur: ziel == ich,
                    besitzt: stand.besitz.besitzt(artikel.id, ziel), verfuegbar: stand.verfuegbar[ich] ?? 0,
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
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var kategorienLeiste: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopKategorie.allCases) { k in
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
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Gitter

    private func gitter(_ info: (verfuegbar: [Person: Int], besitz: BesitzLogik.Ergebnis)) -> some View {
        let artikel = ShopKatalog.alle.filter { $0.kategorie == kategorie.rawValue && $0.sichtbar(fuer: ziel) }
        let aussehenZiel = FigurenModell.shared.aussehen(ziel)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 14) {
            ForEach(artikel) { a in
                Button { ausgewaehlt = a } label: {
                    ArtikelKachel(artikel: a, besitzt: info.besitz.besitzt(a.id, ziel), vorschauAussehen: aussehenZiel.mitVorschau(a))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Aktionen

    private func kaufen(_ artikel: ShopArtikel) {
        guard PunkteModell.shared.kaufen(artikel: artikel.id, fuer: ziel, preis: { ShopKatalog.artikel($0)?.preis }) else { return }
        gekauft += 1
    }

    private func anziehen(_ artikel: ShopArtikel) {
        var a = FigurenModell.shared.aussehen(ich)
        a.anziehen(artikel)
        FigurenModell.shared.aussehenSichern(a)
    }

    private func ausziehen(_ artikel: ShopArtikel) {
        var a = FigurenModell.shared.aussehen(ich)
        a.ausziehen(artikel, person: ich)
        FigurenModell.shared.aussehenSichern(a)
    }
}

private enum ShopKategorie: String, CaseIterable, Identifiable {
    case mode, tasche, uhr, schmuck, brille, backdrop, chatTheme, flamme, pose, tier
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .mode: "Mode"
        case .tasche: "Taschen"
        case .uhr: "Uhren"
        case .schmuck: "Schmuck"
        case .brille: "Brillen"
        case .backdrop: "Backdrops"
        case .chatTheme: "Chat-Themes"
        case .flamme: "Flammen"
        case .pose: "Posen & Tänze"
        case .tier: "Haustiere"
        }
    }

    var symbol: String {
        switch self {
        case .mode: "tshirt"
        case .tasche: "bag"
        case .uhr: "clock"
        case .schmuck: "sparkles"
        case .brille: "eyeglasses"
        case .backdrop: "photo"
        case .chatTheme: "paintpalette"
        case .flamme: "flame"
        case .pose: "figure.dance"
        case .tier: "pawprint"
        }
    }
}

/// One grid tile: a live preview (figure try-on, or the theme's/flame's/backdrop's own preview).
private struct ArtikelKachel: View {
    let artikel: ShopArtikel
    let besitzt: Bool
    let vorschauAussehen: FigurAussehen

    var body: some View {
        VStack(spacing: 4) {
            vorschau
                .frame(width: 84, height: 96)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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

    @ViewBuilder private var vorschau: some View {
        switch artikel.kategorie {
        case "chatTheme":
            if let t = ChatThemes.von(artikel.id) { ChatThemePreviewView(thema: t) }
        case "flamme":
            if let f = Flammen.von(artikel.id) { FlammenPreviewView(flamme: f) }
        case "backdrop":
            BackdropView(id: artikel.id)
        default:
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
    private var getragen: Bool { vorschauAussehen.traegt(artikel) }
    private var direktTeil: Bool { !["chatTheme", "flamme", "backdrop"].contains(artikel.kategorie) }

    var body: some View {
        VStack(spacing: 18) {
            vorschau.frame(height: 220).frame(maxWidth: .infinity)
            VStack(spacing: 4) {
                if let marke = artikel.marke { Text(marke).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                Text(artikel.name).font(.title3.bold())
                if !besitzt { Text("\(artikel.preis) Punkte").font(.headline).foregroundStyle(Color.loveaRose) }
            }
            aktion
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .medium), trigger: getragen)
        .confirmationDialog("„\(artikel.name)“ für \(artikel.preis) Punkte kaufen?", isPresented: $bestaetigen, titleVisibility: .visible) {
            Button("Kaufen") { onKauf(); dismiss() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    @ViewBuilder private var vorschau: some View {
        switch artikel.kategorie {
        case "chatTheme":
            if let t = ChatThemes.von(artikel.id) { ChatThemePreviewView(thema: t).scaleEffect(2.4) }
        case "flamme":
            if let f = Flammen.von(artikel.id) { FlammenPreviewView(flamme: f).scaleEffect(2.4) }
        case "backdrop":
            BackdropView(id: artikel.id).clipShape(RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 24)
        default:
            FigurView(vorschauAussehen, zustand: .ruhig, groesse: 260, animiert: false, ganzkoerper: true)
        }
    }

    @ViewBuilder private var aktion: some View {
        if besitzt {
            if istEigeneFigur && direktTeil {
                Button(getragen ? "Ausziehen" : "Anziehen") {
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
