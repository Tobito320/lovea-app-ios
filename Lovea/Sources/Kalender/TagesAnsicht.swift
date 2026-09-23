import SwiftUI

/// Z-9.5: Tagesansicht als Zeitachse 8–22 Uhr mit zwei Spalten Ahmed | Annika. Blöcke stehen nach
/// Uhrzeit, ganztägige (und solche außerhalb 8–22) oben, gemeinsame freie Zeit ist als grünes Band
/// hinterlegt. Ein Termin öffnet per Antippen „Zum iPhone-Kalender" (Z-9.6).
struct TagesAnsicht: View {
    let tag: String
    let kalender = KalenderModell.shared

    @State private var zeigtTerminEditor = false
    @State private var zeigtAusnahmeEditor = false
    @State private var export: TerminExport?
    /// Höhe einer Stunde; wächst mit der Schriftgröße, damit die Blocktexte Platz behalten.
    @ScaledMetric(relativeTo: .caption) private var stunde: CGFloat = 48
    @ScaledMetric(relativeTo: .caption2) private var randBreite: CGFloat = 28

    private static let fensterVon = 8 * 60
    private static let fensterBis = 22 * 60

    var body: some View {
        let daten = kalender.zustand.daten
        let ahmed = Wochenplan.tag(tag, person: Person.ahmed.rawValue, daten: daten)
        let annika = Wochenplan.tag(tag, person: Person.annika.rawValue, daten: daten)
        let frei = Self.freieZeiten(ahmed + annika)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let treffen = daten.treffen.first(where: { $0.datum == tag }) {
                    NavigationLink(value: TreffenZiel(datum: treffen.datum)) {
                        Label(treffen.wasMachenWir ?? "Treffen", systemImage: "heart.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.loveaRose)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(Color.loveaRose.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Label(freiText(frei), systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                kopfzeile

                let obenAhmed = ahmed.filter { lage($0) == nil }
                let obenAnnika = annika.filter { lage($0) == nil }
                if !obenAhmed.isEmpty || !obenAnnika.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Text("Tag")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: randBreite, alignment: .trailing)
                            .accessibilityHidden(true)
                        obenListe(.ahmed, obenAhmed)
                        obenListe(.annika, obenAnnika)
                    }
                }

                zeitachse(ahmed: ahmed, annika: annika, frei: frei)

                HStack(spacing: 10) {
                    Button("Termin anlegen") { zeigtTerminEditor = true }
                        .buttonStyle(.bordered)
                    Button("Ausnahme setzen") { zeigtAusnahmeEditor = true }
                        .buttonStyle(.bordered)
                }
                .frame(minHeight: 44)
            }
            .padding()
        }
        .navigationTitle(Datum.anzeige(tag))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TreffenZiel.self) { ziel in
            TreffenTagView(datum: ziel.datum)
        }
        .sheet(isPresented: $zeigtTerminEditor) { TerminEditor(datum: tag) }
        .sheet(isPresented: $zeigtAusnahmeEditor) { AusnahmeEditor(datum: tag) }
        .sheet(item: $export) { e in
            IPhoneKalenderExportBlatt(titel: e.titel, start: e.start, ende: e.ende, ganztaegig: e.ganztaegig)
        }
    }

    // MARK: - Aufbau

    private var kopfzeile: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: randBreite, height: 1)
            ForEach(Person.allCases, id: \.self) { person in
                Text(person.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.person(person))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityHidden(true)
    }

    private func obenListe(_ person: Person, _ bloecke: [Block]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(bloecke.enumerated()), id: \.offset) { _, block in
                blockKarte(block, person: person, hoehe: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func zeitachse(ahmed: [Block], annika: [Block], frei: [FreiesFenster]) -> some View {
        let hoehe = y(Self.fensterBis)
        let stunden = Array(8...22)
        return HStack(alignment: .top, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ForEach(stunden, id: \.self) { h in
                    Text("\(h)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .offset(y: y(h * 60) - 7)
                }
            }
            .frame(width: randBreite, height: hoehe, alignment: .topTrailing)
            .accessibilityHidden(true)

            ZStack(alignment: .top) {
                ForEach(stunden, id: \.self) { h in
                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(height: 0.5)
                        .offset(y: y(h * 60))
                        .accessibilityHidden(true)
                }
                ForEach(frei) { fenster in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.15))
                        .frame(height: y(fenster.bis) - y(fenster.von))
                        .offset(y: y(fenster.von))
                        .accessibilityHidden(true)
                }
                HStack(alignment: .top, spacing: 6) {
                    spalte(.ahmed, ahmed, hoehe: hoehe)
                    spalte(.annika, annika, hoehe: hoehe)
                }
            }
            .frame(height: hoehe, alignment: .top)
        }
    }

    // ponytail: overlapping blocks of one person lie on top of each other (rare with school/work
    // patterns plus a few Termine); side-by-side lanes if that turns out to hide things.
    private func spalte(_ person: Person, _ bloecke: [Block], hoehe: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Color.clear
            ForEach(Array(bloecke.enumerated()), id: \.offset) { _, block in
                if let pos = lage(block) {
                    blockKarte(block, person: person, hoehe: max(y(pos.bis) - y(pos.von), 24))
                        .offset(y: y(pos.von))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hoehe)
    }

    @ViewBuilder
    private func blockKarte(_ block: Block, person: Person, hoehe: CGFloat?) -> some View {
        let ton = farbe(block, person: person)
        let karte = VStack(alignment: .leading, spacing: 1) {
            Text(block.titel)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Text(zeitText(block))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: hoehe, maxHeight: hoehe, alignment: .topLeading)
        .background(ton.opacity(0.18))
        .overlay(alignment: .leading) { Rectangle().fill(ton).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name): \(block.titel), \(zeitText(block))")

        if let id = block.terminId, let termin = kalender.zustand.daten.termine.first(where: { $0.id == id }) {
            Menu {
                Button("Zum iPhone-Kalender", systemImage: "calendar.badge.plus") { export = TerminExport(termin) }
            } label: {
                karte
            }
            .buttonStyle(.plain)
            .accessibilityHint("Zum iPhone-Kalender hinzufügen")
        } else {
            karte
        }
    }

    // MARK: - Werte

    private func y(_ minuten: Int) -> CGFloat {
        CGFloat(minuten - Self.fensterVon) / 60 * stunde
    }

    /// Lage auf der Achse in Minuten, auf 8–22 Uhr beschnitten. Nil = ganztägig oder ganz außerhalb.
    /// Ohne Ende gilt eine Stunde.
    private func lage(_ block: Block) -> (von: Int, bis: Int)? {
        guard let start = Self.minuten(block.start) else { return nil }
        let ende = Self.minuten(block.ende) ?? start + 60
        let von = max(start, Self.fensterVon)
        let bis = min(ende, Self.fensterBis)
        return von < bis ? (von, bis) : nil
    }

    private func freiText(_ frei: [FreiesFenster]) -> String {
        guard !frei.isEmpty else { return "Keine gemeinsame freie Zeit zwischen 8 und 22 Uhr" }
        return "Gemeinsam frei: " + frei.map { "\(Self.uhrzeitText($0.von))–\(Self.uhrzeitText($0.bis))" }.joined(separator: ", ")
    }

    private func zeitText(_ block: Block) -> String {
        var text: String
        if let start = block.start, let ende = block.ende { text = "\(start)–\(ende)" }
        else if let start = block.start { text = "ab \(start)" }
        else { text = "ganztägig" }
        if block.status != "normal" { text += " · \(statusText(block.status))" }
        return text
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "krank": "krank"
        case "urlaub": "Urlaub"
        case "frei": "frei"
        case "verschoben": "verschoben"
        default: status
        }
    }

    /// Personenfarbe (Spec 3), Treffen in Rosé; Ausnahmen in ihrer Statusfarbe, der Status steht
    /// zusätzlich als Text im Block.
    private func farbe(_ block: Block, person: Person) -> Color {
        switch block.status {
        case "krank": return .orange
        case "urlaub": return .blue
        case "frei": return .green
        case "verschoben": return .purple
        default: return block.typ == "treffen" ? Color.loveaRose : Color.person(person)
        }
    }

    /// Gemeinsame freie Fenster innerhalb 8–22 Uhr: das Fenster minus alle belegten Blöcke
    /// beider Personen (ganztägige oder zeitlose Blöcke ohne Status „frei"/„urlaub" blockieren
    /// das ganze Fenster).
    private static func freieZeiten(_ bloecke: [Block]) -> [FreiesFenster] {
        var frei: [(von: Int, bis: Int)] = [(fensterVon, fensterBis)]
        for block in bloecke {
            guard block.status != "frei", block.status != "urlaub" else { continue }
            let start = minuten(block.start).map { max($0, fensterVon) } ?? fensterVon
            let ende = minuten(block.ende).map { min($0, fensterBis) } ?? fensterBis
            guard start < ende else { continue }
            frei = frei.flatMap { stueck -> [(von: Int, bis: Int)] in
                guard start < stueck.bis, ende > stueck.von else { return [stueck] }
                var teile: [(von: Int, bis: Int)] = []
                if stueck.von < start { teile.append((stueck.von, start)) }
                if ende < stueck.bis { teile.append((ende, stueck.bis)) }
                return teile
            }
        }
        return frei.filter { $0.bis - $0.von >= 30 }.map { FreiesFenster(von: $0.von, bis: $0.bis) }
    }

    private static func minuten(_ hhmm: String?) -> Int? {
        guard let hhmm, let doppelpunkt = hhmm.firstIndex(of: ":"),
              let stunde = Int(hhmm[..<doppelpunkt]), let minute = Int(hhmm[hhmm.index(after: doppelpunkt)...])
        else { return nil }
        return stunde * 60 + minute
    }

    private static func uhrzeitText(_ minuten: Int) -> String { String(format: "%02d:%02d", minuten / 60, minuten % 60) }
}

/// Navigationsziel für „Treffen ansehen" aus der Tagesansicht.
struct TreffenZiel: Hashable { let datum: String }

private struct FreiesFenster: Identifiable { let von: Int; let bis: Int; var id: Int { von } }

/// Z-9.6: ein Lovea-Termin als Vorlage für den System-Dialog „Zum iPhone-Kalender".
private struct TerminExport: Identifiable {
    let id: String
    let titel: String
    let start: Date
    let ende: Date
    let ganztaegig: Bool

    init(_ termin: Termin) {
        id = termin.id
        titel = termin.titel
        ganztaegig = termin.start == nil
        let start = IPhoneKalenderDatum.kombiniert(termin.datum, termin.start)
        let ende = termin.ende.map { IPhoneKalenderDatum.kombiniert(termin.datum, $0) } ?? start
        self.start = start
        self.ende = ende > start ? ende : start.addingTimeInterval(60 * 60)
    }
}
