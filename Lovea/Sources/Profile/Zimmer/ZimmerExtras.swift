import SwiftUI

/// p63: was im Zuhause außer den beiden noch lebt. Ein Wert, der alles trägt, was das Overlay zeichnet:
/// so zeichnet es nur neu, wenn sich etwas davon ändert.
struct ZimmerExtrasStand: Equatable {
    var deko: ZimmerDeko
    var countdown: ZimmerCountdown.Stand
    /// Der Tag des nächsten Treffens, für den Hinweis beim Tippen auf das Schild.
    var treffen: String?
    var pins: [GlobusPin]
    var augen: Int

    /// Der Stand von jetzt. Beziehungsbeginn ohne Eintrag: 26.08.2026, wie bei den Abzeichen.
    @MainActor
    static func live(am jetzt: Date = Date()) -> ZimmerExtrasStand {
        let kalender = KalenderModell.shared
        let jahrestag = Datum.datum(kalender.zustand.jahrestag ?? "2026-08-26")
        let treffen = kalender.naechstesTreffen?.datum
        let tag = Calendar.berlin.ordinality(of: .day, in: .year, for: jetzt) ?? 1
        return ZimmerExtrasStand(
            deko: ZimmerDeko.fuer(tag: jetzt, jahrestag: jahrestag),
            countdown: ZimmerCountdown.stand(treffen: treffen, heute: Datum.text(jetzt)),
            treffen: treffen,
            pins: ZimmerGlobus.pins(DateSpeicher.shared.ideen),
            augen: ZimmerWuerfel.augen(zahl: tag)
        )
    }
}

/// p63: das Overlay im Zuhause (Entwurfsraum 390 x 430 wie die Bühne): Deko nach Anlass, Schild mit Koffer,
/// Regal mit Album und Globus, Würfel auf dem Tisch. Alles steht still; die Tipp-Flächen öffnen je ein Blatt.
///
/// Akku: beim Start wird nichts geladen (Blätter und Fotos erst beim Öffnen), nichts läuft von selbst.
/// Die einzige Bewegung ist die Feier am Tag des Wiedersehens: eine Animation von 2,6 s, einmal je Tag,
/// nicht bei "Bewegung reduzieren" und nicht im Stromsparmodus.
struct ZimmerExtras: View {
    let stand: ZimmerExtrasStand
    let s: CGFloat
    let oben: CGFloat
    /// p65: `.panorama` setzt Schild, Regal, Würfel und Deko an ihre Plätze in der breiten Welt.
    var welt: ProfilWelt = .einzel

    private enum Blatt: String, Identifiable {
        case wuerfel, globus, album
        var id: String { rawValue }
    }

    @State private var blatt: Blatt?
    @State private var hinweis = false
    @State private var feier = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let regalAlbum = CGPoint(x: 306, y: 126)
    private static let regalGlobus = CGPoint(x: 355, y: 108)

    var body: some View {
        ZStack(alignment: .topLeading) {
            let stand = stand
            let welt = welt
            Canvas { g, groesse in
                let w = SzenenZeichnung.raum(g, groesse, welt: welt)
                welt.zeichne(w, .fenster) { ZimmerDekoZeichnung.zeichne($0, stand.deko) }
                welt.zeichne(w, .regalDeko) { regal($0, stand) }
                welt.zeichne(w, .countdown) {
                    ZimmerCountdownZeichnung.zeichne($0, text: ZimmerCountdown.text(stand.countdown), heute: stand.countdown == .heute)
                }
                welt.zeichne(w, .kommode) {
                    ZimmerWuerfelZeichnung.zeichne($0, mitte: ZimmerWuerfelZeichnung.ort, kante: ZimmerWuerfelZeichnung.kante, augen: stand.augen, drehung: 0.22)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            ZimmerFeierBild(fortschritt: feier, welt: welt)
            flaeche(welt.ort(ZimmerWuerfelZeichnung.ort, .kommode), 34, 34, "Date-Würfel") { blatt = .wuerfel }
            flaeche(welt.ort(Self.regalGlobus, .regalDeko), 40, 48, "Globus mit Wunschliste") { blatt = .globus }
            flaeche(welt.ort(Self.regalAlbum, .regalDeko), 44, 44, "Erinnerungsalbum") { blatt = .album }
            flaeche(welt.ort(CGPoint(x: ZimmerCountdownZeichnung.ort.x, y: ZimmerCountdownZeichnung.ort.y + 18), .countdown), 76, 74, ZimmerCountdown.text(stand.countdown) + " bis zum Wiedersehen") { hinweis = true }
        }
        .sheet(item: $blatt) { b in
            switch b {
            case .wuerfel: ZimmerWuerfelBlatt()
            case .globus: ZimmerGlobusBlatt()
            case .album: ZimmerAlbumBlatt(nachrichten: ChatModell.shared.nachrichten, ich: Raum.shared.ich, briefe: ZimmerAlbumLogik.liebesbriefe(BriefeSpeicher.shared.stand))
            }
        }
        .alert("Wiedersehen", isPresented: $hinweis) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(hinweisText)
        }
        .task(id: stand.countdown) { await feiern() }
    }

    private var hinweisText: String {
        guard let treffen = stand.treffen, stand.countdown != .keins else { return "Noch kein Treffen im Kalender." }
        return Datum.anzeige(treffen)
    }

    private func regal(_ g: GraphicsContext, _ stand: ZimmerExtrasStand) {
        let holz = Pal.holz
        for x in [296, 366] as [CGFloat] {
            teil(g, Path { p in
                p.move(to: P(x - 3, 132))
                p.addLine(to: P(x + 3, 132))
                p.addLine(to: P(x - 3, 140))
                p.closeSubpath()
            }, holz.mal(0.85), 1.2)
        }
        teil(g, box(286, 126, 96, 6, 2), holz, 1.8)
        ZimmerAlbumZeichnung.zeichne(g, fuss: Self.regalAlbum)
        ZimmerGlobusZeichnung.zeichneImRegal(g, mitte: Self.regalGlobus, radius: 14, zentrum: ZimmerGlobus.mitte(stand.pins), pins: stand.pins)
    }

    /// Unsichtbare Tipp-Fläche um einen Punkt des Entwurfsraums.
    private func flaeche(_ mitte: CGPoint, _ b: CGFloat, _ h: CGFloat, _ name: String, _ aktion: @escaping () -> Void) -> some View {
        // In the panorama every tap area is at least 44 pt (the slots leave room for it).
        let mindest: CGFloat = welt == .panorama ? ProfilSlots.tippMinimum : 0
        return Button(action: aktion) { Color.clear }
            .buttonStyle(.plain)
            .frame(width: max(b * s, mindest), height: max(h * s, mindest))
            .contentShape(Rectangle())
            .position(x: mitte.x * s, y: oben + mitte.y * s)
            .accessibilityLabel(name)
    }

    /// Einmal je Tag am Tag des Wiedersehens: Herzen und Konfetti steigen vom Schild auf.
    private func feiern() async {
        guard ZimmerCountdown.feiern(stand.countdown, heute: Datum.text(Date())),
              !reduceMotion, !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        withAnimation(.easeOut(duration: 2.6)) { feier = 1 }
        try? await Task.sleep(for: .seconds(2.8))
        feier = 0
    }
}
