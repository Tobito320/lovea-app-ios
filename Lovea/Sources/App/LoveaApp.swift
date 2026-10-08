import SwiftUI
import TipKit
import UIKit

@main
struct LoveaApp: App {
    @UIApplicationDelegateAdaptor(LoveaAppDelegate.self) private var appDelegate
    @StateObject private var session = PersonSession()
    @AppStorage("lovea.ersterStartFertig") private var ersterStartFertig = false
    @Environment(\.scenePhase) private var scenePhase
    /// R3 (Build 78): >= 2 Abstürze in Folge -> Sicherheitsmodus, siehe `StartProtokoll.abgesichert`.
    /// Nur dieser eine Zustand entscheidet, was `body` zeigt — "Normal starten" setzt ihn auf false.
    @State private var abgesichert: Bool
    @State private var bericht: AbsturzBericht?
    @State private var berichtGezeigt = false

    /// UI-Tests laufen oft über `XCUIApplication` (killt den Prozess ohne `.background` — sonst
    /// zählte jeder Testlauf als Absturz) oder über `-uiTestStudio` (kein echter Launch-Pfad).
    private static var istTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestStudio")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        guard !Self.istTest else {
            _abgesichert = State(initialValue: false)
            _bericht = State(initialValue: nil)
            return
        }
        AbsturzFaenger.installieren() // Allererstes: vor jeder anderen App-Logik.
        // AppErklaerungen.swift: jeder Tip einmal pro Stunde höchstens, kein `.immediate` (sonst poppt
        // beim ersten Start alles auf einmal auf).
        try? Tips.configure([.displayFrequency(.hourly)])
        let vorherCrash = StartProtokoll.neuerStart()
        let alteStufe = StartProtokoll.alteStufeEinmalLesen()
        _bericht = State(initialValue: AbsturzBericht.erfassen(vorherCrash: vorherCrash, altesStufenFeld: alteStufe))
        _abgesichert = State(initialValue: StartProtokoll.abgesichert)
        StartProtokoll.marke("loveaApp.init.start")
        StartProtokoll.marke("loveaApp.init.ende")
    }

    var body: some Scene {
        return WindowGroup {
            if abgesichert {
                // R3: NUR der Absturz-Bericht — kein Raum/Sync, keine Modelle, keine Live
                // Activities, kein WorkoutUhr, nichts Launch-Seitiges. "Normal starten" setzt den
                // Zähler zurück und wechselt in den normalen Zweig unten, der alles selbst startet.
                AbsturzBerichtAnsicht(bericht: bericht, zeigtSchliessen: false, zeigtNormalStarten: true) {
                    StartProtokoll.zaehlerZuruecksetzenNachSichtbar()
                    abgesichert = false
                }
            } else {
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
                    // R3: deckt einen Start ab, der im Hintergrund begann (Silent-Push/HealthKit)
                    // und erst jetzt eine Szene zeigt — `unsauberZaehlen()` zählt höchstens einmal
                    // pro Prozess, ist also ein no-op, wenn `didFinishLaunching` schon zählte.
                    StartProtokoll.unsauberZaehlen()
                    StartPuls.shared.starten()
                    AppStart.erstesBildGezeigt()
                    if bericht != nil { berichtGezeigt = true }
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
                // R3: einmalig (Sheet-Bindung, nicht erneut gesetzt), danach sind die Dateien schon
                // gelöscht (`AbsturzBericht.erfassen`) — ein zweiter Start zeigt nichts mehr.
                .sheet(isPresented: $berichtGezeigt) {
                    AbsturzBerichtAnsicht(bericht: bericht)
                }
                // R3: 5 s sichtbar ohne Absturz -> Zähler zurück, ohne auf `.background` zu warten.
                .task {
                    guard !Self.istTest else { return }
                    try? await Task.sleep(for: .seconds(5))
                    StartProtokoll.zaehlerZuruecksetzenNachSichtbar()
                }
            }
        }
    }

    private func starten(_ person: Person?) {
        Raum.shared.ich = person
        guard let person else { return }
        SchlafSignale.bootErfassen()
        // Bundle JSON (questions, date ideas) is read on first access; do that off the main thread.
        Task.detached(priority: .utility) { _ = FrageDesTages.vorrat; _ = WirModell.ideenVorrat }
        StartProtokoll.marke("modelle.falten.vor")
        AppStart.falten(person)
        StartProtokoll.marke("modelle.falten.nach")
        StartProtokoll.marke("raum.start.vor")
        Raum.shared.start()
        AppKann.shared.melden()
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
            SchlafSignale.aktivMelden()
            WidgetPendingOpsMerge.abholen()
            StartProtokoll.marke("gym.abgleichen.start")
            GymLive.abgleichen() // z. B. auf dem iPad eingecheckt, oder die Einheit ist abgelaufen
            StartProtokoll.marke("workoutuhr.mitteilungLoeschen.vor")
            WorkoutUhr.shared.mitteilungLoeschen() // im Vordergrund vibriert die Leiste selbst
            StartProtokoll.marke("workoutuhr.mitteilungLoeschen.nach")
        }
        if phase == .background {
            SchlafSignale.lebtMelden()
            AppStart.erstesBildGezeigt(wartezeit: .zero) // kam das erste Bild nie, wartende Start-Arbeit jetzt freigeben
            GalerieSync.shared.hintergrund()
            StartProtokoll.marke("workoutuhr.mitteilungPlanen.vor")
            WorkoutUhr.shared.mitteilungPlanen()
            StartProtokoll.marke("workoutuhr.mitteilungPlanen.nach")
            StartPuls.shared.stoppen()
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
    private static var erstesBildGemeldet = false
    private static var erstesBildDa = false
    private static var wartende: [CheckedContinuation<Void, Never>] = []

    /// Schneller Start (`StartPlan`): Arbeit, die erst nach dem ersten Bild nötig ist, wartet hier.
    static func erstesBildAbwarten() async {
        guard !erstesBildDa else { return }
        await withCheckedContinuation { (fortsetzung: CheckedContinuation<Void, Never>) in
            wartende.append(fortsetzung)
        }
    }

    /// Von der Szene-`onAppear`. `wartezeit` lässt das Bild erst stehen (Schätzung, nicht gemessen).
    static func erstesBildGezeigt(wartezeit: Duration = .seconds(1)) {
        guard !erstesBildGemeldet else { return }
        erstesBildGemeldet = true
        Task { @MainActor in
            if wartezeit > .zero { try? await Task.sleep(for: wartezeit) }
            erstesBildDa = true
            let liste = wartende
            wartende = []
            for fortsetzung in liste { fortsetzung.resume() }
        }
    }

    static func falten(_ person: Person) {
        Raum.shared.ich = person
        guard gefaltetFuer != person else { return } // twice would double WidgetStandSchreiber's observation chain
        gefaltetFuer = person
        // Register every fold before the log replays.
        _ = FigurenModell.shared; _ = ChatModell.shared; _ = ChatEinstellungen.shared; _ = OrteModell.shared
        _ = KalenderModell.shared; _ = WirModell.shared; _ = SpieleModell.shared; _ = EinstellungenModell.shared
        _ = TeilenModell.shared; _ = LiveZeichnung.shared; _ = UmzugImport.shared; _ = HealthModell.shared
        _ = PunkteModell.shared; _ = UmzugAufraeumen.shared; _ = WetterModell.shared; _ = TrainingModell.shared
        // Build 78 (Ahmed, Live-Activity-Befund): fehlte hier -- entstand erst lazy, wenn EssenLive
        // es zum ersten Mal anfasste, dessen Fold-Beobachter war beim Replay also noch nicht
        // registriert und frühe Ernährungs-Ops wurden verpasst (zeigte "0 kcal" trotz echter Einträge).
        _ = ErnaehrungModell.shared
        let spaeter = StartPlan.zeitpunkt(schneller: StartPlan.an(), hintergrundStart: UIApplication.shared.applicationState == .background) == .nachErstemBild
        StartProtokoll.marke("startplan.spaeter=\(spaeter)")
        GalerieSync.shared.start(nachErstemBild: spaeter)
        // Kein Prompt hier (nur `sicherstellen()` vom Health-Tab darf fragen) — startet HealthKit-
        // Observer/Background-Delivery erneut, falls die Berechtigung früher schon erteilt wurde.
        // Die Replay-Kette existiert schon (Registrierung oben); `Raum.shared.leer()` im Handler wartet darauf.
        HealthModell.shared.beobachtenStartenFallsErlaubt()
        // Z-28.2: Widget-Stand-Schreiber, damit auch ein Hintergrund-Start das Widget aktualisiert.
        if spaeter {
            Task { @MainActor in
                await erstesBildAbwarten()
                WidgetStandSchreiber.shared.start()
            }
        } else {
            WidgetStandSchreiber.shared.start()
        }
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
