import CoreGraphics
import Foundation

/// R6: Wischen zwischen den Haupt-Tabs (Home, Chat, Zeichnen, Health, Profil), wie bei
/// Snapchat/Instagram. Nur die reine Entscheidung hier — Geste und Haptik sitzen in
/// `TabWischGeste.swift`, damit diese Logik ohne SwiftUI/UIKit testbar bleibt.
enum TabWischRichtung: Equatable {
    case vorherigerTab
    case naechsterTab
}

enum TabWischLogik {
    /// Unter dieser Auslenkung ist es kein Wisch, sondern Scrollen/Antippen.
    static let mindestStrecke: CGFloat = 60
    /// Start zu nah am Rand = System-Zurück-Wischen (gepushter Screen), nicht Tab-Wechsel.
    static let randAbstand: CGFloat = 30

    /// Einstellungen: "Zwischen Tabs wischen" (`@AppStorage`), Standard an.
    static let schluessel = "lovea.tabWischen"

    static func aktiv(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: schluessel) as? Bool ?? true
    }

    /// Darf die Wisch-Geste überhaupt beginnen? Einmal beim Start der Berührung gefragt
    /// (`gestureRecognizerShouldBegin`). `vx`/`vy`: Anfangsgeschwindigkeit; senkrechtes Scrollen
    /// bleibt so unberührt. `innenBelegt`: ein innerer horizontaler Bereich gewinnt (`TabWischSperre`).
    static func darfBeginnen(vx: CGFloat, vy: CGFloat, startX: CGFloat, breite: CGFloat, aktiv: Bool, innenBelegt: Bool) -> Bool {
        guard aktiv, !innenBelegt else { return false }
        guard startX > randAbstand, startX < breite - randAbstand else { return false }
        return abs(vx) > 2 * abs(vy)
    }

    /// Kann eine horizontale Scroll-Fläche in Fingerrichtung noch scrollen? Nur dann gehört ihr die
    /// Berührung; am Anschlag oder ohne überstehenden Inhalt wechselt der Tab.
    /// Finger nach links = Inhalt rückt nach links = `offset` wächst.
    static func kannHorizontalScrollen(offset: CGFloat, inhalt: CGFloat, sicht: CGFloat, insetLinks: CGFloat, insetRechts: CGFloat, fingerNachLinks: Bool) -> Bool {
        let toleranz: CGFloat = 1
        let kleinster = -insetLinks
        let groesster = inhalt + insetRechts - sicht
        guard groesster - kleinster > toleranz else { return false }
        return fingerNachLinks ? offset < groesster - toleranz : offset > kleinster + toleranz
    }

    /// `dx`/`dy`: Endauslenkung der Geste (dx mit Nachlauf). `startX`/`breite`: Startpunkt und
    /// Fensterbreite, um den Rand (Zurück-Wischen) auszusparen. `aktiv`: der Schalter in den
    /// Einstellungen. `nil` heißt: keine Reaktion.
    static func richtung(dx: CGFloat, dy: CGFloat, startX: CGFloat, breite: CGFloat, aktiv: Bool = true) -> TabWischRichtung? {
        guard aktiv else { return nil }
        guard startX > randAbstand, startX < breite - randAbstand else { return nil }
        guard abs(dx) > mindestStrecke, abs(dx) > 2 * abs(dy) else { return nil }
        return dx < 0 ? .naechsterTab : .vorherigerTab
    }
}
