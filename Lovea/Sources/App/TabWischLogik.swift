import CoreGraphics

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

    /// `dx`/`dy`: Endauslenkung der Geste. `startX`/`breite`: Startpunkt und Bildschirmbreite der
    /// Geste, um den Rand (Zurück-Wischen) auszusparen. `nil` heißt: keine Reaktion.
    static func richtung(dx: CGFloat, dy: CGFloat, startX: CGFloat, breite: CGFloat) -> TabWischRichtung? {
        guard startX > randAbstand, startX < breite - randAbstand else { return nil }
        guard abs(dx) > mindestStrecke, abs(dx) > 2 * abs(dy) else { return nil }
        return dx < 0 ? .naechsterTab : .vorherigerTab
    }
}
