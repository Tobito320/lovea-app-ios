import SwiftUI

@main
struct LoveaApp: App {
    @UIApplicationDelegateAdaptor(LoveaAppDelegate.self) private var appDelegate
    @StateObject private var session = PersonSession()
    @AppStorage("lovea.ersterStartFertig") private var ersterStartFertig = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-uiTestStudio") {
                    UITestStudio()
                } else if let person = session.person, ersterStartFertig {
                    AppRootView(session: session, person: person)
                } else {
                    ErsterStart(vorausgewaehltePerson: session.person) { person in
                        session.waehlen(person)
                        ersterStartFertig = true
                    }
                }
            }
            .onChange(of: session.person, initial: true) { _, person in starten(person) }
            .onChange(of: scenePhase) { _, phase in phaseGewechselt(phase) }
            // Z-28.3: `widgetURL` der Widgets, z. B. `lovea://health`. `AppNavigation.tabWunsch`
            // ignoriert selbst jeden unbekannten Host (siehe `AppRootView`s `onChange`).
            .onOpenURL { url in AppNavigation.shared.tabWunsch = url.host }
        }
    }

    private func starten(_ person: Person?) {
        Raum.shared.ich = person
        guard let person else { return }
        // Bundle JSON (questions, date ideas) is read on first access; do that off the main thread.
        Task.detached(priority: .utility) { _ = FrageDesTages.vorrat; _ = WirModell.ideenVorrat }
        AppStart.falten(person)
        Raum.shared.start()
        Standort.shared.start()
        // Z-28.2/Z-28.3: wartende Gym-Ops aus den Widgets abholen.
        WidgetPendingOpsMerge.abholen()
    }

    private func phaseGewechselt(_ phase: ScenePhase) {
        Raum.shared.aktiv(phase == .active, hintergrund: phase == .background)
        if phase == .active { WidgetPendingOpsMerge.abholen() }
    }
}

/// Final-Review I-7: everything a launch needs WITHOUT a scene — runs from
/// `LoveaAppDelegate.didFinishLaunching` (a HealthKit background relaunch may never connect a
/// scene, and Apple wants the observer queries set up there) and again from the scene's `starten`.
/// Deliberately no `Raum.shared.start()`: in a background launch no scenePhase change would ever
/// close that socket; the HealthKit handler's `nachholenBisFertig` connects and disconnects itself.
@MainActor
enum AppStart {
    private static var gefaltetFuer: Person?

    static func falten(_ person: Person) {
        Raum.shared.ich = person
        guard gefaltetFuer != person else { return } // twice would double WidgetStandSchreiber's observation chain
        gefaltetFuer = person
        // Register every fold before the log replays.
        _ = FigurenModell.shared; _ = ChatModell.shared; _ = ChatEinstellungen.shared; _ = OrteModell.shared
        _ = KalenderModell.shared; _ = WirModell.shared; _ = SpieleModell.shared; _ = EinstellungenModell.shared
        _ = TeilenModell.shared; _ = LiveZeichnung.shared; _ = UmzugImport.shared; _ = HealthModell.shared
        _ = PunkteModell.shared; _ = UmzugAufraeumen.shared; _ = WetterModell.shared
        // Kein Prompt hier (nur `sicherstellen()` vom Health-Tab darf fragen) — startet HealthKit-
        // Observer/Background-Delivery erneut, falls die Berechtigung früher schon erteilt wurde.
        // Die Replay-Kette existiert schon (Registrierung oben); `Raum.shared.leer()` im Handler wartet darauf.
        HealthModell.shared.beobachtenStartenFallsErlaubt()
        // Z-28.2: Widget-Stand-Schreiber, damit auch ein Hintergrund-Start das Widget aktualisiert.
        WidgetStandSchreiber.shared.start()
    }
}

/// UI tests start straight in an empty studio with a throwaway library.
private struct UITestStudio: View {
    @State private var library: ArtworkLibrary
    @State private var artworkID: UUID

    init() {
        let library = ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-\(UUID().uuidString)"))
        _library = State(initialValue: library)
        _artworkID = State(initialValue: library.createArtwork(name: "Test", projectID: nil, format: .square).id)
    }

    var body: some View {
        NavigationStack {
            DrawingStudioView(
                artworkID: artworkID,
                library: library,
                person: .annika
            )
        }
    }
}
