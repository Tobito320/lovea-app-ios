import SwiftUI

@main
struct LoveaApp: App {
    @UIApplicationDelegateAdaptor(LoveaAppDelegate.self) private var appDelegate
    @StateObject private var session = PersonSession()
    @AppStorage("lovea.ersterStartFertig") private var ersterStartFertig = false
    @Environment(\.scenePhase) private var scenePhase

    /// UI-Tests laufen oft über `XCUIApplication` (killt den Prozess ohne `.background` — sonst
    /// zählte jeder Testlauf als Absturz) oder über `-uiTestStudio` (kein echter Launch-Pfad).
    private static var istTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestStudio")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        guard !Self.istTest else { return }
        AbsturzFaenger.installieren() // Allererstes: vor jeder anderen App-Logik.
        StartProtokoll.neuerStart()
        StartProtokoll.marke("loveaApp.init.start")
        StartProtokoll.marke("loveaApp.init.ende")
    }

    var body: some Scene {
        StartProtokoll.marke("loveaApp.body")
        return WindowGroup {
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
            .onAppear {
                guard !Self.istTest else { return }
                StartProtokoll.szeneErreicht()
                Herzschlag.shared.starten()
            }
            .onChange(of: session.person, initial: true) { _, person in starten(person) }
            .onChange(of: scenePhase) { _, phase in phaseGewechselt(phase) }
            // Z-28.3: `widgetURL` der Widgets, z. B. `lovea://health`. `AppNavigation.tabWunsch`
            // ignoriert selbst jeden unbekannten Host (siehe `AppRootView`s `onChange`).
            // R8: `lovea://essen?mahlzeit=…` (Live-Activity-Mahlzeitenzeile) trägt zusätzlich die
            // Mahlzeit in der Query — `essenMahlzeitWunsch` öffnet dafür direkt das Hinzufügen-Blatt.
            .onOpenURL { url in
                AppNavigation.shared.tabWunsch = url.host
                let teile = URLComponents(url: url, resolvingAgainstBaseURL: false)
                AppNavigation.shared.essenMahlzeitWunsch = teile?.queryItems?.first { $0.name == "mahlzeit" }?.value
            }
        }
    }

    private func starten(_ person: Person?) {
        Raum.shared.ich = person
        guard let person else { return }
        // Bundle JSON (questions, date ideas) is read on first access; do that off the main thread.
        Task.detached(priority: .utility) { _ = FrageDesTages.vorrat; _ = WirModell.ideenVorrat }
        StartProtokoll.marke("modelle.falten.vor")
        AppStart.falten(person)
        StartProtokoll.marke("modelle.falten.nach")
        StartProtokoll.marke("raum.start.vor")
        Raum.shared.start()
        StartProtokoll.marke("raum.start.nach")
        Standort.shared.start()
        // Z-28.2/Z-28.3: wartende Gym-Ops aus den Widgets abholen.
        WidgetPendingOpsMerge.abholen()
    }

    private func phaseGewechselt(_ phase: ScenePhase) {
        guard !Self.istTest else { return }
        StartProtokoll.marke("phaseGewechselt.\(String(describing: phase)).vor")
        Raum.shared.aktiv(phase == .active, hintergrund: phase == .background)
        if phase == .active {
            WidgetPendingOpsMerge.abholen()
            StartProtokoll.marke("gym.abgleichen.start")
            GymLive.abgleichen() // z. B. auf dem iPad eingecheckt, oder die Einheit ist abgelaufen
            StartProtokoll.marke("workoutuhr.mitteilungLoeschen.vor")
            WorkoutUhr.shared.mitteilungLoeschen() // im Vordergrund vibriert die Leiste selbst
            StartProtokoll.marke("workoutuhr.mitteilungLoeschen.nach")
        }
        if phase == .background {
            GalerieSync.shared.hintergrund()
            StartProtokoll.marke("workoutuhr.mitteilungPlanen.vor")
            WorkoutUhr.shared.mitteilungPlanen()
            StartProtokoll.marke("workoutuhr.mitteilungPlanen.nach")
            Herzschlag.shared.stoppen()
            // Normaler Hintergrund-Wechsel, kein Absturz: der nächste Start soll nicht fälschlich
            // als Absturz zählen.
            StartProtokoll.sauber()
        }
        StartProtokoll.marke("phaseGewechselt.\(String(describing: phase)).nach")
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
        _ = PunkteModell.shared; _ = UmzugAufraeumen.shared; _ = WetterModell.shared; _ = TrainingModell.shared
        GalerieSync.shared.start()
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
