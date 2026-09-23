import EventKit
import EventKitUI
import SwiftUI

/// Z-9.6 „Zum iPhone-Kalender": `EKEventEditViewController` in SwiftUI, nur Schreibzugriff
/// (`requestWriteOnlyAccessToEvents`). Der Aufrufer baut das `EKEvent` und präsentiert dieses
/// Blatt; der System-Dialog übernimmt Sichern/Abbrechen.
struct IPhoneKalenderExport: UIViewControllerRepresentable {
    let event: EKEvent
    let store: EKEventStore
    var onFertig: () -> Void = {}

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFertig: onFertig) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFertig: () -> Void
        init(onFertig: @escaping () -> Void) { self.onFertig = onFertig }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            // Not passed as `dismiss`'s `completion:` on purpose: that parameter's type requires a
            // Sendable closure in the current SDK, and forwarding the stored `onFertig` there fails
            // ("sending value of non-Sendable type '() -> Void' risks causing data races"). Calling
            // it right after, instead of as the animation's completion, sidesteps that entirely —
            // the tiny timing difference doesn't matter since SwiftUI tears down the sheet itself.
            controller.dismiss(animated: true)
            onFertig()
        }
    }
}

/// Z-9.6 „Zum iPhone-Kalender": fordert erst den Schreibzugriff an und zeigt danach
/// `IPhoneKalenderExport` mit dem passenden `EKEvent`, beide auf demselben `EKEventStore`.
struct IPhoneKalenderExportBlatt: View {
    let titel: String
    let start: Date
    let ende: Date
    var ganztaegig = false
    @Environment(\.dismiss) private var dismiss
    /// Erst in `.task` gebaut: `EKEventStore()` ist teuer und entstünde sonst bei jedem Neuaufbau
    /// dieser Ansicht (jedes Rendern des Aufrufers, solange das Blatt offen ist).
    @State private var store: EKEventStore?
    @State private var keineErlaubnis = false

    var body: some View {
        Group {
            if let store {
                // Ohne eigenen NavigationStack: der System-Dialog bringt seine Leiste mit, sonst
                // stünden zwei Leisten übereinander.
                IPhoneKalenderExport(event: event(store), store: store, onFertig: { dismiss() })
                    .ignoresSafeArea()
            } else {
                NavigationStack {
                    Group {
                        if keineErlaubnis {
                            ContentUnavailableView("Kein Zugriff", systemImage: "calendar.badge.exclamationmark", description: Text("Lovea braucht Zugriff auf deinen Kalender, um den Termin einzutragen."))
                        } else {
                            ProgressView()
                        }
                    }
                    .navigationTitle("Zum iPhone-Kalender")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    }
                }
            }
        }
        .task {
            let neu = EKEventStore()
            if (try? await neu.requestWriteOnlyAccessToEvents()) == true {
                store = neu
            } else {
                keineErlaubnis = true
            }
        }
    }

    private func event(_ store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = titel
        event.startDate = start
        event.endDate = ende
        event.isAllDay = ganztaegig
        event.calendar = store.defaultCalendarForNewEvents
        return event
    }
}

extension IPhoneKalenderExportBlatt {
    /// Z-9.6: ein Lovea-Termin als Vorlage. Ohne Uhrzeit ganztägig, ohne Ende eine Stunde.
    init(termin: Termin) {
        let start = IPhoneKalenderDatum.kombiniert(termin.datum, termin.start)
        let ende = termin.ende.map { IPhoneKalenderDatum.kombiniert(termin.datum, $0) } ?? start
        self.init(titel: termin.titel, start: start, ende: ende > start ? ende : start.addingTimeInterval(60 * 60), ganztaegig: termin.start == nil)
    }
}

/// Baut ein Datum aus `yyyy-MM-dd` und optional `HH:mm` (Berlin-Zeitzone). Ohne Uhrzeit wird
/// für den Export sinnvoll 9 Uhr angenommen (ganztägige `EKEvent`s wären für ein Treffen unpassend).
enum IPhoneKalenderDatum {
    static func kombiniert(_ datum: String, _ zeit: String?) -> Date {
        var komponenten = Datum.kalender.dateComponents([.year, .month, .day], from: Datum.datum(datum))
        let minuten = Datum.minuten(zeit) ?? 9 * 60
        komponenten.hour = minuten / 60
        komponenten.minute = minuten % 60
        return Datum.kalender.date(from: komponenten) ?? Datum.datum(datum)
    }
}

/// Z-9.6 „Aus iPhone-Kalender holen": volle Erlaubnis beim ersten Gebrauch, Liste der nächsten
/// 30 Tage, Auswahl ergibt `termin.setzen`. Die `id` kommt aus dem iPhone-Termin, so legt ein
/// zweites Holen desselben Termins kein Doppel an.
struct IPhoneKalenderImport: View {
    @Environment(\.dismiss) private var dismiss
    @State private var eintraege: [Eintrag] = []
    @State private var status: Status = .laedt

    private enum Status { case laedt, keineErlaubnis, fertig }

    /// Wertkopie eines `EKEvent` (nicht Sendable), gelesen abseits des Main Threads. Die `id` ist
    /// je Vorkommen eindeutig: Wiederholungen teilen sich sonst `eventIdentifier`.
    struct Eintrag: Identifiable, Sendable {
        let id: String
        let titel: String
        let start: Date
        let ende: Date
        let ganztaegig: Bool
    }

    var body: some View {
        NavigationStack {
            Group {
                switch status {
                case .laedt:
                    ProgressView()
                case .keineErlaubnis:
                    ContentUnavailableView("Kein Zugriff", systemImage: "calendar.badge.exclamationmark", description: Text("Lovea braucht Zugriff auf deinen Kalender, um Termine zu holen."))
                case .fertig where eintraege.isEmpty:
                    ContentUnavailableView("Keine Termine", systemImage: "calendar", description: Text("In den nächsten 30 Tagen stehen keine Termine in deinem iPhone-Kalender."))
                case .fertig:
                    List(eintraege) { eintrag in
                        Button { uebernehmen(eintrag) } label: { zeile(eintrag) }
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Aus iPhone-Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .task { await laden() }
    }

    private func zeile(_ eintrag: Eintrag) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eintrag.titel)
                .font(.body.weight(.medium))
            Text(eintrag.start.formatted(date: .abbreviated, time: eintrag.ganztaegig ? .omitted : .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func laden() async {
        // Abfrage und Lesen abseits des Main Threads: `events(matching:)` kann bei vielen
        // Kalendern spürbar dauern.
        let ergebnis: [Eintrag]? = await Task.detached(priority: .userInitiated) { () async -> [Eintrag]? in
            let store = EKEventStore()
            guard (try? await store.requestFullAccessToEvents()) == true else { return nil }
            let start = Date()
            let ende = Datum.kalender.date(byAdding: .day, value: 30, to: start) ?? start
            return store.events(matching: store.predicateForEvents(withStart: start, end: ende, calendars: nil))
                .map { event in
                    let beginn: Date = event.startDate ?? start
                    return Eintrag(
                        id: "\(event.calendarItemIdentifier)-\(Int(beginn.timeIntervalSince1970))",
                        titel: event.title ?? "Ohne Titel",
                        start: beginn,
                        ende: event.endDate ?? beginn,
                        ganztaegig: event.isAllDay
                    )
                }
                .sorted { $0.start < $1.start }
        }.value
        if let ergebnis {
            eintraege = ergebnis
            status = .fertig
        } else {
            status = .keineErlaubnis
        }
    }

    private func uebernehmen(_ eintrag: Eintrag) {
        let termin = Termin(
            id: "iphone-\(eintrag.id)",
            fuer: [(Raum.shared.ich ?? .ahmed).rawValue],
            titel: eintrag.titel,
            typ: "sonstiges",
            datum: Datum.text(eintrag.start),
            start: eintrag.ganztaegig ? nil : Datum.uhrzeit(eintrag.start),
            ende: eintrag.ganztaegig ? nil : Datum.uhrzeit(eintrag.ende)
        )
        Raum.shared.senden("termin.setzen", termin)
        Haptik.erfolg()
        dismiss()
    }
}
