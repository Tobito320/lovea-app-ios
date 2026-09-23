import SwiftUI

/// Z-9.5: Tagesansicht mit zwei Spalten Ahmed | Annika, gemeinsame freie Zeit (8–22 Uhr)
/// hervorgehoben. Termin anlegen und Ausnahme setzen als Blätter, Treffen öffnet `TreffenTagView`.
struct TagesAnsicht: View {
    let tag: String
    let kalender = KalenderModell.shared

    @State private var zeigtTerminEditor = false
    @State private var zeigtAusnahmeEditor = false

    private static let titelFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Datum.kalender
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.titelFormat.string(from: Datum.datum(tag)))
                    .font(.title3.weight(.semibold))

                if let treffen = kalender.zustand.daten.treffen.first(where: { $0.datum == tag }) {
                    NavigationLink(value: TreffenZiel(datum: treffen.datum)) {
                        Label(treffen.wasMachenWir ?? "Treffen", systemImage: "heart.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.loveaRose)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(Color.loveaRose.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                let freieFenster = freieZeiten(ahmedBloecke, annikaBloecke)
                if !freieFenster.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Gemeinsam frei", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack {
                            ForEach(freieFenster) { fenster in
                                Text("\(fenster.von)–\(fenster.bis)")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    spalte(person: .ahmed, bloecke: ahmedBloecke)
                    spalte(person: .annika, bloecke: annikaBloecke)
                }

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
        .navigationTitle(tag)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TreffenZiel.self) { ziel in
            TreffenTagView(datum: ziel.datum)
        }
        .sheet(isPresented: $zeigtTerminEditor) { TerminEditor(datum: tag) }
        .sheet(isPresented: $zeigtAusnahmeEditor) { AusnahmeEditor(datum: tag) }
    }

    private var ahmedBloecke: [Block] { Wochenplan.tag(tag, person: "ahmed", daten: kalender.zustand.daten) }
    private var annikaBloecke: [Block] { Wochenplan.tag(tag, person: "annika", daten: kalender.zustand.daten) }

    private func spalte(person: Person, bloecke: [Block]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(person.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.person(person))
            if bloecke.isEmpty {
                Text("Frei")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(bloecke.enumerated()), id: \.offset) { _, block in
                    blockZeile(block)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func blockZeile(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.titel)
                .font(.caption.weight(.medium))
            Text(zeitText(block))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusFarbe(block.status).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
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

    private func statusFarbe(_ status: String) -> Color {
        switch status {
        case "krank": .orange
        case "urlaub": .blue
        case "frei": .green
        case "verschoben": .purple
        default: .gray
        }
    }

    /// Gemeinsame freie Fenster innerhalb 8–22 Uhr: das Fenster minus alle belegten Blöcke
    /// beider Personen (ganztägige oder zeitlose Blöcke ohne Status „frei"/„urlaub" blockieren
    /// das ganze Fenster).
    private func freieZeiten(_ ahmed: [Block], _ annika: [Block]) -> [FreiesFenster] {
        let fensterStart = 8 * 60, fensterEnde = 22 * 60
        var frei: [(von: Int, bis: Int)] = [(fensterStart, fensterEnde)]
        for block in ahmed + annika {
            guard block.status != "frei", block.status != "urlaub" else { continue }
            let start = minuten(block.start).map { max($0, fensterStart) } ?? fensterStart
            let ende = minuten(block.ende).map { min($0, fensterEnde) } ?? fensterEnde
            guard start < ende else { continue }
            frei = frei.flatMap { stueck -> [(von: Int, bis: Int)] in
                guard start < stueck.bis, ende > stueck.von else { return [stueck] }
                var teile: [(von: Int, bis: Int)] = []
                if stueck.von < start { teile.append((stueck.von, start)) }
                if ende < stueck.bis { teile.append((ende, stueck.bis)) }
                return teile
            }
        }
        return frei.filter { $0.bis - $0.von >= 30 }.map { FreiesFenster(von: uhrzeitText($0.von), bis: uhrzeitText($0.bis)) }
    }

    private func minuten(_ hhmm: String?) -> Int? {
        guard let hhmm, let doppelpunkt = hhmm.firstIndex(of: ":"),
              let stunde = Int(hhmm[..<doppelpunkt]), let minute = Int(hhmm[hhmm.index(after: doppelpunkt)...])
        else { return nil }
        return stunde * 60 + minute
    }

    private func uhrzeitText(_ minuten: Int) -> String { String(format: "%02d:%02d", minuten / 60, minuten % 60) }
}

/// Navigationsziel für „Treffen ansehen" aus der Tagesansicht.
struct TreffenZiel: Hashable { let datum: String }

private struct FreiesFenster: Identifiable { let von: String; let bis: String; var id: String { von + bis } }
