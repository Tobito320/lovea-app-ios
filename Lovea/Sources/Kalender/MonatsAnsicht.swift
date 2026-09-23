import SwiftUI
import UIKit

/// Z-9.5: Monatsraster mit farbigen Punkten pro Person und Herz für Treffen. Wischen wechselt
/// den Monat. Einen Tag antippen ruft `onTagWaehlen` mit dem `yyyy-MM-dd`-String auf.
struct MonatsAnsicht: View {
    let kalender = KalenderModell.shared
    var onTagWaehlen: (String) -> Void

    @State private var monat = Date()

    private static let wochentagsKuerzel = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    // Fresh formatter per call: DateFormatter is a class and not Sendable, so a shared `static
    // let` would trip Swift 6 strict concurrency (same reasoning as `Op.isoFormatierer`).
    private static func monatsTitel(_ datum: Date) -> String {
        let f = DateFormatter()
        f.calendar = Datum.kalender
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: datum)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { wechsleMonat(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Vorheriger Monat")
                Spacer()
                Text(Self.monatsTitel(monat))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { wechsleMonat(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Nächster Monat")
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)

            HStack(spacing: 0) {
                ForEach(Self.wochentagsKuerzel, id: \.self) { kuerzel in
                    Text(kuerzel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(Array(tage.enumerated()), id: \.offset) { _, tag in
                    if let tag {
                        tagZelle(tag)
                    } else {
                        Color.clear.frame(height: 40)
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

    private func wechsleMonat(_ delta: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        monat = Datum.kalender.date(byAdding: .month, value: delta, to: monat) ?? monat
    }

    /// 42 Zellen (6 Wochen), `nil` als Auffüller vor dem 1. und nach dem letzten Tag.
    private var tage: [String?] {
        var komponenten = Datum.kalender.dateComponents([.year, .month], from: monat)
        komponenten.day = 1
        guard let erster = Datum.kalender.date(from: komponenten) else { return [] }
        let ersterText = Datum.text(erster)
        let anzahlTage = Datum.kalender.range(of: .day, in: .month, for: erster)?.count ?? 30
        let vorlauf = Datum.wochentag(ersterText) - 1
        var ergebnis: [String?] = Array(repeating: nil, count: vorlauf)
        for tag in 1...anzahlTage { ergebnis.append(Datum.addTage(ersterText, tag - 1)) }
        while ergebnis.count < 42 { ergebnis.append(nil) }
        return ergebnis
    }

    private func tagZelle(_ tag: String) -> some View {
        let heute = tag == Datum.text(Date())
        let daten = kalender.zustand.daten
        let hatTreffen = daten.treffen.contains { $0.datum == tag }
        let hatTermin = daten.termine.contains { $0.datum == tag }
        // Left bar = Ahmed, right bar = Annika — a fixed position (not the person's own accent
        // color, which is already used for identity elsewhere) reads unambiguously even for two
        // people who share the same "A" initial, so a border-split cell or letter label isn't needed.
        let routineAhmed = routineTyp(tag, person: .ahmed)
        let routineAnnika = routineTyp(tag, person: .annika)

        var vorlesen = [Datum.anzeige(tag)]
        if heute { vorlesen.insert("Heute", at: 0) }
        if let routineAhmed { vorlesen.append("Ahmed: \(Self.typName(routineAhmed))") }
        if let routineAnnika { vorlesen.append("Annika: \(Self.typName(routineAnnika))") }
        if hatTermin { vorlesen.append("Termin") }
        if hatTreffen { vorlesen.append("Treffen") }

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            onTagWaehlen(tag)
        } label: {
            VStack(spacing: 3) {
                Text(tagesnummer(tag))
                    .font(.subheadline.weight(heute ? .bold : .regular))
                    .foregroundStyle(heute ? Color.loveaRose : .primary)
                HStack(spacing: 3) {
                    routinebalken(routineAhmed)
                    routinebalken(routineAnnika)
                }
                .frame(height: 3)
                HStack(spacing: 3) {
                    if hatTermin {
                        Circle().fill(Color.loveaRose).frame(width: 5, height: 5)
                    }
                    if hatTreffen {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Color.loveaRose)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(heute ? Color.loveaRose.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vorlesen.joined(separator: ", "))
    }

    private func routinebalken(_ typ: String?) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(typ.map(Self.farbeFuerTyp) ?? Color.clear)
            .frame(width: 14, height: 3)
    }

    /// Schule/Arbeit-Muster eines Tages, nur laufende (keine Ausnahme wie "frei"/"krank"). Ein
    /// Tag zeigt höchstens eine Farbe pro Person; Priorität Schule > Arbeit > Fahrschule > Sonstiges
    /// deckt den seltenen Fall mehrerer Muster am selben Tag ab.
    private func routineTyp(_ tag: String, person: Person) -> String? {
        let typen = Set(Wochenplan.tag(tag, person: person.rawValue, daten: kalender.zustand.daten)
            .filter { $0.quelle == "muster" && $0.status == "normal" }
            .map(\.typ))
        return Self.typPrioritaet.first { typen.contains($0) }
    }

    private static let typPrioritaet = ["schule", "arbeit", "fahrschule", "sonstiges"]

    static func farbeFuerTyp(_ typ: String) -> Color {
        switch typ {
        case "schule": return .blue
        case "arbeit": return .orange
        default: return .gray // fahrschule, sonstiges
        }
    }

    static func typName(_ typ: String) -> String {
        switch typ {
        case "schule": return "Schule"
        case "arbeit": return "Arbeit"
        case "fahrschule": return "Fahrschule"
        default: return "Sonstiges"
        }
    }

    private func tagesnummer(_ tag: String) -> String {
        String(Int(tag.suffix(2)) ?? 0)
    }
}

/// Kompakte Legende unter dem Monatsraster (Z-Feedback 23.09.2026): erklärt die Farben, da eine
/// Markierung nie allein über Farbe verständlich sein darf (VoiceOver liest den Typ ohnehin aus).
struct MonatsLegende: View {
    // Adaptives Raster statt HStack: bei großer Schrift (Accessibility-Größen, hier nicht
    // gedeckelt wie MonatsAnsicht) brechen die vier Einträge in mehrere Zeilen um, statt zu clippen.
    private static let spalten = [GridItem(.adaptive(minimum: 90), spacing: 10, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: Self.spalten, alignment: .leading, spacing: 6) {
            eintrag(Color.blue, "Schule")
            eintrag(Color.orange, "Arbeit")
            eintrag(Color.loveaRose, "Termin", istPunkt: true)
            eintrag(Color.loveaRose, "Treffen", istHerz: true)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func eintrag(_ farbe: Color, _ titel: String, istPunkt: Bool = false, istHerz: Bool = false) -> some View {
        HStack(spacing: 4) {
            if istHerz {
                Image(systemName: "heart.fill").font(.system(size: 8)).foregroundStyle(farbe)
            } else if istPunkt {
                Circle().fill(farbe).frame(width: 6, height: 6)
            } else {
                RoundedRectangle(cornerRadius: 1.5).fill(farbe).frame(width: 12, height: 3)
            }
            Text(titel)
        }
    }
}
