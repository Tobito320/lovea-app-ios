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

/// Z-9.6 „Zum iPhone-Kalender": fordert erst den Schreibzugriff an (`requestWriteOnlyAccessToEvents`)
/// und zeigt danach `IPhoneKalenderExport` mit dem passenden `EKEvent` — beide auf demselben
/// `EKEventStore`, sonst kennt der Editor das übergebene Event nicht.
struct IPhoneKalenderExportBlatt: View {
    let titel: String
    let start: Date
    let ende: Date
    @Environment(\.dismiss) private var dismiss
    @State private var store = EKEventStore()
    @State private var status: ExportStatus = .laedt

    private enum ExportStatus { case laedt, keineErlaubnis, bereit }

    var body: some View {
        NavigationStack {
            Group {
                switch status {
                case .laedt:
                    ProgressView()
                case .keineErlaubnis:
                    ContentUnavailableView("Kein Zugriff", systemImage: "calendar.badge.exclamationmark", description: Text("Lovea braucht Zugriff auf deinen Kalender, um den Termin einzutragen."))
                case .bereit:
                    IPhoneKalenderExport(event: event, store: store, onFertig: { dismiss() })
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Zum iPhone-Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if status != .bereit {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                }
            }
        }
        .task {
            let erlaubt = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
            status = erlaubt ? .bereit : .keineErlaubnis
        }
    }

    private var event: EKEvent {
        let event = EKEvent(eventStore: store)
        event.title = titel
        event.startDate = start
        event.endDate = ende
        event.calendar = store.defaultCalendarForNewEvents
        return event
    }
}

/// Baut ein Datum aus `yyyy-MM-dd` und optional `HH:mm` (Berlin-Zeitzone). Ohne Uhrzeit wird
/// für den Export sinnvoll 9 Uhr angenommen (ganztägige `EKEvent`s wären für ein Treffen unpassend).
enum IPhoneKalenderDatum {
    static func kombiniert(_ datum: String, _ zeit: String?) -> Date {
        var komponenten = Datum.kalender.dateComponents([.year, .month, .day], from: Datum.datum(datum))
        if let zeit, let doppelpunkt = zeit.firstIndex(of: ":"),
           let stunde = Int(zeit[..<doppelpunkt]), let minute = Int(zeit[zeit.index(after: doppelpunkt)...]) {
            komponenten.hour = stunde
            komponenten.minute = minute
        } else {
            komponenten.hour = 9
            komponenten.minute = 0
        }
        return Datum.kalender.date(from: komponenten) ?? Datum.datum(datum)
    }
}

/// Z-9.6 „Aus iPhone-Kalender holen": volle Erlaubnis beim ersten Gebrauch, Liste der nächsten
/// 30 Tage, Auswahl ergibt `termin.setzen`.
struct IPhoneKalenderImport: View {
    let datum: String
    @Environment(\.dismiss) private var dismiss
    @State private var events: [EKEvent] = []
    @State private var status: Status = .laedt

    private enum Status { case laedt, keineErlaubnis, fertig }

    var body: some View {
        NavigationStack {
            Group {
                switch status {
                case .laedt:
                    ProgressView()
                case .keineErlaubnis:
                    ContentUnavailableView("Kein Zugriff", systemImage: "calendar.badge.exclamationmark", description: Text("Lovea braucht Zugriff auf deinen Kalender, um Termine zu holen."))
                case .fertig where events.isEmpty:
                    ContentUnavailableView("Keine Termine", systemImage: "calendar", description: Text("In den nächsten 30 Tagen stehen keine Termine in deinem iPhone-Kalender."))
                case .fertig:
                    List(events, id: \.eventIdentifier) { event in
                        Button {
                            uebernehmen(event)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title ?? "Ohne Titel")
                                    .font(.body.weight(.medium))
                                Text(event.startDate, style: .date) + Text(" · ") + Text(event.startDate, style: .time)
                            }
                        }
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

    private func laden() async {
        let store = EKEventStore()
        let erlaubt = (try? await store.requestFullAccessToEvents()) ?? false
        guard erlaubt else {
            status = .keineErlaubnis
            return
        }
        let start = Date()
        let ende = Datum.kalender.date(byAdding: .day, value: 30, to: start) ?? start
        let suche = store.predicateForEvents(withStart: start, end: ende, calendars: nil)
        events = store.events(matching: suche).sorted { $0.startDate < $1.startDate }
        status = .fertig
    }

    private func uebernehmen(_ event: EKEvent) {
        let start = event.startDate ?? Date()
        let endeUhrzeit = event.isAllDay ? nil : event.endDate.map(Self.uhrzeitText)
        let termin = Termin(
            id: UUID().uuidString,
            fuer: [(Raum.shared.ich ?? .ahmed).rawValue],
            titel: event.title ?? "Termin",
            typ: "sonstiges",
            datum: Datum.text(start),
            start: event.isAllDay ? nil : Self.uhrzeitText(start),
            ende: endeUhrzeit
        )
        Raum.shared.senden("termin.setzen", termin)
        dismiss()
    }

    private static func uhrzeitText(_ datum: Date) -> String {
        let komponenten = Datum.kalender.dateComponents([.hour, .minute], from: datum)
        return String(format: "%02d:%02d", komponenten.hour ?? 0, komponenten.minute ?? 0)
    }
}
