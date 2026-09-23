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
    @State var muster: Muster
    @State private var hatZeit: Bool
    @State private var start: Date
    @State private var ende: Date

    private static let typen = ["schule", "arbeit", "fahrschule", "sonstiges"]
    private static let wochentagsNamen = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    init(muster: Muster) {
        _muster = State(initialValue: muster)
        _hatZeit = State(initialValue: muster.start != nil && muster.ende != nil)
        _start = State(initialValue: Self.zeit(muster.start) ?? Date())
        _ende = State(initialValue: Self.zeit(muster.ende) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Was") {
                    TextField("Titel", text: $muster.titel)
                    Picker("Art", selection: $muster.typ) {
                        ForEach(Self.typen, id: \.self) { Text($0.capitalized) }
                    }
                }
                Section("Wann") {
                    HStack {
                        ForEach(1...7, id: \.self) { tag in
                            let an = muster.wochentage.contains(tag)
                            Button(Self.wochentagsNamen[tag - 1]) {
                                if an { muster.wochentage.removeAll { $0 == tag } } else { muster.wochentage.append(tag) }
                            }
                            .buttonStyle(.bordered)
                            .tint(an ? Color.loveaRose : .gray)
                        }
                    }
                    Picker("Wechselwoche", selection: $muster.wochen) {
                        Text("Alle").tag("alle")
                        Text("Woche A").tag("A")
                        Text("Woche B").tag("B")
                    }
                    DatePicker("Ab", selection: Binding(get: { Datum.datum(muster.ab) }, set: { muster.ab = Datum.text($0) }), displayedComponents: .date)
                }
                Section("Uhrzeit") {
                    Toggle("Mit Uhrzeit", isOn: $hatZeit)
                    if hatZeit {
                        DatePicker("Von", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("Bis", selection: $ende, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Muster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(muster.titel.trimmingCharacters(in: .whitespaces).isEmpty || muster.wochentage.isEmpty)
                }
            }
        }
    }

    private func sichern() {
        var gesendet = muster
        gesendet.start = hatZeit ? Self.text(start) : nil
        gesendet.ende = hatZeit ? Self.text(ende) : nil
        Raum.shared.senden("muster.setzen", gesendet)
        dismiss()
    }

    private static func zeit(_ hhmm: String?) -> Date? {
        guard let hhmm, let doppelpunkt = hhmm.firstIndex(of: ":"),
              let stunde = Int(hhmm[..<doppelpunkt]), let minute = Int(hhmm[hhmm.index(after: doppelpunkt)...])
        else { return nil }
        var komponenten = DateComponents()
        komponenten.hour = stunde
        komponenten.minute = minute
        return Datum.kalender.date(from: komponenten)
    }

    private static func text(_ datum: Date) -> String {
        let komponenten = Datum.kalender.dateComponents([.hour, .minute], from: datum)
        return String(format: "%02d:%02d", komponenten.hour ?? 0, komponenten.minute ?? 0)
    }
}
