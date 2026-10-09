import Charts
import SwiftUI

// Health-Coach, Bausteine einer Antwort: Tabelle, Diagramm, Fortschritt, abhakbare Aufgabe, Folgefragen, Wege in die
// App, Erinnerung und Ziel. Alles hier zeichnet nur, was `CoachText` und `CoachMarker` schon geprüft haben.
// Akku: nichts davon hat einen Timer.

enum CoachAnzeige {
    private static let deutsch = Locale(identifier: "de_DE")

    private static var stil: Date.FormatStyle {
        let kalender = Datum.kalender
        return Date.FormatStyle(locale: deutsch, calendar: kalender, timeZone: kalender.timeZone)
    }

    /// "Heute", "Gestern" oder "Mo. 5. Okt.".
    static func tagText(_ zeit: Date) -> String {
        let kalender = Datum.kalender
        if kalender.isDateInToday(zeit) { return "Heute" }
        if kalender.isDateInYesterday(zeit) { return "Gestern" }
        return zeit.formatted(stil.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "Heute, 14:05" oder "Mo. 5. Okt., 14:05".
    static func zeitText(_ zeit: Date) -> String {
        tagText(zeit) + ", " + zeit.formatted(stil.hour().minute())
    }

    /// Zahl ohne unnötige Nachkommastellen, deutsch: 8200 -> "8.200", 82,4 -> "82,4".
    static func zahl(_ wert: Double) -> String {
        let begrenzt = min(max(wert, 0), 1_000_000_000)
        return begrenzt.formatted(.number.precision(.fractionLength(0...1)).locale(deutsch))
    }

    /// Der Text ohne Markdown-Zeichen, für VoiceOver.
    static func klartext(_ text: String) -> String {
        String(CoachText.inline(text).characters)
    }

    /// Antwort ohne Marker und ohne Fett-Sterne, zum Kopieren und Teilen.
    static func kopierText(_ roh: String) -> String {
        CoachMarker.zerlegen(roh).text.replacingOccurrences(of: "**", with: "")
    }

    /// Inline-Markdown; Zahlen mit Einheit ("8.200 Schritte", "85 %") fett und mit mintfarbenem Hintergrund.
    static func hervorgehoben(_ text: String) -> AttributedString {
        var ergebnis = CoachText.inline(text)
        let sichtbar = String(ergebnis.characters)
        for bereich in CoachText.zahlBereiche(sichtbar).reversed() {
            let anfang = ergebnis.characters.index(ergebnis.startIndex, offsetBy: bereich.lowerBound)
            let ende = ergebnis.characters.index(ergebnis.startIndex, offsetBy: bereich.upperBound)
            ergebnis[anfang..<ende].inlinePresentationIntent = .stronglyEmphasized
            ergebnis[anfang..<ende].backgroundColor = HabitFarbe.mint.farbe.opacity(0.18)
        }
        return ergebnis
    }
}

// MARK: - Tabelle

struct CoachTabelle: View {
    let kopf: [String]
    let zeilen: [[String]]

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    ForEach(Array(kopf.enumerated()), id: \.offset) { _, zelle in
                        Text(CoachText.inline(zelle)).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in
                    GridRow {
                        ForEach(Array(zeile.enumerated()), id: \.offset) { spalte, zelle in
                            Text(CoachText.inline(zelle))
                                .font(.subheadline.weight(spalte == 0 ? .medium : .regular))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(14)
        }
        .scrollIndicators(.hidden)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .healthKarte(HabitFarbe.himmel.farbe)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschreibung)
    }

    private var beschreibung: String {
        let reihen = zeilen.map { zeile in
            zip(kopf, zeile).map { "\($0): \(CoachAnzeige.klartext($1))" }.joined(separator: ", ")
        }
        return "Tabelle. " + reihen.joined(separator: ". ")
    }
}

// MARK: - Diagramm

struct CoachDiagramm: View {
    let titel: String
    let punkte: [CoachMarker.Punkt]

    private var hoechster: Double { max(punkte.map(\.wert).max() ?? 0, 1) }

    /// Gleiche Beschriftungen würden im Diagramm auf einen Balken fallen; ein unsichtbares Zeichen trennt sie.
    private var spalten: [String] {
        var gesehen: [String: Int] = [:]
        return punkte.map { punkt in
            let bisher = gesehen[punkt.label, default: 0]
            gesehen[punkt.label] = bisher + 1
            return punkt.label + String(repeating: "\u{200B}", count: bisher)
        }
    }

    private func beschriftung(_ wert: Double) -> String {
        wert >= 1000 ? HealthText.kurz(Int(min(wert, 1_000_000_000))) : CoachAnzeige.zahl(wert)
    }

    var body: some View {
        let namen = spalten
        VStack(alignment: .leading, spacing: 10) {
            Text(titel).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Chart {
                ForEach(Array(punkte.enumerated()), id: \.offset) { index, punkt in
                    BarMark(x: .value("Zeit", namen[index]), y: .value("Wert", punkt.wert))
                        .foregroundStyle(HabitFarbe.mint.farbe)
                        .cornerRadius(4)
                        .annotation(position: .top, spacing: 3) {
                            Text(beschriftung(punkt.wert)).font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        }
                }
            }
            .chartYScale(domain: 0...(hoechster * 1.25))
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 150)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.mint.farbe)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Diagramm \(titel). " + punkte.map { "\($0.label) \(CoachAnzeige.zahl($0.wert))" }.joined(separator: ", "))
    }
}

// MARK: - Fortschritt

struct CoachFortschritt: View {
    let label: String
    let aktuell: Double
    let ziel: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(CoachAnzeige.zahl(aktuell)) von \(CoachAnzeige.zahl(ziel))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: CoachLokal.anteil(aktuell: aktuell, ziel: ziel)).tint(HabitFarbe.mint.farbe)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.mint.farbe)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(CoachAnzeige.zahl(aktuell)) von \(CoachAnzeige.zahl(ziel))")
    }
}

// MARK: - Aufgabe zum Abhaken

struct CoachAufgabeZeile: View {
    let text: String
    let erledigt: Bool
    let umschalten: () -> Void

    var body: some View {
        Button(action: umschalten) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: erledigt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(erledigt ? HabitFarbe.mint.farbe : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text(CoachText.inline(text))
                    .strikethrough(erledigt)
                    .foregroundStyle(erledigt ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CoachAnzeige.klartext(text))
        .accessibilityValue(erledigt ? "Erledigt" : "Offen")
    }
}

// MARK: - Folgefragen und Wege

struct CoachFolgefragen: View {
    let fragen: [String]
    let waehlen: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(fragen.enumerated()), id: \.offset) { _, frage in
                Button { waehlen(frage) } label: {
                    HStack(spacing: 8) {
                        Text(frage).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .background(HabitFarbe.mint.farbe.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.federnd)
                .foregroundStyle(.primary)
            }
        }
    }
}

/// Link in einen Bereich der App. Der Stapel von Heute kennt `HealthZiel` (`navigationDestination`).
struct CoachWeg: View {
    let ziel: HealthZiel
    let beschriftung: String

    var body: some View {
        NavigationLink(value: ziel) {
            HStack(spacing: 6) {
                Text(beschriftung).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(HabitFarbe.himmel.farbe)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(HabitFarbe.himmel.farbe.opacity(0.16), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.federnd)
    }
}

// MARK: - Erinnerung und Ziel

struct CoachErinnerungsKnopf: View {
    let stunde: Int
    let minute: Int
    let text: String

    private enum Stand { case offen, gesetzt, verweigert }

    @State private var stand: Stand?

    private var kennung: String { CoachLokal.erinnerungsKennung(stunde: stunde, minute: minute, text: text) }
    private var uhr: String { String(format: "%02d:%02d", stunde, minute) }

    var body: some View {
        let aktuell = stand ?? (CoachModell.shared.erinnerungen.contains(kennung) ? .gesetzt : .offen)
        Button {
            guard aktuell != .gesetzt else { return }
            Task {
                let ok = await CoachModell.shared.erinnerungPlanen(stunde: stunde, minute: minute, text: text)
                stand = ok ? .gesetzt : .verweigert
                if ok { Haptik.erfolg() } else { Haptik.warnung() }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(aktuell == .gesetzt ? "Erinnerung gesetzt: täglich \(uhr)" : "Täglich um \(uhr) erinnern",
                      systemImage: aktuell == .gesetzt ? "bell.fill" : "bell")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Text(aktuell == .verweigert ? "Mitteilungen sind aus. Erlaube sie in den iPhone-Einstellungen." : text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(HabitFarbe.amber.farbe.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.federnd)
        .foregroundStyle(.primary)
    }
}

struct CoachZielKnopf: View {
    let text: String

    @State private var gemerkt: Bool?

    var body: some View {
        let aktuell = gemerkt ?? (CoachModell.shared.ziel == text)
        Button {
            guard !aktuell else { return }
            CoachModell.shared.zielSetzen(text)
            gemerkt = true
            Haptik.erfolg()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(aktuell ? "Als Ziel gemerkt" : "Als Ziel merken", systemImage: aktuell ? "flag.fill" : "flag")
                    .font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(HabitFarbe.indigo.farbe.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.federnd)
        .foregroundStyle(.primary)
    }
}

// MARK: - Aktionen unter der letzten Antwort

struct CoachAktionsLeiste: View {
    let hoch: Bool
    let runter: Bool
    let daumenHoch: () -> Void
    let daumenRunter: () -> Void
    let kopieren: () -> Void
    let kuerzer: () -> Void
    let genauer: () -> Void
    let nochmal: (() -> Void)?

    @State private var kopiert = false

    var body: some View {
        HStack(spacing: 0) {
            knopf(hoch ? "hand.thumbsup.fill" : "hand.thumbsup", "Hilfreich", daumenHoch)
            knopf(runter ? "hand.thumbsdown.fill" : "hand.thumbsdown", "Nicht hilfreich", daumenRunter)
            knopf(kopiert ? "checkmark" : "doc.on.doc", "Kopieren") {
                kopieren()
                kopiert = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    kopiert = false
                }
            }
            Menu {
                Button("Kürzer", systemImage: "arrow.down.right.and.arrow.up.left", action: kuerzer)
                Button("Genauer", systemImage: "arrow.up.left.and.arrow.down.right", action: genauer)
                if let nochmal { Button("Nochmal fragen", systemImage: "arrow.clockwise", action: nochmal) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Mehr")
            Spacer(minLength: 0)
        }
    }

    private func knopf(_ symbol: String, _ name: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}
