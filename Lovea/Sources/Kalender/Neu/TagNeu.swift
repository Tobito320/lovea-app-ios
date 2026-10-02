import SwiftUI

/// Die Tagesansicht von Variante C. Diese Hülle liest Modell und `Raum`, hält den Tag (der
/// Wochenstreifen wechselt ihn) und die Blätter. Das Sichtbare steckt in `TagNeuInhalt`.
struct TagNeu: View {
    @State private var tag: String
    let kalender = KalenderModell.shared
    @State private var blatt: KalenderBlatt?
    @State private var treffenZiel: TreffenZiel?

    init(tag: String) {
        _tag = State(initialValue: tag)
    }

    var body: some View {
        ScrollView {
            TagNeuInhalt(
                tag: tag, daten: kalender.zustand.daten, heute: Datum.text(Date()), ich: Raum.shared.ich,
                aktionen: .live(blatt: $blatt, treffen: { treffenZiel = TreffenZiel(datum: tag) }),
                waehle: { tag = $0 }
            )
            .padding()
        }
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { KalenderPlusMenue(waehle: { blatt = $0 }) }
        }
        .kalenderBlaetter(tag: tag, blatt: $blatt)
        .navigationDestination(item: $treffenZiel) { TreffenTagView(datum: $0.datum) }
    }
}

/// Wochenstreifen, Datum groß, drei Balken (Ahmed, Annika, zusammen), dann die `TagesListe`.
/// Ohne `ScrollView`, damit die Render-Tafel es zeichnen kann.
struct TagNeuInhalt: View {
    let tag: String
    let daten: KalenderDaten
    let heute: String
    let ich: Person?
    var aktionen = TagesAktionen()
    var waehle: (String) -> Void = { _ in }

    @ScaledMetric(relativeTo: .title) private var datumGroesse: CGFloat = 28

    var body: some View {
        let ahmed = Wochenplan.tag(tag, person: Person.ahmed.rawValue, daten: daten)
        let annika = Wochenplan.tag(tag, person: Person.annika.rawValue, daten: daten)
        VStack(alignment: .leading, spacing: 16) {
            streifen
            Text(Datum.anzeige(tag))
                .font(.system(size: datumGroesse, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 8) {
                balkenZeile(Person.ahmed.name, Color.person(.ahmed), TagesWerte.personenBalken(ahmed), symbol: nil)
                balkenZeile(Person.annika.name, Color.person(.annika), TagesWerte.personenBalken(annika), symbol: nil)
                balkenZeile("zusammen", Color.kalenderGruen, TagesWerte.zusammenBalken(ahmed + annika), symbol: "sparkles")
                achse
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Zeitachse von 8 bis 22 Uhr, die Zeiten stehen in der Liste darunter")
            TagesListe(tag: tag, daten: daten, ich: ich, aktionen: aktionen)
        }
    }

    // MARK: - Wochenstreifen

    private var streifen: some View {
        HStack(spacing: 0) {
            ForEach(AnsichtWerte.wochenTage(tag), id: \.self) { tag in
                streifenTag(tag)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func streifenTag(_ tag: String) -> some View {
        let gewaehlt = tag == self.tag
        return Button {
            Haptik.auswahl()
            waehle(tag)
        } label: {
            VStack(spacing: 4) {
                Text(AnsichtWerte.kurz(tag))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TagesKreis(nummer: String(Int(tag.suffix(2)) ?? 0), heute: tag == heute, gewaehlt: gewaehlt)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(Datum.anzeige(tag) + (tag == heute ? ", heute" : "") + (gewaehlt ? ", gewählt" : ""))
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }

    // MARK: - Balken

    private func balkenZeile(_ titel: String, _ farbe: Color, _ segmente: [BalkenSegment], symbol: String?) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol).font(.caption)
                } else {
                    Circle().frame(width: 6, height: 6)
                }
                Text(titel).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(farbe)
            .frame(width: 84, alignment: .leading)
            TagesBalken(segmente: segmente, farbe: farbe)
        }
    }

    /// Beschriftung 8, 12, 16, 20 Uhr unter den Balken, an derselben Stelle wie die Balken selbst.
    private var achse: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 84, height: 1)
            GeometryReader { geo in
                ForEach([8, 12, 16, 20], id: \.self) { stunde in
                    Text("\(stunde)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .position(x: AnsichtWerte.anteil(stunde * 60) * geo.size.width, y: 7)
                }
            }
            .frame(height: 14)
        }
    }
}

/// Ein Tagesbalken 8 bis 22 Uhr, Höhe 12. Alltag blass in der Personenfarbe, Termin kräftig,
/// gemeinsam frei grün, Treffen Rosé.
struct TagesBalken: View {
    let segmente: [BalkenSegment]
    let farbe: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                ForEach(Array(segmente.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(fuellung(segment.art))
                        .frame(width: max((AnsichtWerte.anteil(segment.bis) - AnsichtWerte.anteil(segment.von)) * geo.size.width, 3))
                        .offset(x: AnsichtWerte.anteil(segment.von) * geo.size.width)
                }
            }
        }
        .frame(height: 12)
        .clipShape(Capsule())
    }

    private func fuellung(_ art: BalkenArt) -> Color {
        switch art {
        case .alltag: farbe.opacity(0.35)
        case .termin: farbe
        case .frei: Color.kalenderGruen
        case .treffen: Color.loveaRose
        }
    }
}
