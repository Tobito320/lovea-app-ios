import Foundation

/// R6-Fix (Review 01.10.): innere horizontale Gesten (Wochenstreifen, Kalendermonat,
/// Pünktlich-Karte wegwischen, ...) beanspruchen die laufende Berührung, sobald sie eine klar
/// horizontale Bewegung erkennen — der Tab-Wisch lässt die Berührung dann in Ruhe. Selbst-verfallend
/// statt manuell zurückgesetzt: jede `onChanged`-Bewegung erneuert den Anspruch um ein kurzes
/// Fenster, das kurz nach Loslassen von selbst abläuft. Das macht die Reihenfolge der
/// `onEnded`-Aufrufe zwischen konkurrierenden Gesten egal — der Tab-Wisch prüft in seinem eigenen
/// `onEnded` einfach, ob gerade (noch) jemand beansprucht hat.
@MainActor
final class TabWischSperre {
    static let shared = TabWischSperre()
    private var bisZeitpunkt = Date.distantPast
    private init() {}

    /// Eine innere horizontale Geste ruft das bei jeder erkannten Bewegung auf (`onChanged`).
    func beanspruchen() { bisZeitpunkt = Date().addingTimeInterval(0.3) }

    /// Der Tab-Wisch prüft das in `onEnded`, bevor er den Tab wechselt.
    var istBeansprucht: Bool { Date() < bisZeitpunkt }
}
