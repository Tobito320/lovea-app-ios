import Foundation
import Observation

/// Plans and gym sessions of both people (`TrainingFaltung`), and the own `gym.*` ops.
/// `aktiveUebung(_:)` is the catalog id the figure shows later.
@MainActor @Observable
final class TrainingModell {
    static let shared = TrainingModell()
    private var faltung = TrainingFaltung()

    private init() {
        StartProtokoll.marke("trainingModell.init.vor")
        Raum.shared.beobachten(TrainingFaltung.arten) { [weak self] op in
            self?.faltung.anwenden(op)
            GymLive.abgleichen()
        }
        StartProtokoll.marke("trainingModell.init.nach")
    }

    private var ich: Person { Raum.shared.ich ?? .ahmed }

    // MARK: - Lesen

    func plan(_ p: Person) -> TrainingsPlan { faltung.plaene[p] ?? .leer }
    func sessions(_ p: Person) -> [GymSession] { faltung.sessions(p) }
    func laufende(_ p: Person, jetzt: Date = Date()) -> GymSession? { sessions(p).first { TrainingLogik.laufend($0, jetzt: jetzt) } }
    func vergessene(_ p: Person, jetzt: Date = Date()) -> GymSession? { TrainingLogik.vergessen(sessions(p), jetzt: jetzt) }
    /// Catalog id of the exercise `p` is doing right now; nil outside a running session.
    func aktiveUebung(_ p: Person) -> String? { laufende(p)?.aktiv?.uebung }
    func heutigerTag(_ p: Person) -> TrainingsTag? { TrainingLogik.tag(plan(p), datum: Datum.text(Date())) }
    func tag(_ p: Person, id: String?) -> TrainingsTag? { plan(p).tage.first { $0.id == id } }

    // MARK: - Schreiben (eigene Person)

    func planSichern(_ plan: TrainingsPlan) { Raum.shared.senden("gym.plan", plan) }

    /// Starts a session, ticks today's Gym habit if needed and puts the own figure in the gym.
    @discardableResult
    func einchecken(tag: String?) -> String {
        let id = UUID().uuidString
        Raum.shared.senden("gym.checkin", GymD(session: id, tag: tag, start: Date()))
        let heute = Datum.text(Date())
        if !HealthModell.shared.gymAbgehakt(ich, heute) { HealthModell.shared.setzeGym(datum: heute, an: true) }
        Anwesenheit.shared.anstossen()
        return id
    }

    /// Trainingstag nachträglich wählen: Check-in mit gleicher Zeit nochmal senden (neuester gilt).
    func tagSetzen(_ s: GymSession, _ tag: String) {
        Raum.shared.senden("gym.checkin", GymD(session: s.id, tag: tag, start: s.start))
    }

    func starten(_ session: String, _ u: PlanUebung) {
        Raum.shared.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "start"))
    }

    /// Done. Changed sets become the plan values for next time.
    func fertig(_ session: String, _ u: PlanUebung, saetze: [PlanSatz]) {
        Raum.shared.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "fertig", saetze: u.istCardio ? nil : saetze))
        if !u.istCardio, saetze != u.saetze { planSichern(TrainingLogik.uebernehmen(plan(ich), planUebung: u.id, saetze: saetze)) }
    }

    /// Die Übungen einer Einheit mit ihren Satzzeilen (`WorkoutLogik.uebungen`); leer, wenn es sie nicht gibt.
    func workout(_ session: String, _ person: Person? = nil) -> [WorkoutUebung] {
        let p = person ?? ich
        let alle = sessions(p)
        guard let s = alle.first(where: { $0.id == session }) else { return [] }
        return WorkoutLogik.uebungen(s, tag: tag(p, id: s.tag), frueher: alle.filter { $0.start < s.start })
    }

    /// Der ganze Stand der Satzzeilen einer Übung. Bei jedem Haken, nicht bei jedem Tastendruck.
    func saetzeSenden(_ session: String, _ u: PlanUebung, _ saetze: [PlanSatz]) {
        Raum.shared.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "satz", saetze: saetze, name: u.name))
    }

    /// Nimmt eine im Training dazugekommene Übung wieder heraus.
    func entfernen(_ session: String, _ u: PlanUebung) {
        Raum.shared.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "weg"))
    }

    func zuruecksetzen(_ session: String, _ u: PlanUebung) {
        Raum.shared.senden("gym.uebung", GymD(session: session, plan: u.id, uebung: u.uebung, status: "offen"))
    }

    /// Das Training beenden. Status "ende" löst die Mitteilung an den Partner aus; eine spätere
    /// Zeitkorrektur (`zeitenAendern`) sendet ihn nicht.
    func auschecken(_ session: String, ende: Date = Date()) {
        let start = sessions(ich).first { $0.id == session }?.start
        let minuten = start.map { max(1, Int(ende.timeIntervalSince($0) / 60)) }
        let zahl = WorkoutLogik.saetzeZahl(workout(session))
        Raum.shared.senden("gym.checkout", GymD(session: session, ende: ende, status: "ende", minuten: minuten, zahl: zahl))
        Anwesenheit.shared.anstossen()
    }

    /// Auschecken rückgängig: die Einheit läuft weiter (`TrainingLogik.session`, status "wieder").
    func auscheckenRueckgaengig(_ session: String) {
        Raum.shared.senden("gym.checkout", GymD(session: session, status: "wieder"))
        Anwesenheit.shared.anstossen()
    }

    /// Later correction: resends check-in and/or checkout for the session (newest wins).
    func zeitenAendern(_ s: GymSession, start: Date, ende: Date?) {
        if start != s.start { Raum.shared.senden("gym.checkin", GymD(session: s.id, tag: s.tag, start: start)) }
        if let ende, ende != s.ende { Raum.shared.senden("gym.checkout", GymD(session: s.id, ende: ende)) }
        Anwesenheit.shared.anstossen()
    }

    /// Ein Training von Hand nachtragen (Ahmed, 01.10.): Start und Ende, ohne im Gym einzuchecken.
    func nachtragen(tag: String?, start: Date, ende: Date) {
        let id = UUID().uuidString
        Raum.shared.senden("gym.checkin", GymD(session: id, tag: tag, start: start))
        Raum.shared.senden("gym.checkout", GymD(session: id, ende: ende))
        let datum = Datum.text(start)
        if !HealthModell.shared.gymAbgehakt(ich, datum) { HealthModell.shared.setzeGym(datum: datum, an: true) }
    }

    func loeschen(_ s: GymSession) {
        Raum.shared.senden("gym.loeschen", GymD(session: s.id))
        Anwesenheit.shared.anstossen()
    }
}
