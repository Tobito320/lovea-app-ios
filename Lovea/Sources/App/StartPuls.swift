import Foundation

/// Build 78 (Ahmed, neue Spur): weder Absturz- noch JetsamEvent-Log auf dem Gerät, obwohl die App
/// sofort schließt — vermutlich killt das System den Prozess (Speicher-Limit, Watchdog-Hänger),
/// etwas, das ein Signal-Handler nie sieht. Für die ersten 30 Sekunden im Vordergrund schreibt dieser
/// StartPuls alle 500 ms eine Breadcrumb-Zeile mit freiem Speicher und wie lange der Hauptthread
/// zuletzt geantwortet hat — zeigt im nächsten Start, ob der Prozess hing oder der Speicher vor dem
/// Tod hochlief. Danach (und beim Hintergrund-Wechsel) stoppt der Timer wieder (Akku-Regel: kein
/// Dauer-Timer, nur die ersten 30 s nach jedem Start).
final class StartPuls: @unchecked Sendable {
    static let shared = StartPuls()
    private let sperre = NSLock()
    private var letzteMainAntwort = Date()
    private var timer: DispatchSourceTimer?
    private var startZeit = Date()
    private init() {}

    func starten() {
        sperre.withLock {
            guard timer == nil else { return }
            letzteMainAntwort = Date()
            startZeit = Date()
            let t = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "lovea.herzschlag"))
            t.schedule(deadline: .now() + 0.5, repeating: 0.5)
            t.setEventHandler { [weak self] in self?.schlag() }
            timer = t
            t.resume()
        }
    }

    func stoppen() {
        sperre.withLock {
            timer?.cancel()
            timer = nil
        }
    }

    private func schlag() {
        let (laeuftNoch, blockiertSek) = sperre.withLock {
            (Date().timeIntervalSince(startZeit) <= 30, Date().timeIntervalSince(letzteMainAntwort))
        }
        guard laeuftNoch else {
            stoppen()
            return
        }
        DispatchQueue.main.async { [weak self] in self?.mainAntwort() }
        StartProtokoll.marke("herzschlag mainBlockiert=\(Int(blockiertSek * 1000))ms")
    }

    private func mainAntwort() {
        sperre.withLock { letzteMainAntwort = Date() }
    }
}
