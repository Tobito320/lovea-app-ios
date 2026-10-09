import SwiftUI

/// Z-9.5 / Z-42.2: Tagesansicht als Zeitachse 8–22 Uhr mit zwei Spalten Ahmed | Annika. Blöcke stehen
/// nach Uhrzeit, ganztägige (und solche außerhalb 8–22) oben, gemeinsame freie Zeit ist grün
/// hinterlegt. Termin antippen: Bearbeiten, Zum iPhone-Kalender, Löschen. Block mit Ausnahme
/// antippen: ändern oder zurücknehmen. Anlegen über „+" in der Leiste.
struct TagesAnsicht: View {
    let tag: String
    let kalender = KalenderModell.shared

    @State private var blatt: Blatt?
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
                treffenZeile(daten.treffen.first { $0.datum == tag })
                Label(freiText(frei), systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                kopfzeile
                ganztags(ahmed: ahmed, annika: annika)
                zeitachse(ahmed: ahmed, annika: annika, frei: frei)
            }
            .padding()
        }
        .navigationTitle(Datum.anzeige(tag))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { hinzufuegen }
        }
        .navigationDestination(for: TreffenZiel.self) { ziel in
            TreffenTagView(datum: ziel.datum)
        }
        .sheet(item: $blatt) { blattInhalt($0) }
    }

    // MARK: - Aufbau

    /// Führt zum Treffen-Tag: ansehen, wenn es eins gibt, sonst planen.
    private func treffenZeile(_ treffen: Treffen?) -> some View {
        NavigationLink(value: TreffenZiel(datum: tag)) {
            HStack {
                Label(treffen.map { $0.wasMachenWir ?? "Treffen" } ?? "Treffen planen", systemImage: treffen == nil ? "heart" : "heart.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.loveaRose)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .background(Color.loveaRose.opacity(treffen == nil ? 0.06 : 0.12), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.federnd)
    }

    private var hinzufuegen: some View {
        Menu {
            Button("Termin anlegen", systemImage: "calendar.badge.plus") { blatt = .termin(nil) }
            Button("Ausnahme setzen", systemImage: "calendar.badge.exclamationmark") { blatt = .ausnahme(nil) }
            Button("Aus iPhone-Kalender holen", systemImage: "square.and.arrow.down") { blatt = .ausIPhone }
        } label: {
            Label("Hinzufügen", systemImage: "plus")
        }
    }

    @ViewBuilder
    private func blattInhalt(_ blatt: Blatt) -> some View {
        switch blatt {
        case .termin(let termin): TerminEditor(datum: tag, termin: termin)
        case .ausnahme(let ausnahme): AusnahmeEditor(datum: tag, ausnahme: ausnahme)
        case .arbeitszeit(let block): ArbeitszeitBlatt(datum: tag, block: block)
        case .zumIPhone(let termin): IPhoneKalenderExportBlatt(termin: termin)
        case .ausIPhone: IPhoneKalenderImport()
        }
    }

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

    @ViewBuilder
    private func ganztags(ahmed: [Block], annika: [Block]) -> some View {
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

    /// Termin: Menü mit Bearbeiten, Zum iPhone-Kalender, Löschen. Block mit Ausnahme: ändern oder
    /// zurücknehmen. Treffen: öffnet den Treffen-Tag.
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
                Button("Bearbeiten", systemImage: "pencil") { blatt = .termin(termin) }
                Button("Zum iPhone-Kalender", systemImage: "calendar.badge.plus") { blatt = .zumIPhone(termin) }
                Button("Löschen", systemImage: "trash", role: .destructive) { loeschen(termin) }
            } label: {
                karte
            }
            .buttonStyle(.plain)
            .accessibilityHint("Bearbeiten, zum iPhone-Kalender oder löschen")
        } else if block.typ == "arbeit", block.quelle == "muster", person == Raum.shared.ich {
            Button { blatt = .arbeitszeit(block) } label: { karte }
                .buttonStyle(.plain)
                .accessibilityHint("Arbeitszeit für diesen Tag ändern")
        } else if let ausnahme = block.ausnahme {
            Menu {
                Button("Ausnahme ändern", systemImage: "pencil") { blatt = .ausnahme(ausnahme) }
                Button("Ausnahme zurücknehmen", systemImage: "arrow.uturn.backward", role: .destructive) { zuruecknehmen(ausnahme) }
            } label: {
                karte
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ausnahme ändern oder zurücknehmen")
        } else if block.quelle == "treffen" {
            NavigationLink(value: TreffenZiel(datum: tag)) { karte }
                .buttonStyle(.plain)
        } else {
            karte
        }
    }

    // MARK: - Aktionen

    private func loeschen(_ termin: Termin) {
        Raum.shared.senden("termin.loeschen", ["id": termin.id])
        Haptik.leicht()
    }

    private func zuruecknehmen(_ ausnahme: Ausnahme) {
        Raum.shared.senden("ausnahme.loeschen", AusnahmeSchluessel(ausnahme))
        Haptik.leicht()
    }

    // MARK: - Werte

    private func y(_ minuten: Int) -> CGFloat {
        CGFloat(minuten - Self.fensterVon) / 60 * stunde
    }

    /// Lage auf der Achse in Minuten, auf 8–22 Uhr beschnitten. Nil = ganztägig oder ganz außerhalb.
    /// Ohne Ende gilt eine Stunde.
    private func lage(_ block: Block) -> (von: Int, bis: Int)? {
        guard let start = Datum.minuten(block.start) else { return nil }
        let ende = Datum.minuten(block.ende) ?? start + 60
        let von = max(start, Self.fensterVon)
        let bis = min(ende, Self.fensterBis)
        return von < bis ? (von, bis) : nil
    }

    private func freiText(_ frei: [FreiesFenster]) -> String {
        guard !frei.isEmpty else { return "Keine gemeinsame freie Zeit zwischen 8 und 22 Uhr" }
        return "Gemeinsam frei: " + frei.map { "\(Datum.uhrzeit(minuten: $0.von))–\(Datum.uhrzeit(minuten: $0.bis))" }.joined(separator: ", ")
    }

    private func zeitText(_ block: Block) -> String {
        var text: String
        if let start = block.start, let ende = block.ende { text = "\(start)–\(ende)" }
        else if let start = block.start { text = "ab \(start)" }
        else { text = "ganztägig" }
        if let netto = block.arbeitNetto { return text + " · \(netto / 60):\(String(format: "%02d", netto % 60)) h" }
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
        if block.arbeitNetto != nil, block.status == "verschoben" { return Color.person(person) }
        switch block.status {
        case "krank": return .orange
        case "urlaub": return .blue
        case "frei": return .green
        case "verschoben": return .purple
        default: return block.typ == "treffen" ? Color.loveaRose : Color.person(person)
        }
    }

    /// Gemeinsame freie Fenster innerhalb 8–22 Uhr: das Fenster minus alle belegten Blöcke
    /// beider Personen. Ganztägige oder zeitlose Blöcke blockieren das ganze Fenster; Urlaub und
    /// frei blockieren nicht, ein Treffen ist gemeinsame Zeit und blockiert auch nicht.
    private static func freieZeiten(_ bloecke: [Block]) -> [FreiesFenster] {
        var frei: [(von: Int, bis: Int)] = [(fensterVon, fensterBis)]
        for block in bloecke {
            guard block.status != "frei", block.status != "urlaub", block.quelle != "treffen" else { continue }
            let start = Datum.minuten(block.start).map { max($0, fensterVon) } ?? fensterVon
            let ende = Datum.minuten(block.ende).map { min($0, fensterBis) } ?? fensterBis
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
}

/// Navigationsziel für den Treffen-Tag aus der Tagesansicht.
struct TreffenZiel: Hashable { let datum: String }

private struct FreiesFenster: Identifiable { let von: Int; let bis: Int; var id: Int { von } }

/// Die Blätter der Tagesansicht, eins zur Zeit.
private enum Blatt: Identifiable {
    case termin(Termin?)
    case ausnahme(Ausnahme?)
    case zumIPhone(Termin)
    case ausIPhone
    case arbeitszeit(Block)

    var id: String {
        switch self {
        case .termin(let termin): "termin-\(termin?.id ?? "neu")"
        case .ausnahme(let ausnahme): "ausnahme-\(ausnahme?.id ?? "neu")"
        case .zumIPhone(let termin): "export-\(termin.id)"
        case .ausIPhone: "import"
        case .arbeitszeit(let block): "arbeit-\(block.musterId ?? "")"
        }
    }
}
