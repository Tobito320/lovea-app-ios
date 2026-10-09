import SwiftUI

/// p66: ein Satz Abstände und Radien für alle Karten und Zeilen (4-pt-Raster). Neue Oberflächen
/// nehmen diese Werte statt eigener Zahlen; alte ziehen bei Gelegenheit nach.
enum Abstand {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

enum Rundung {
    static let klein: CGFloat = 10
    static let karte: CGFloat = 16
}

extension Shape where Self == RoundedRectangle {
    /// Die eine Kartenform der App: `.background(farbe, in: .loveaKarte)`, `.contentShape(.loveaKarte)`.
    static var loveaKarte: RoundedRectangle { RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous) }
}
