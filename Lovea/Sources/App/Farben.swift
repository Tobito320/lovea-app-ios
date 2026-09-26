import SwiftUI

extension Color {
    /// Akzentfarbe aus dem App-Icon.
    static let loveaRose = Color(red: 0xFF / 255, green: 0x3B / 255, blue: 0x5C / 255)

    /// Personenfarbe überall in der App (Runde 3, Spec 8): Ahmed Blau, Annika Rosé, hell wie dunkel gleich.
    static func person(_ p: Person) -> Color {
        switch p {
        case .annika:
            // #E0284A instead of the icon rosé #FF3B5C: white body text needs 4.5:1 (HIG), #FF3B5C gives 3.48:1.
            return Color(red: 0xE0 / 255, green: 0x28 / 255, blue: 0x4A / 255)
        case .ahmed:
            // #2F6FE4: white text 4.65:1.
            return Color(red: 0x2F / 255, green: 0x6F / 255, blue: 0xE4 / 255)
        }
    }

    /// Textfarbe auf einer Personenfarbe: für beide weiß.
    static func personText(_ p: Person) -> Color { .white }
}
