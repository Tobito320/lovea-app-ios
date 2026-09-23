import Foundation

/// A free piece from Ahmed's and Annika's photos: drawn with an existing shape (`basis`) in a fixed color.
struct FotoTeil: Sendable {
    let basis: Int
    let farbe: FigurFarbe
}

/// Keys are the indices appended at the end of `oberteile`/`hosen`/`schuhArten`.
/// ponytail: fixed colors, the color swatch is ignored for these; own shapes when the basis looks too plain.
extension FigurAussehen {
    static let fotoOberteile: [Int: FotoTeil] = [
        27: FotoTeil(basis: 3, farbe: FigurFarbe(0xF2F2F0)),  // Weißes Kompressions-Longsleeve (Pulli-Form)
        28: FotoTeil(basis: 0, farbe: FigurFarbe(0x161617)),  // Schwarzes Kompressions-Tee
        29: FotoTeil(basis: 0, farbe: FigurFarbe(0x1F4D36)),  // Waldgrünes Oversize-Tee
        30: FotoTeil(basis: 6, farbe: FigurFarbe(0xF4F2EE)),  // Weißes Rippen-Tank (Trägertop-Form)
    ]
    static let fotoHosen: [Int: FotoTeil] = [
        16: FotoTeil(basis: 6, farbe: FigurFarbe(0x151515)),  // Schwarze Gym-Shorts
        17: FotoTeil(basis: 4, farbe: FigurFarbe(0xC9C9C7)),  // Hellgraue Wide-Jogger
        18: FotoTeil(basis: 2, farbe: FigurFarbe(0xBEBFC0)),  // Hellgraue Baggy-Jeans
    ]
    static let fotoSchuhe: [Int: FotoTeil] = [
        15: FotoTeil(basis: 0, farbe: FigurFarbe(0xF4F4F2)),  // Weiße Low-Top-Sneaker
    ]
}
