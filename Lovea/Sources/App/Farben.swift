import SwiftUI
import UIKit

extension Color {
    /// Akzentfarbe aus dem App-Icon.
    static let loveaRose = Color(red: 0xFF / 255, green: 0x3B / 255, blue: 0x5C / 255)

    /// Personenfarbe für Chat-Blasen, Kalender und Karte (Spec 3).
    static func person(_ p: Person) -> Color {
        switch p {
        case .annika:
            // #E0284A instead of the icon rosé #FF3B5C: white body text needs 4.5:1 (HIG), #FF3B5C gives 3.48:1.
            return Color(red: 0xE0 / 255, green: 0x28 / 255, blue: 0x4A / 255)
        case .ahmed:
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0xF5 / 255, green: 0xEE / 255, blue: 0xF1 / 255, alpha: 1)
                    : UIColor(red: 0x6B / 255, green: 0x2A / 255, blue: 0x4A / 255, alpha: 1)
            })
        }
    }

    /// Textfarbe für Personenfarben-Chat-Blasen: weiß, außer auf Ahmeds Perlweiß im Dunkelmodus.
    static func personText(_ p: Person) -> Color {
        switch p {
        case .annika:
            return .white
        case .ahmed:
            return Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0x2A / 255, green: 0x14 / 255, blue: 0x20 / 255, alpha: 1)
                    : .white
            })
        }
    }
}
