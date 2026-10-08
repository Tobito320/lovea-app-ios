import Foundation

extension FigurAussehen {
    /// p69 (50): crash protection for a saved look. The drawing already clamps every index (`grenze`, `wahl`), so a
    /// bad number cannot crash it, but it would silently show the LAST entry of the list, and the editor would
    /// save that wrong number again. `mitGueltigerKleidung` and `mitGueltigemGesicht` repair the clothing and the
    /// face; this one repairs the plain index fields they leave out (skin, hair, eyes, brows, nose, mouth, body,
    /// beard, the color slots, the free watch): a number outside its list becomes the person's default.
    /// Pure, so both phones come to the same picture.
    static func mitGueltigenIndizes(_ a: FigurAussehen, _ p: Person) -> FigurAussehen {
        let basis = standard(for: p)
        var b = a
        let felder: [(WritableKeyPath<FigurAussehen, Int>, Int)] = [
            (\.haut, hautToene.count), (\.frisur, frisuren.count), (\.haarfarbe, haarfarben.count),
            (\.augen, augenfarben.count), (\.bart, baerte.count), (\.augenform, augenformen.count),
            (\.brauen, augenbrauen.count), (\.nase, nasen.count), (\.mund, muender.count),
            (\.koerperform, koerperformen.count), (\.groesse, groessen.count), (\.kinnbart, kinnbaerte.count),
            (\.uhrAlltag, uhrenAlltag.count),
            (\.oberteilfarbe, farben.count), (\.jackenfarbe, farben.count), (\.hosenfarbe, farben.count),
            (\.schuhfarbe, farben.count), (\.muetzenfarbe, farben.count),
        ]
        for (pfad, anzahl) in felder where !(0..<anzahl).contains(a[keyPath: pfad]) {
            b[keyPath: pfad] = basis[keyPath: pfad]
        }
        return b
    }
}
