import SwiftUI

/// Unser Zimmer, Worker H: gemeinsame Sammlungen als Overlay über `ZuhauseBuehne` (Welt 975 x 430, unten verankert).
/// Mixtape-Regal, Rezeptkasten, Wunschrolle (mit Aufklebern am Kühlschrank), Stimmungsregenbogen,
/// Wachstumsleiste und Dankbarkeitsbaum. Kein Takt: alles ist Tippen, Sync-Werte (`zimmer.*`) oder lokales Zählen.
struct ZimmerSammlungEbene: View {
    private let welt: ProfilWelt
    private let eigen: Bool

    // Orte in Entwurfseinheiten (für ZimmerPlatzLogik)
    static let kassetteRect = CGRect(x: 522, y: 14, width: 44, height: 26)
    static let wunschrolleRect = CGRect(x: 318, y: 6, width: 34, height: 44)
    static let regenbogenRect = CGRect(x: 676, y: 22, width: 84, height: 48)
    static let massRect = CGRect(x: 748, y: 178, width: 16, height: 84)
    static let rezeptRect = CGRect(x: 570, y: 372, width: 40, height: 30)
    static let baumRect = CGRect(x: 806, y: 290, width: 44, height: 64)
    static let alleRects: [CGRect] = [kassetteRect, wunschrolleRect, regenbogenRect, massRect, rezeptRect, baumRect]

    private enum Blatt: String, Identifiable {
        case kassetten, rezepte, wuensche, wachstum
        var id: String { rawValue }
    }

    @State private var blatt: Blatt?
    @State private var hinweis: String?
    @State private var tipp = 0
    @State private var dankeAnzahl = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(welt: ProfilWelt = .panorama, eigen: Bool = true) {
        self.welt = welt
        self.eigen = eigen
    }

    private typealias SD = ZimmerSammlungDaten
    private typealias SL = ZimmerSammlungLogik
    private typealias Z = ZimmerSammlungZeichnung

    private var ich: Person { SD.ich }
    private var meineStimmung: Gefuehl? { SignaleSpeicher.shared.stimmung(von: ich) }
    private var herbst: Bool { SL.istHerbst(Date()) }
    private var anzahlChat: Int { ChatModell.shared.nachrichten.count }

    var body: some View {
        if welt == .panorama && eigen {
            GeometryReader { geo in
                let s = geo.size.width / welt.breite
                let oben = geo.size.height - ZuhauseZeichnung.hoehe * s
                ZStack(alignment: .topLeading) {
                    aufkleber(s, oben)
                    kassette(s, oben)
                    wunschrolle(s, oben)
                    regenbogen(s, oben)
                    mass(s, oben)
                    rezept(s, oben)
                    baum(s, oben)
                    if let hinweis { pille(hinweis).position(x: geo.size.width / 2, y: oben + 30 * s) }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: tipp)
            .onAppear { aktualisieren() }
            .onChange(of: meineStimmung, initial: true) { _, neu in SD.stimmungMerken(neu) }
            .onChange(of: anzahlChat) { _, _ in aktualisieren() }
            .sheet(item: $blatt) { b in
                switch b {
                case .kassetten: ZimmerKassettenBlatt()
                case .rezepte: ZimmerRezeptBlatt()
                case .wuensche: ZimmerWunschrolleBlatt()
                case .wachstum: ZimmerWachstumBlatt()
                }
            }
        }
    }

    private func aktualisieren() { dankeAnzahl = SD.dankeBlaetter() }

    // MARK: Bausteine

    private func ding<V: View>(_ rect: CGRect, _ s: CGFloat, _ oben: CGFloat, name: String, tippen: @escaping () -> Void,
                               @ViewBuilder _ inhalt: () -> V) -> some View {
        Button {
            tipp += 1
            tippen()
        } label: {
            inhalt().padding(8)
                .frame(minWidth: ProfilSlots.tippMinimum, minHeight: ProfilSlots.tippMinimum)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .position(x: rect.midX * s, y: oben + rect.midY * s)
    }

    private func pille(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: .capsule)
            .transition(.opacity)
            .allowsHitTesting(false)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func zeigen(_ text: String) {
        withAnimation(reduceMotion ? nil : Feder.schnell) { hinweis = text }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if hinweis == text { withAnimation(reduceMotion ? nil : Feder.schnell) { hinweis = nil } }
        }
    }

    // MARK: 3 Mixtape

    private func kassette(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let n = SD.kassetten(von: ich).count + SD.kassetten(von: ich.partner).count
        return ding(Self.kassetteRect, s, oben, name: "Mixtape-Regal, \(n) Kassetten", tippen: { blatt = .kassetten }) {
            Z.Kassette(anzahl: n, e: s)
        }
    }

    // MARK: 5 Rezeptkasten

    private func rezept(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let n = SD.alleRezepte().count
        return ding(Self.rezeptRect, s, oben, name: "Rezeptkasten, \(n) Karten", tippen: { blatt = .rezepte }) {
            Z.Rezeptkasten(karten: n, e: s)
        }
    }

    // MARK: 9 Wunschrolle und Aufkleber

    private func wunschrolle(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let alle = SD.alleWuensche()
        let fertig = SD.erledigt()
        let erledigt = alle.filter { fertig.contains($0.id) }.count
        return ding(Self.wunschrolleRect, s, oben,
                    name: "Wunschrolle, \(erledigt) von \(alle.count) gemeinsam erledigt", tippen: { blatt = .wuensche }) {
            Z.Wunschrolle(offen: alle.count - erledigt, erledigt: erledigt, e: s)
        }
    }

    /// Erledigte Wünsche kleben als Sterne am Kühlschrank. Nur Zeichnung, kein Tippen.
    @ViewBuilder private func aufkleber(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let alle = SD.alleWuensche()
        let fertig = SD.erledigt()
        let n = SL.aufkleber(erledigt: alle.filter { fertig.contains($0.id) }.count)
        if n > 0 {
            let r = ProfilSlots.welt(.kuehl)
            Z.Aufkleber(anzahl: n, e: s)
                .position(x: r.midX * s, y: oben + (r.minY + 14) * s)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: 16 Stimmungsregenbogen

    @ViewBuilder private func regenbogen(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let tage = SL.letzteTage(heute: SD.heute)
        let meine = SL.bogen(SD.verlauf(von: ich), tage: tage)
        let partner = SL.bogen(SD.verlauf(von: ich.partner), tage: tage)
        if meine.contains(where: { $0 != nil }) || partner.contains(where: { $0 != nil }) {
            ding(Self.regenbogenRect, s, oben, name: "Stimmungsregenbogen der letzten sieben Tage", tippen: {
                zeigen("Außen deine Woche, innen die von \(ich.partner.name)")
            }) { Z.Regenbogen(aussen: meine, innen: partner, e: s) }
        }
    }

    // MARK: 6 Wachstumsleiste

    private func mass(_ s: CGFloat, _ oben: CGFloat) -> some View {
        let liste = SL.marken(heute: SD.heute, start: Meilenstein.start, eigene: SD.eigeneMarken())
        let erreicht = liste.filter(\.erreicht).count
        return ding(Self.massRect, s, oben, name: "Wachstumsleiste, \(erreicht) Meilensteine erreicht", tippen: { blatt = .wachstum }) {
            Z.Wachstumsleiste(erreicht: erreicht, gesamt: liste.count, e: s)
        }
    }

    // MARK: 17 Dankbarkeitsbaum

    @ViewBuilder private func baum(_ s: CGFloat, _ oben: CGFloat) -> some View {
        if dankeAnzahl > 0 {
            let verteilt = SL.blaetter(gesamt: dankeAnzahl, herbst: herbst)
            ding(Self.baumRect, s, oben, name: "Dankbarkeitsbaum, \(dankeAnzahl) Blätter", tippen: {
                zeigen(herbst && verteilt.haufen > 0
                       ? "\(dankeAnzahl) Mal Danke. Der Herbst legt Blätter in den Haufen"
                       : "\(dankeAnzahl) Mal Danke gesagt")
            }) {
                Z.Baum(baum: SL.sichtbar(verteilt.baum, maximal: 24), haufen: verteilt.haufen, herbst: herbst, e: s)
            }
        }
    }
}
