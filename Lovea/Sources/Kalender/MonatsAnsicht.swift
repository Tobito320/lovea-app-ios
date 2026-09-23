import SwiftUI

/// Z-9.5: Monatsraster mit farbigen Punkten pro Person und Herz für Treffen. Wischen wechselt
/// den Monat. Einen Tag antippen ruft `onTagWaehlen` mit dem `yyyy-MM-dd`-String auf.
struct MonatsAnsicht: View {
    let kalender = KalenderModell.shared
    var onTagWaehlen: (String) -> Void

    @State private var monat = Date()

    private static let wochentagsKuerzel = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private static let monatsFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Datum.kalender
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { wechsleMonat(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Vorheriger Monat")
                Spacer()
                Text(Self.monatsFormat.string(from: monat))
                    .font(.headline)
                Spacer()
                Button { wechsleMonat(1) } label: { Image(systemName: "chevron.right") }
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
        let hatTreffen = kalender.zustand.daten.treffen.contains { $0.datum == tag }
        return Button {
            onTagWaehlen(tag)
        } label: {
            VStack(spacing: 3) {
                Text(tagesnummer(tag))
                    .font(.subheadline.weight(heute ? .bold : .regular))
                    .foregroundStyle(heute ? Color.loveaRose : .primary)
                HStack(spacing: 3) {
                    ForEach(Person.allCases, id: \.self) { person in
                        if !Wochenplan.tag(tag, person: person.rawValue, daten: kalender.zustand.daten).isEmpty {
                            Circle().fill(Color.person(person)).frame(width: 5, height: 5)
                        }
                    }
                    if hatTreffen {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(Color.loveaRose)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(heute ? Color.loveaRose.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tag)
    }

    private func tagesnummer(_ tag: String) -> String {
        String(Int(tag.suffix(2)) ?? 0)
    }
}
