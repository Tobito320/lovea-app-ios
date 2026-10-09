import SwiftUI

/// p59: the five bouquets Ahmed photographed, drawn by hand in vector (one file each). The raw
/// value is what gets saved, so the cases only ever grow.
enum StraussArt: String, CaseIterable, Codable, Sendable, Identifiable {
    case lila, rotBunt, rosaGerbera, pinkCreme, glitzerRot

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lila: "Lila Rosen"
        case .rotBunt: "Rot und bunt"
        case .rosaGerbera: "Rosa mit Gerbera"
        case .pinkCreme: "Pink und Creme"
        case .glitzerRot: "Glitzer-Rosen"
        }
    }

    /// The design box every bouquet is drawn in; the stems end at its bottom edge.
    static let breite: CGFloat = 200
    static let hoehe: CGFloat = 240
}

/// Draws `art` into `rect`, centred, stems on the bottom edge. Static: nothing here animates or
/// reads the clock. Below about 64 pt the fine specks are left out (`fein`).
func zeichneStrauss(_ g: GraphicsContext, art: StraussArt, in rect: CGRect) {
    let s = min(rect.width / StraussArt.breite, rect.height / StraussArt.hoehe)
    guard s > 0 else { return }
    var h = g
    h.translateBy(x: rect.midX - StraussArt.breite * s / 2, y: rect.maxY - StraussArt.hoehe * s)
    h.scaleBy(x: s, y: s)
    let fein = StraussArt.breite * s >= 64
    switch art {
    case .lila: StraussLila.zeichne(h, fein: fein)
    case .rotBunt: StraussRotBunt.zeichne(h, fein: fein)
    case .rosaGerbera: StraussRosaGerbera.zeichne(h, fein: fein)
    case .pinkCreme: StraussPinkCreme.zeichne(h, fein: fein)
    case .glitzerRot: StraussGlitzerRot.zeichne(h, fein: fein)
    }
}

/// One bouquet as a view, `breite` pt wide (for the picker sheet and previews).
struct StraussBild: View {
    let art: StraussArt
    var breite: CGFloat = 120

    var body: some View {
        Canvas { g, size in zeichneStrauss(g, art: art, in: CGRect(origin: .zero, size: size)) }
            .frame(width: breite, height: breite * StraussArt.hoehe / StraussArt.breite)
            .accessibilityLabel(art.name)
    }
}
