import SwiftUI

/// Nur eine neue Datei — fasst `Muster` (aus `Kalender/Logik/KalenderDaten.swift`) rückwirkend
/// als `Identifiable` auf, ohne die Logik-Datei selbst anzufassen.
extension Muster: Identifiable {}

/// Einstellungen → Wochenplan (Z-9.4 letzter Satz): eigene Muster bearbeiten, Zeiten und Tage
/// einstellen. Block 15 verlinkt diese Ansicht aus den Einstellungen.
struct WochenplanEditor: View {
    let kalender = KalenderModell.shared
    @State private var bearbeitetesMuster: Muster?
    @State private var zeigtNeu = false

    private var eigenePerson: Person { Raum.shared.ich ?? .ahmed }
    private var eigeneMuster: [Muster] { kalender.zustand.daten.muster.filter { $0.person == eigenePerson.rawValue } }

    var body: some View {
        List {
            ForEach(eigeneMuster) { muster in
                Button { bearbeitetesMuster = muster } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(muster.titel.isEmpty ? muster.typ.capitalized : muster.titel)
                            .font(.body.weight(.medium))
                        Text(zusammenfassung(muster))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
            }
            .onDelete { indexSet in
                for i in indexSet { Raum.shared.senden("muster.loeschen", ["id": eigeneMuster[i].id]) }
            }
        }
        .navigationTitle("Wochenplan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Neu") { zeigtNeu = true } }
        }
        .sheet(item: $bearbeitetesMuster) { muster in MusterEditorBlatt(muster: muster) }
        .sheet(isPresented: $zeigtNeu) {
            MusterEditorBlatt(muster: Muster(id: UUID().uuidString, person: eigenePerson.rawValue, typ: "arbeit", titel: "", wochentage: [1, 2, 3, 4, 5], wochen: "alle", start: nil, ende: nil, ab: Datum.text(Date())))
        }
    }

    private func zusammenfassung(_ muster: Muster) -> String {
        let tage = muster.wochentage.sorted().map { Self.wochentagsKuerzel[$0 - 1] }.joined(separator: ", ")
        let woche = muster.wochen == "alle" ? "" : " · Woche \(muster.wochen)"
        let zeit = (muster.start != nil && muster.ende != nil) ? " · \(muster.start!)–\(muster.ende!)" : ""
        return tage + woche + zeit
    }

    private static let wochentagsKuerzel = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
}

private struct MusterEditorBlatt: View {
    @Environment(\.dismiss) private var dismiss
    @State private var muster: Muster
    @State private var hatZeit: Bool
    @State private var start: Date
    @State private var ende: Date

    private static let typen = ["schule", "arbeit", "fahrschule", "sonstiges"]
    private static let wochentagsNamen = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private static let wochentagsVoll = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

    init(muster: Muster) {
        _muster = State(initialValue: muster)
        _hatZeit = State(initialValue: muster.start != nil && muster.ende != nil)
        // An einem echten Tag verankert (nicht Jahr 1 aus reinen Stunden/Minuten), Standard 8–16 Uhr.
        let heute = Datum.text(Date())
        _start = State(initialValue: IPhoneKalenderDatum.kombiniert(heute, muster.start ?? "08:00"))
        _ende = State(initialValue: IPhoneKalenderDatum.kombiniert(heute, muster.ende ?? "16:00"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Was") {
                    TextField("Titel", text: $muster.titel, prompt: Text(muster.typ.capitalized))
                    Picker("Art", selection: $muster.typ) {
                        ForEach(Self.typen, id: \.self) { Text($0.capitalized) }
                    }
                }
                Section("Wann") {
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { tag in wochentagKnopf(tag) }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    Picker("Wechselwoche", selection: $muster.wochen) {
                        Text("Alle").tag("alle")
                        Text("Woche A").tag("A")
                        Text("Woche B").tag("B")
                    }
                    DatePicker("Ab", selection: Binding(get: { Datum.datum(muster.ab) }, set: { muster.ab = Datum.text($0) }), displayedComponents: .date)
                        .environment(\.timeZone, Datum.kalender.timeZone)
                }
                Section("Uhrzeit") {
                    Toggle("Mit Uhrzeit", isOn: $hatZeit)
                    if hatZeit {
                        DatePicker("Von", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("Bis", selection: $ende, in: start..., displayedComponents: .hourAndMinute)
                    }
                }
                .environment(\.timeZone, Datum.kalender.timeZone)
            }
            .navigationTitle("Muster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: sichern)
                        .disabled(muster.wochentage.isEmpty)
                }
            }
        }
    }

    /// Z-42.2: jeder Tag ein eigener Knopf. `.borderless`, sonst lösen in einer Form-Zeile alle
    /// sieben zusammen aus.
    private func wochentagKnopf(_ tag: Int) -> some View {
        let an = muster.wochentage.contains(tag)
        return Button {
            if an { muster.wochentage.removeAll { $0 == tag } } else { muster.wochentage.append(tag) }
            Haptik.auswahl()
        } label: {
            Text(Self.wochentagsNamen[tag - 1])
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(an ? Color.white : Color.primary)
                .background(an ? Color.loveaRose : Color(uiColor: .tertiarySystemFill), in: .circle)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Self.wochentagsVoll[tag - 1])
        .accessibilityAddTraits(an ? .isSelected : [])
    }

    private func sichern() {
        var gesendet = muster
        // Ohne Titel gilt die Art („Arbeit"), statt „Sichern" stumm zu sperren.
        if gesendet.titel.trimmingCharacters(in: .whitespaces).isEmpty { gesendet.titel = gesendet.typ.capitalized }
        gesendet.wochentage.sort()
        gesendet.start = hatZeit ? Datum.uhrzeit(start) : nil
        gesendet.ende = hatZeit ? Datum.uhrzeit(ende) : nil
        Raum.shared.senden("muster.setzen", gesendet)
        Haptik.erfolg()
        dismiss()
    }
}
