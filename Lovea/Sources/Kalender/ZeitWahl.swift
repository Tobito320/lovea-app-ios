import SwiftUI

/// Z-42.2 Nachtrag (Ahmed: Uhrzeit eingeben ist zu mühsam): Schnellwahl statt Rad. Beginn-Chips
/// 08–20 Uhr alle zwei Stunden, „Andere …" öffnet einen kompakten Picker, Dauer-Chips setzen das
/// Ende. `start == nil` heißt ohne Uhrzeit (Chip `ohneZeit`, etwa „Ganztägig"). Ohne `ende`
/// (Treffen) gibt es nur den Beginn. Die Chips sind `.borderless`, sonst lösen in einer Form-Zeile
/// alle Knöpfe zusammen aus.
struct ZeitWahl: View {
    let datum: String
    @Binding var start: String?
    var ende: Binding<String?>? = nil
    let ohneZeit: String

    @State private var zeigtAndere = false

    private static let zeiten = ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"]
    private static let dauern = [30, 60, 120, 180]
    private static let standardBeginn = "10:00"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ueberschrift(ende == nil ? "Uhrzeit" : "Beginn")
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    ForEach(Self.zeiten.prefix(4), id: \.self) { zeitChip($0) }
                }
                GridRow {
                    ForEach(Self.zeiten.suffix(3), id: \.self) { zeitChip($0) }
                    andereChip
                }
                if ende == nil {
                    GridRow { ohneChip.gridCellColumns(4) }
                }
            }
            if let ende {
                ueberschrift("Dauer")
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        ForEach(Self.dauern, id: \.self) { dauerChip($0, ende: ende) }
                    }
                    GridRow { ohneChip.gridCellColumns(4) }
                }
                if let start {
                    Text(ende.wrappedValue.map { "\(start) bis \($0)" } ?? "ab \(start)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func ueberschrift(_ titel: String) -> some View {
        Text(titel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func zeitChip(_ zeit: String) -> some View {
        chip(zeit, an: start == zeit) { waehleBeginn(zeit) }
    }

    private var andereChip: some View {
        let eigene = start.flatMap { Self.zeiten.contains($0) ? nil : $0 }
        return chip(eigene ?? "Andere …", an: eigene != nil, vorlesen: eigene.map { "Andere Uhrzeit, \($0)" } ?? "Andere Uhrzeit") {
            zeigtAndere = true
        }
        .popover(isPresented: $zeigtAndere) {
            DatePicker("Uhrzeit", selection: andereZeit, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.timeZone, Datum.kalender.timeZone)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var ohneChip: some View {
        chip(ohneZeit, an: start == nil) {
            start = nil
            if let ende { ende.wrappedValue = nil }
        }
    }

    private func dauerChip(_ minuten: Int, ende: Binding<String?>) -> some View {
        let titel = minuten < 60 ? "\(minuten) min" : "\(minuten / 60) h"
        let vorlesen = minuten < 60 ? "\(minuten) Minuten" : (minuten == 60 ? "1 Stunde" : "\(minuten / 60) Stunden")
        return chip(titel, an: Self.dauer(start, ende.wrappedValue) == minuten, vorlesen: vorlesen) {
            let beginn = start ?? Self.standardBeginn
            start = beginn
            ende.wrappedValue = Datum.uhrzeit(beginn, plus: minuten)
        }
    }

    private func chip(_ titel: String, an: Bool, vorlesen: String? = nil, aktion: @escaping () -> Void) -> some View {
        Button {
            aktion()
            Haptik.auswahl()
        } label: {
            Text(titel)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(an ? Color.white : Color.primary)
                .background(an ? Color.loveaRose : Color(uiColor: .tertiarySystemFill), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(vorlesen ?? titel)
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    /// Für „Andere …": der Picker arbeitet mit einem Datum am Tag `datum`.
    private var andereZeit: Binding<Date> {
        Binding(
            get: { IPhoneKalenderDatum.kombiniert(datum, start ?? Self.standardBeginn) },
            set: { waehleBeginn(Datum.uhrzeit($0)) }
        )
    }

    /// Neuer Beginn; das Ende rückt mit, die Dauer bleibt (sonst 1 h).
    private func waehleBeginn(_ zeit: String) {
        let dauer = Self.dauer(start, ende?.wrappedValue) ?? 60
        start = zeit
        if let ende { ende.wrappedValue = Datum.uhrzeit(zeit, plus: dauer) }
    }

    private static func dauer(_ start: String?, _ ende: String?) -> Int? {
        guard let von = Datum.minuten(start), let bis = Datum.minuten(ende), bis > von else { return nil }
        return bis - von
    }
}
