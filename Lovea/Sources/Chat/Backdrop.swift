import SwiftUI
import UIKit

/// Z-34.1: light particles drawn over a backdrop (`BackdropPartikel`), still under Reduce Motion.
enum BackdropAnimation: Sendable { case keine, herzen, funkeln, blueten, schnee, blaetter, glitzer }

/// One chat backdrop (Spec 2.8): a picture for both of you plus the bubble colors it brings.
struct Backdrop: Identifiable, Sendable {
    let id: String
    let name: String
    let verlauf: [Color]        // eigene Blase, 2–3 Stopps
    let eigeneText: Color
    let partnerBlase: Color     // hell/dunkel adaptiv
    let partnerText: Color
    let ersatz: [Color]         // 9 Farben für MeshGradient 3×3, falls das Bild fehlt
    let animation: BackdropAnimation
    var bildName: String { "backdrop-\(id)" }
}

/// `chat.backdrop` (shared, last write wins): a template, an own photo or an own drawing. Both
/// own kinds carry the id of an uploaded medium, so the partner's phone can show them too.
enum BackdropWahl: Equatable, Sendable { case vorlage(String), foto(String), zeichnung(String) }

/// The 16 backdrops in picker order, plus `neutral` for photo, drawing or no choice. Every
/// bubble/text pair reaches 4.5 : 1 in light and dark, own gradients at every point
/// (`BackdropTests`).
@MainActor
enum Backdrops {
    static let alle: [Backdrop] = [
        eintrag("romantic", "Romantic", [0xD62C63, 0xA8174A, 0x7A0F3C], hell: 0xFBEEF2, dunkel: 0x33242A,
                ersatz: [0xF9D3DC, 0xF6C0CE, 0xFBDDE4, 0xF08FAA, 0xF3A6BA, 0xE77794, 0xC8385F, 0xD9537A, 0xA82650], .herzen),
        eintrag("flirty", "Flirty", [0xD81F76, 0xB0179A, 0x7A22C9], hell: 0xFCEDF5, dunkel: 0x33232E,
                ersatz: [0xFFC3B8, 0xFFB0CB, 0xFFA3C2, 0xFF7EA8, 0xF76AA8, 0xE45BB5, 0xC449B8, 0xA945C8, 0x7E3FCF], .herzen),
        eintrag("monochrome", "Monochrome", [0x505053, 0x2C2C2E, 0x161618], hell: 0xEDEDEE, dunkel: 0x2A2A2C,
                ersatz: [0xF2F2F2, 0xE4E4E5, 0xF7F7F7, 0xC9C9CB, 0xD8D8DA, 0xB5B5B8, 0x7D7D80, 0x96969A, 0x5E5E61]),
        eintrag("coquette", "Coquette", [0xC63F79, 0xA8457F, 0x8A4F9E], hell: 0xFDF0F4, dunkel: 0x33262C,
                ersatz: [0xFFF3F6, 0xFAD9E4, 0xE3EEFB, 0xF7CADA, 0xFFF7F2, 0xD3E5F8, 0xF2B8CD, 0xF9D2DF, 0xC2DAF3], .glitzer),
        eintrag("dark-academia", "Dark Academia", [0xE6CD95, 0xC9A566], text: 0x2B1D12, hell: 0xECEAE6, dunkel: 0x2E2620,
                ersatz: [0x2E211A, 0x3D2B20, 0x22302A, 0x4A3527, 0x33271F, 0x2B3A31, 0x1C1612, 0x3B2A1F, 0x16201B]),
        eintrag("y2k", "Y2K", [0xD4007A, 0x8F2BF0, 0x3D4EF5], hell: 0xF1EDFD, dunkel: 0x29243A,
                ersatz: [0xFFC2F2, 0xC4E8FF, 0xE3CCFF, 0xFF8FDD, 0xD2F4FF, 0xA88BFF, 0x8FE9FF, 0xF6A8FF, 0x7C7CFF], .glitzer),
        eintrag("soft-pastel", "Soft Pastel", [0xAB4F93, 0x8458BD, 0x5A6BC0], hell: 0xF6F0FA, dunkel: 0x2D2833,
                ersatz: [0xFDE4EE, 0xEEE2FA, 0xDDF3EC, 0xF9D4E3, 0xFFF6EA, 0xDAE8FB, 0xEDD9F8, 0xFCE4D9, 0xD2F0E7]),
        eintrag("old-money", "Old Money", [0x2F5D46, 0x1F3F30], text: 0xFFFDF6, hell: 0xF4EFE6, dunkel: 0x2B2A26,
                ersatz: [0xF6F1E7, 0xEDE3D1, 0xF4EEE3, 0xE3D6BF, 0xD9C8AA, 0xE9DECB, 0xC7AE88, 0xB89D76, 0xD2BD9A]),
        eintrag("night-sky", "Night Sky", [0x5A48D6, 0x3A2FA8, 0x241F73], hell: 0xECEEF8, dunkel: 0x222536,
                ersatz: [0x0B1026, 0x141A3D, 0x0D1330, 0x1B1E4A, 0x2A2059, 0x131B47, 0x2D1B50, 0x3B2568, 0x1B1542], .funkeln),
        eintrag("kirschbluete", "Kirschblüte", [0xC64272, 0xAB3868, 0x8F2F63], hell: 0xFDF0F5, dunkel: 0x33262C,
                ersatz: [0xEAF3FF, 0xFFF1F6, 0xFCE3EC, 0xFBD6E4, 0xFFF8FB, 0xF7C6D8, 0xF3B6CC, 0xFADCE7, 0xEBA5C0], .blueten),
        eintrag("sunset", "Sunset", [0xC9421F, 0xB3306A, 0x6B2C8F], hell: 0xFDF0EA, dunkel: 0x342720,
                ersatz: [0xFFC48A, 0xFFAD7E, 0xFF9B8A, 0xFF8A6E, 0xF0708C, 0xD85D9C, 0x9E4CAE, 0x7A3FA3, 0x4B2F85]),
        eintrag("ocean", "Ocean", [0x0B7A99, 0x0A5F8A, 0x1D3F8F], hell: 0xEBF5F8, dunkel: 0x1F2C33,
                ersatz: [0xC8F0F4, 0x9EE0EA, 0xB4E6F3, 0x5DBDD3, 0x7ACDDD, 0x3A9CC0, 0x1E77A0, 0x176287, 0x0E466E]),
        eintrag("film-grain", "Film Grain", [0x8C5A3C, 0x6B422B, 0x4A2C1C], hell: 0xF3EEE6, dunkel: 0x2D2925,
                ersatz: [0xE9DDC9, 0xDDCBAE, 0xF0E6D4, 0xCDB794, 0xDFCFB4, 0xBBA17C, 0xA98E6B, 0xC1AA88, 0x927A5C]),
        eintrag("paris", "Paris", [0xB03F69, 0x7D3F7E, 0x3E4C8C], hell: 0xF6EFF3, dunkel: 0x2B2731,
                ersatz: [0xF4DCE4, 0xE8D6E8, 0xDADFED, 0xEDC7D5, 0xDCCBE1, 0xC1CCE3, 0xCBABBF, 0xADABCA, 0x919EC1]),
        eintrag("herbst", "Herbst", [0xB3441C, 0x923519, 0x6E2A14], hell: 0xFBF0E6, dunkel: 0x33281F,
                ersatz: [0xF7D8A3, 0xEEB26A, 0xF3C888, 0xDD8844, 0xCD7236, 0xE3A15A, 0xAD5630, 0x924426, 0xBD6A35], .blaetter),
        eintrag("schnee", "Schnee", [0x3A6CAB, 0x2D568F, 0x223F6E], hell: 0xEEF3F9, dunkel: 0x232A33,
                ersatz: [0xEEF4FA, 0xE1EAF4, 0xF5F8FC, 0xC4D4E6, 0xD4E0EE, 0xB4C7DE, 0x94ABC9, 0xA7BBD5, 0x8199BC], .schnee),
    ]

    /// Calm, follows light and dark mode: the chat before anyone picked, and the bubbles over an own picture.
    static let neutral = Backdrop(
        id: "neutral", name: "Neutral",
        verlauf: [fest(0xDC2A55), fest(0xB81D52)], eigeneText: fest(0xFFFFFF),
        partnerBlase: adaptiv(0xE9E9EB, 0x2A2A2D), partnerText: adaptiv(textHell, textDunkel),
        ersatz: zip(
            [0xF6F6F8, 0xF1F0F4, 0xF7F5F6, 0xEEEEF2, 0xF5F5F8, 0xF0EEF2, 0xEBEAEF, 0xF2F1F5, 0xEDECF1] as [UInt32],
            [0x101012, 0x131215, 0x0F0F11, 0x151418, 0x0C0C0E, 0x141317, 0x121115, 0x17161A, 0x0E0E10] as [UInt32]
        ).map { adaptiv($0, $1) },
        animation: .keine
    )

    static func von(_ id: String) -> Backdrop? { alle.first { $0.id == id } }

    static var wahl: BackdropWahl? { lesen(EinstellungenModell.shared.geteilt("chat.backdrop")) }

    static var aktuell: Backdrop { backdrop(fuer: wahl) }

    static func waehlen(_ wahl: BackdropWahl) {
        EinstellungenModell.shared.setzen("chat.backdrop", json(wahl))
    }

    /// Unknown template ids (e.g. from a newer build) and own pictures fall back to `neutral`.
    static func backdrop(fuer wahl: BackdropWahl?) -> Backdrop {
        guard case .vorlage(let id)? = wahl else { return neutral }
        return von(id) ?? neutral
    }

    /// `{"id"}` · `{"art":"foto","medienId"}` · `{"art":"zeichnung","id"}`; anything else is no choice.
    static func lesen(_ wert: JSONValue?) -> BackdropWahl? {
        guard case .object(let o)? = wert else { return nil }
        func text(_ schluessel: String) -> String? {
            guard case .string(let s)? = o[schluessel] else { return nil }
            return s
        }
        switch (text("art"), text("id"), text("medienId")) {
        case ("foto"?, _, let medienId?): return .foto(medienId)
        case ("zeichnung"?, let id?, _): return .zeichnung(id)
        case (nil, let id?, _): return .vorlage(id)
        default: return nil
        }
    }

    static func json(_ wahl: BackdropWahl) -> JSONValue {
        switch wahl {
        case .vorlage(let id): .object(["id": .string(id)])
        case .foto(let medienId): .object(["art": .string("foto"), "medienId": .string(medienId)])
        case .zeichnung(let id): .object(["art": .string("zeichnung"), "id": .string(id)])
        }
    }

    // MARK: - Palette helpers (hex 0xRRGGBB)

    private static let textHell: UInt32 = 0x1C1B1F
    private static let textDunkel: UInt32 = 0xF5F3F7

    private static func eintrag(
        _ id: String, _ name: String, _ verlauf: [UInt32], text: UInt32 = 0xFFFFFF,
        hell: UInt32, dunkel: UInt32, ersatz: [UInt32], _ animation: BackdropAnimation = .keine
    ) -> Backdrop {
        Backdrop(
            id: id, name: name, verlauf: verlauf.map { fest($0) }, eigeneText: fest(text),
            partnerBlase: adaptiv(hell, dunkel), partnerText: adaptiv(textHell, textDunkel),
            ersatz: ersatz.map { fest($0) }, animation: animation
        )
    }

    private static func fest(_ hex: UInt32) -> Color { Color(uiColor: backdropUIFarbe(hex)) }

    private static func adaptiv(_ hell: UInt32, _ dunkel: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? backdropUIFarbe(dunkel) : backdropUIFarbe(hell) })
    }
}

/// 0xRRGGBB → sRGB. A free function, so the dynamic-color closure above captures only integers.
private func backdropUIFarbe(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: 1
    )
}
