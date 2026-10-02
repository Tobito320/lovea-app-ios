import SwiftUI

/// Die Kalender-Karte von Variante C auf Home: ruhiges Monatsraster mit Punkten, darunter das Blatt
/// des gewählten Tages. Diese Hülle liest Modell und `Raum` und hält den Zustand; alles Sichtbare
/// steckt in `RasterMonatInhalt` und `TagesBlatt`, die nur fertige Werte nehmen.
struct RasterMonat: View {
    /// Antippen von „Tag öffnen": der Tag geht auf den Home-Pfad (`KalenderTagZiel`).
    var oeffnen: (String) -> Void
    let kalender = KalenderModell.shared

    /// Der 1. des gezeigten Monats, `yyyy-MM-dd`.
    @State private var erster = String(Datum.text(Date()).prefix(8)) + "01"
    @State private var gewaehlt = Datum.text(Date())
    @State private var blatt: KalenderBlatt?
    @State private var treffenZiel: TreffenZiel?

    var body: some View {
        let daten = kalender.zustand.daten
        let heute = Datum.text(Date())
        VStack(spacing: 16) {
            RasterMonatInhalt(
                raster: kalender.monatsRaster(erster), daten: daten, erster: erster, heute: heute, gewaehlt: gewaehlt,
                waehle: { gewaehlt = $0 }, wechsle: { wechsleMonat($0) }, plus: { blatt = $0 }
            )
            TagesBlatt(
                tag: gewaehlt, daten: daten, ich: Raum.shared.ich,
                aktionen: .live(blatt: $blatt, treffen: { treffenZiel = TreffenZiel(datum: gewaehlt) }),
                oeffnen: { oeffnen(gewaehlt) }
            )
        }
        .kalenderBlaetter(tag: gewaehlt, blatt: $blatt)
        .navigationDestination(item: $treffenZiel) { TreffenTagView(datum: $0.datum) }
    }

    private func wechsleMonat(_ delta: Int) {
        Haptik.auswahl()
        let anfang = Datum.datum(erster)
        erster = Datum.text(Datum.kalender.date(byAdding: .month, value: delta, to: anfang) ?? anfang)
        gewaehlt = AnsichtWerte.tagNachMonatswechsel(erster: erster, heute: Datum.text(Date()))
    }
}

/// Kopf, Wochentage, Raster und Ferienzeile. Keine Rahmen, keine Tönung: Heute ist ein gefüllter
/// Kreis in Rosé, der gewählte Tag ein Kreis in `.primary`, darunter ein Punkt je Person mit
/// Termin und ein Herz für ein Treffen.
struct RasterMonatInhalt: View {
    let raster: MonatsRaster
    let daten: KalenderDaten
    /// Der 1. des Monats, `yyyy-MM-dd`.
    let erster: String
    let heute: String
    let gewaehlt: String
    /// Die Render-Tafel kann kein `Menu` zeichnen: dort steht ein einfaches „+".
    var statisch = false
    var waehle: (String) -> Void = { _ in }
    var wechsle: (Int) -> Void = { _ in }
    var plus: (KalenderBlatt) -> Void = { _ in }

    @ScaledMetric(relativeTo: .largeTitle) private var titelGroesse: CGFloat = 32

    private static let wochentage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        let marken = TagesWerte.marken(daten, monat: erster)
        VStack(spacing: 4) {
            kopf
            wochentagZeile
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(AnsichtWerte.wochenZeilen(raster.zellen).enumerated()), id: \.offset) { _, woche in
                    GridRow {
                        ForEach(Array(woche.enumerated()), id: \.offset) { _, zelle in
                            platz(zelle, marken: marken)
                        }
                    }
                }
            }
            ferienZeile
        }
        // Sieben Spalten passen ab AX-Größen nicht mehr; wie `MonatsAnsicht` deckeln statt abschneiden.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    // MARK: - Kopf

    private var kopf: some View {
        HStack(spacing: 0) {
            Text(raster.titel)
                .font(.system(size: titelGroesse, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            pfeil("chevron.left", "Vorheriger Monat", -1)
            pfeil("chevron.right", "Nächster Monat", 1)
            if statisch {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            } else {
                KalenderPlusMenue(waehle: plus)
            }
        }
        .frame(minHeight: 52)
    }

    private func pfeil(_ symbol: String, _ titel: String, _ delta: Int) -> some View {
        Button { wechsle(delta) } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle()) // sonst trifft nur das schmale Symbol
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel)
    }

    private var wochentagZeile: some View {
        HStack(spacing: 0) {
            ForEach(Self.wochentage, id: \.self) { kuerzel in
                Text(kuerzel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var ferienZeile: some View {
        if let text = TagesWerte.ferienZeile(monat: erster) {
            Label(text, systemImage: "sun.max")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
    }

    // MARK: - Raster

    @ViewBuilder
    private func platz(_ zelle: MonatsRaster.Zelle?, marken: [String: TagesMarken]) -> some View {
        if let zelle {
            tagKnopf(zelle, marken: marken[zelle.tag])
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 56)
        }
    }

    private func tagKnopf(_ zelle: MonatsRaster.Zelle, marken: TagesMarken?) -> some View {
        let istHeute = zelle.tag == heute
        let istGewaehlt = zelle.tag == gewaehlt
        return Button {
            Haptik.auswahl()
            waehle(zelle.tag)
        } label: {
            VStack(spacing: 3) {
                TagesKreis(nummer: zelle.nummer, heute: istHeute, gewaehlt: istGewaehlt)
                punkte(marken)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(AnsichtWerte.zellenText(anzeige: zelle.anzeige, marken: marken, heute: istHeute, gewaehlt: istGewaehlt))
        .accessibilityAddTraits(istGewaehlt ? .isSelected : [])
    }

    private func punkte(_ marken: TagesMarken?) -> some View {
        HStack(spacing: 3) {
            if marken?.ahmed == true { Circle().fill(Color.person(.ahmed)).frame(width: 6, height: 6) }
            if marken?.annika == true { Circle().fill(Color.person(.annika)).frame(width: 6, height: 6) }
            if marken?.treffen == true {
                Image(systemName: "heart.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(Color.loveaRose)
            }
        }
        .frame(height: 8)
    }
}

/// Die Zahl eines Tages im Kreis: Heute gefüllt in Rosé mit weißer Zahl, gewählt in `.primary` mit
/// Zahl in `systemBackground`. Heute und gewählt zugleich: Rosé mit Ring.
struct TagesKreis: View {
    let nummer: String
    let heute: Bool
    let gewaehlt: Bool

    @ScaledMetric(relativeTo: .body) private var groesse: CGFloat = 34

    var body: some View {
        Text(nummer)
            .font(.body.weight(heute || gewaehlt ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(zahlFarbe)
            .frame(width: groesse, height: groesse)
            .background(Circle().fill(fuellung))
            .overlay { if heute && gewaehlt { Circle().strokeBorder(Color.primary, lineWidth: 2) } }
    }

    private var fuellung: Color {
        if heute { return Color.loveaRose }
        return gewaehlt ? Color.primary : Color.clear
    }

    private var zahlFarbe: Color {
        if heute { return .white }
        return gewaehlt ? Color(uiColor: .systemBackground) : Color.primary
    }
}
