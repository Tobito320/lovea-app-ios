import SwiftUI

/// p65 A2: where a horizontal swipe of the panorama comes to rest. The zone anchors of `ProfilSlots`
/// (design units) turned into points by the width of the scroll view, so a flick always ends with one
/// zone filling the screen.
struct ProfilZonenSnap: ScrollTargetBehavior {
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let einheit = context.containerSize.width / ProfilSlots.ansichtBreite
        guard einheit > 0 else { return }
        target.rect.origin.x = ProfilPanoramaLayout.naechsterAnker(target.rect.minX / einheit) * einheit
    }
}

/// p65 A2: the profile scene as a panorama. `welt` is the whole world (975 design units wide, built by the
/// caller with `ProfilWelt.panorama`), swiped sideways and snapping to the three zones; the wall behind it
/// is its own, wider-than-the-screen layer that moves at 60 % of the furniture's speed (parallax).
/// `schwebend` floats over the scene and does not move (online chip, gear). Under the scene sit the zone
/// tabs. `hoehe` is the scene's height including the status bar the wall bleeds into; the world is
/// anchored to the bottom of it, so it stays whole whatever `hoehe` is.
struct ProfilPanorama<Welt: View, Schwebend: View>: View {
    let wahl: ZimmerWahl
    let breite: CGFloat
    let hoehe: CGFloat
    private let welt: Welt
    private let schwebend: Schwebend

    /// Starts in the middle (living), where the sofa and the TV are.
    @State private var position = ScrollPosition(edge: .leading)
    @State private var zone = ProfilZone.wohn
    /// p70: when a tab last sent the scroll, so the jump it causes gets no second haptic.
    @State private var letzterTab = Date.distantPast
    /// The start position is set once. `.task` runs again whenever the profile comes back (a pushed page
    /// closes, the tab is chosen again) and would swing the panorama back to the middle each time.
    @State private var gestartet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(wahl: ZimmerWahl, breite: CGFloat, hoehe: CGFloat, @ViewBuilder welt: () -> Welt, @ViewBuilder schwebend: () -> Schwebend) {
        self.wahl = wahl
        self.breite = breite
        self.hoehe = hoehe
        self.welt = welt()
        self.schwebend = schwebend()
    }

    var body: some View {
        let k = ProfilPanoramaLayout.massstab(breite: breite)
        VStack(spacing: 0) {
            szene(k)
            zonenLeiste(k)
        }
    }

    private func szene(_ k: CGFloat) -> some View {
        let weltBreite = ProfilSlots.weltBreite * k
        return ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                wand(k)
                welt.frame(width: weltBreite, height: hoehe)
            }
            .frame(width: weltBreite, height: hoehe, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .scrollTargetBehavior(ProfilZonenSnap())
        // p70: a swipe that comes to rest in another zone clicks once, like the tabs.
        .onChange(of: zone) { _, _ in
            if ZuhauseSzeneLogik.zonenHaptik(sekundenSeitTab: Date().timeIntervalSince(letzterTab)) { Haptik.auswahl() }
        }
        // Only a change of zone invalidates this, not every point of the swipe.
        .onScrollGeometryChange(for: ProfilZone.self) { ProfilPanoramaLayout.zone(offset: $0.contentOffset.x / k) } action: { _, neu in
            zone = neu
        }
        // The swipe is the panorama's, not the tab's (the tab swipe still works under the scene).
        .simultaneousGesture(
            DragGesture(minimumDistance: 20).onChanged { wert in
                if abs(wert.translation.width) > abs(wert.translation.height) { TabWischSperre.shared.beanspruchen() }
            }
        )
        .task {
            guard !gestartet else { return }
            gestartet = true
            position.scrollTo(x: ProfilSlots.anker(.wohn) * k)
        }
        .background(FigurFarbe(wahl.teil(.wand).farbe).farbe)
        .overlay(alignment: .top) { schwebend }
        // p70: a gift waiting in the vase, and "Annika hat etwas gestellt".
        .overlay(alignment: .bottom) { ZimmerHinweisLeiste() }
        .frame(width: breite, height: hoehe)
        .clipped()
    }

    /// The wall, 741 units wide, bottom-anchored like the world. In the scrolled content it would move
    /// as fast as the furniture; the offset pushes it back by 40 % of the scroll, so it moves slower.
    private func wand(_ k: CGFloat) -> some View {
        ProfilWandSchicht(wahl: wahl, k: k, hoehe: hoehe)
        .visualEffect { inhalt, proxy in
            let weg = min(max(-proxy.frame(in: .scrollView).minX, 0), ProfilPanoramaLayout.maxOffset * k)
            return inhalt.offset(x: (1 - ProfilPanoramaLayout.wandFaktor) * weg)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Zone tabs

    private func zonenLeiste(_ k: CGFloat) -> some View {
        ProfilZonenLeiste(zone: zone) { gehe($0, k) }
    }

    private func gehe(_ z: ProfilZone, _ k: CGFloat) {
        Haptik.auswahl()
        letzterTab = Date()
        withAnimation(reduceMotion ? nil : Feder.weich) { position.scrollTo(x: ProfilSlots.anker(z) * k) }
    }
}

/// p65 A2: the wall layer of the panorama, `ProfilPanoramaLayout.wandBreite` design units wide and anchored to
/// the bottom of `hoehe` like the world. `k` is points per design unit. Its own view so the render board
/// draws the very same layer the app scrolls.
struct ProfilWandSchicht: View {
    let wahl: ZimmerWahl
    let k: CGFloat
    let hoehe: CGFloat

    var body: some View {
        let wahl = wahl, k = k
        Canvas { g, groesse in
            var w = g
            w.translateBy(x: 0, y: groesse.height - SzenenZeichnung.hoehe * k)
            w.scaleBy(x: k, y: k)
            ZuhauseZeichnung.wand(w, wahl, breite: ProfilPanoramaLayout.wandBreite)
        }
        .frame(width: ProfilPanoramaLayout.wandBreite * k, height: hoehe)
    }
}

/// p65 A2: "Annika ist online" as a small chip floating in the scene: the one avatar of the profile with its
/// green dot, and the words only while the other one is really there. Otherwise the chip names the next
/// milestone ("noch 18 Tage bis 2 Monate"), and the ring round the avatar fills toward it either way.
struct ProfilOnlineChip: View {
    let person: Person
    let online: Bool

    var body: some View {
        let meilenstein = Meilenstein.naechster(heute: Datum.text(Date()))
        HStack(spacing: 8) {
            ProfilAvatar(person: person, online: online, d: 30, fortschritt: meilenstein.fortschritt)
            Text(online ? "\(person.name) ist online" : meilenstein.text)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(online ? "online" : "offline"), \(meilenstein.text)")
    }
}
