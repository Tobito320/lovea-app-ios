import SwiftUI

/// Z-41.1: the full-body figure standing on the map - elliptical ground shadow, a soft lift, the map
/// state (`KarteLogik.kartenZustand`) and the extras from weather and charging. Shared by the map
/// pins and the profile preview, so both always show the same figure.
/// No `poseImmer` any more: a bought pose would replace walking, charging and place poses; it still
/// shows whenever the figure just stands (`.ruhig`), FigurView's default branch.
struct KartenFigur: View {
    let person: Person
    let daten: StandortDaten
    var groesse: CGFloat = 130
    var animiert = true

    var body: some View {
        let zustand = self.zustand
        FigurView(
            FigurenModell.shared.aussehen(person), zustand: zustand, abzeichen: FigurenModell.shared.anzeige(person).abzeichen,
            groesse: groesse, animiert: animiert, bildrate: 20, ganzkoerper: true, extras: extras(zustand)
        )
        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
        .background(alignment: .bottom) { bodenSchatten }
    }

    /// Feet stand at y 372…392 of FigurView's 200 x 400 full-body canvas, so a shadow aligned to the
    /// frame's bottom sits right under the shoes.
    private var bodenSchatten: some View {
        Ellipse()
            .fill(Color.black.opacity(0.3))
            .frame(width: groesse * 0.34, height: groesse * 0.075)
            .blur(radius: groesse * 0.02)
    }

    private var zustand: FigurZustand {
        if let bis = OrteModell.shared.nahBis, bis > Date() { return .anstossen } // Zufällig nah (Z-8.5)
        return KarteLogik.kartenZustand(
            anzeige: FigurenModell.shared.anzeige(person).haupt,
            bewegung: daten.bewegung,
            ortKategorie: OrteModell.shared.ortBei(lat: daten.lat, lon: daten.lon)?.kategorie,
            sekundenAlt: daten.sekundenAlt ?? .infinity
        )
    }

    private func extras(_ zustand: FigurZustand) -> Set<FigurExtra> {
        let wetter = WetterModell.shared.staende[person]
        return KarteLogik.extras(
            wetterCode: wetter?.code, temperatur: wetter?.temperatur, tag: wetter?.tag ?? false,
            laedt: daten.laedt || zustand == .laedt
        )
    }
}
