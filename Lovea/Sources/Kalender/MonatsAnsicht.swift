import SwiftUI

/// Z-9.5 / Z-42.1: Monatsraster. Jede Zelle ist fein umrandet und senkrecht geteilt, links Ahmed,
/// rechts Annika. Schule tönt die Hälfte kräftig, Arbeit hell, dazu Buch oder Koffer; Termin als
/// Punkt, Treffen als Herz. Wischen wechselt den Monat, antippen ruft `onTagWaehlen` mit dem
/// `yyyy-MM-dd`-String. Die Werte kommen fertig aus `KalenderModell.monatsRaster`.
struct MonatsAnsicht: View {
    let kalender = KalenderModell.shared
    var onTagWaehlen: (String) -> Void

    /// Der 1. des gezeigten Monats, `yyyy-MM-dd`.
    @State private var erster = String(Datum.text(Date()).prefix(8)) + "01"

    private static let wochentagsKuerzel = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private static let spalten = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let raster = kalender.monatsRaster(erster)
        let heute = Datum.text(Date())
        VStack(spacing: 10) {
            kopf(raster.titel)
            wochentage
            LazyVGrid(columns: Self.spalten, spacing: 4) {
                ForEach(Array(raster.zellen.enumerated()), id: \.offset) { _, zelle in
                    if let zelle {
                        tagKnopf(zelle, heute: zelle.tag == heute)
                    } else {
                        Color.clear.frame(height: MonatsZelle.hoehe)
                    }
                }
            }
        }
        // Sieben Spalten (und der Monatsname zwischen den Pfeilen) passen ab AX-Größen nicht mehr;
        // wie der System-Kalender deckeln statt abschneiden. VoiceOver liest jeden Tag voll vor.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { wert in
                    if wert.translation.width < -30 { wechsleMonat(1) }
                    else if wert.translation.width > 30 { wechsleMonat(-1) }
                }
        )
    }

    private func kopf(_ titel: String) -> some View {
        HStack {
            pfeil("chevron.left", "Vorheriger Monat", -1)
            Spacer()
            Text(titel)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            pfeil("chevron.right", "Nächster Monat", 1)
        }
        .frame(minHeight: 44)
    }

    private func pfeil(_ symbol: String, _ titel: String, _ delta: Int) -> some View {
        Button { wechsleMonat(delta) } label: {
            Image(systemName: symbol)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle()) // sonst trifft nur das schmale Symbol
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel)
    }

    private var wochentage: some View {
        HStack(spacing: 4) {
            ForEach(Self.wochentagsKuerzel, id: \.self) { kuerzel in
                Text(kuerzel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func tagKnopf(_ zelle: MonatsRaster.Zelle, heute: Bool) -> some View {
        Button {
            Haptik.auswahl()
            onTagWaehlen(zelle.tag)
        } label: {
            MonatsZelle(zelle: zelle, heute: heute)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(zelle.vorlesen(heute: heute))
    }

    private func wechsleMonat(_ delta: Int) {
        Haptik.auswahl()
        let anfang = Datum.datum(erster)
        erster = Datum.text(Datum.kalender.date(byAdding: .month, value: delta, to: anfang) ?? anfang)
    }
}

/// Z-42.1: eine Tageszelle aus fertigen Werten, ohne Modellzugriff.
struct MonatsZelle: View {
    let zelle: MonatsRaster.Zelle
    let heute: Bool
    @Environment(\.colorSchemeContrast) private var kontrast

    static let hoehe: CGFloat = 52

    var body: some View {
        VStack(spacing: 2) {
            Text(zelle.nummer)
                .font(.subheadline.weight(heute ? .bold : .medium))
                .monospacedDigit()
            HStack(spacing: 0) {
                symbol(zelle.ahmed)
                symbol(zelle.annika)
            }
            HStack(spacing: 3) {
                if zelle.termin { Circle().fill(.primary).frame(width: 5, height: 5) }
                if zelle.treffen { herz }
            }
            .frame(height: 11)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: Self.hoehe)
        .background { haelften }
        .clipShape(.rect(cornerRadius: 9))
        .overlay { rahmen }
        .contentShape(.rect(cornerRadius: 9))
    }

    /// Links Ahmed, rechts Annika, jeweils in der eigenen Personenfarbe.
    private var haelften: some View {
        HStack(spacing: 0) {
            Color.person(.ahmed).opacity(deckkraft(zelle.ahmed))
            Color.person(.annika).opacity(deckkraft(zelle.annika))
        }
    }

    /// Schule kräftig, Arbeit hell; mit „Kontrast erhöhen" beides stärker.
    private func deckkraft(_ typ: String?) -> Double {
        let mehr = kontrast == .increased
        switch typ {
        case "schule"?: return mehr ? 0.5 : 0.34
        case "arbeit"?: return mehr ? 0.24 : 0.14
        default: return 0
        }
    }

    /// Buch oder Koffer, damit Schule und Arbeit nicht nur an der Tönung hängen.
    private func symbol(_ typ: String?) -> some View {
        Image(systemName: typ == "schule" ? "book.closed.fill" : "briefcase.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.primary)
            .opacity(typ == nil ? 0 : 0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 11)
    }

    /// Auf einer kleinen Scheibe, damit das Herz auch auf der rosé getönten Hälfte lesbar bleibt.
    private var herz: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(Color.loveaRose)
            .padding(2)
            .background(Color(uiColor: .systemBackground), in: .circle)
    }

    private var rahmen: some View {
        RoundedRectangle(cornerRadius: 9)
            .strokeBorder(
                heute ? Color.primary : Color(uiColor: .separator),
                lineWidth: heute ? 2 : (kontrast == .increased ? 1.5 : 1)
            )
    }
}

/// Z-42.1: Legende unter dem Monatsraster. Keine Markierung hängt nur an der Farbe (Seite, Buch,
/// Koffer, Punkt, Herz); VoiceOver liest alles als einen Satz.
struct MonatsLegende: View {
    // Adaptives Raster: bei großer Schrift (hier nicht gedeckelt) brechen die Einträge um.
    private static let spalten = [GridItem(.adaptive(minimum: 96), spacing: 10, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: Self.spalten, alignment: .leading, spacing: 6) {
            eintrag("Ahmed") { haelfte(.ahmed, links: true) }
            eintrag("Annika") { haelfte(.annika, links: false) }
            eintrag("Schule") { Image(systemName: "book.closed.fill") }
            eintrag("Arbeit") { Image(systemName: "briefcase.fill") }
            eintrag("Termin") { Circle().fill(.primary).frame(width: 5, height: 5) }
            eintrag("Treffen") { Image(systemName: "heart.fill").foregroundStyle(Color.loveaRose) }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legende: links Ahmed, rechts Annika. Kräftig getönt mit Buch: Schule. Hell getönt mit Koffer: Arbeit. Punkt: Termin. Herz: Treffen.")
    }

    private func eintrag<Zeichen: View>(_ titel: String, @ViewBuilder zeichen: () -> Zeichen) -> some View {
        HStack(spacing: 5) {
            zeichen().frame(width: 16)
            Text(titel)
        }
    }

    /// Eine Mini-Zelle mit der getönten Hälfte: zeigt Farbe und Seite der Person.
    private func haelfte(_ person: Person, links: Bool) -> some View {
        HStack(spacing: 0) {
            Color.person(person).opacity(links ? 0.34 : 0)
            Color.person(person).opacity(links ? 0 : 0.34)
        }
        .frame(width: 14, height: 11)
        .clipShape(.rect(cornerRadius: 3))
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Color(uiColor: .separator), lineWidth: 1) }
    }
}
