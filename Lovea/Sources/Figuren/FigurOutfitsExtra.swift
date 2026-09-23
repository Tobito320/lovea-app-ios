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
        32: FotoTeil(basis: 0, farbe: FigurFarbe(0x1E1E20)),  // Schwarzes Rundhals-Tee (Fix round 3)
    ]
    static let fotoHosen: [Int: FotoTeil] = [
        16: FotoTeil(basis: 6, farbe: FigurFarbe(0x151515)),  // Schwarze Gym-Shorts
        17: FotoTeil(basis: 4, farbe: FigurFarbe(0xC9C9C7)),  // Hellgraue Wide-Jogger
        18: FotoTeil(basis: 2, farbe: FigurFarbe(0xBEBFC0)),  // Hellgraue Baggy-Jeans
        19: FotoTeil(basis: 2, farbe: FigurFarbe(0xE9B8C0)),  // Rosa Weite Jeans (Fix round 3)
    ]
    static let fotoSchuhe: [Int: FotoTeil] = [
        15: FotoTeil(basis: 0, farbe: FigurFarbe(0xF4F4F2)),  // Weiße Low-Top-Sneaker
    ]
}

/// Fix round 3: a one-tap outfit. It only sets the clothes (top, jacket, pants, shoes and their free
/// colors); face and hair stay. Saved inside the normal synced `figur.aussehen`, no new op.
struct FigurOutfit: Sendable, Identifiable {
    let name: String
    let geschlecht: FigurGeschlecht
    let oberteil: Int
    var oberteilHex: String?
    var jacke = 0
    var jackeHex: String?
    let hose: Int
    var hoseHex: String?
    let schuhe: Int
    var schuhHex: String?

    var id: String { name }
}

extension FigurAussehen {
    /// Ahmed's outfits come from his photos and lean pink and black; "Oben ohne Gym" is the bare
    /// gym torso. Photo pieces (`fotoOberteile`/`fotoHosen`/`fotoSchuhe`) bring their own color.
    static let outfits: [FigurOutfit] = [
        FigurOutfit(name: "Pink Knit", geschlecht: .m, oberteil: 31, oberteilHex: "F2A9BA", hose: 19, schuhe: 15),
        FigurOutfit(name: "All Black", geschlecht: .m, oberteil: 32, hose: 2, hoseHex: "1F1F22", schuhe: 10, schuhHex: "F4F1EE"),
        FigurOutfit(name: "Pink & Black", geschlecht: .m, oberteil: 31, oberteilHex: "F2A9BA", hose: 2, hoseHex: "1F1F22", schuhe: 10, schuhHex: "F4F1EE"),
        FigurOutfit(name: "Gym Black", geschlecht: .m, oberteil: 28, hose: 16, schuhe: 2, schuhHex: "F4F1EE"),
        FigurOutfit(name: "Oben ohne Gym", geschlecht: .m, oberteil: 33, hose: 16, schuhe: 2, schuhHex: "F4F1EE"),
        FigurOutfit(name: "Grey Denim", geschlecht: .m, oberteil: 32, hose: 18, schuhe: 15),
        FigurOutfit(name: "Brasilien", geschlecht: .m, oberteil: 20, oberteilHex: "F5CE5A", hose: 2, hoseHex: "8E8C93", schuhe: 10, schuhHex: "F4F1EE"),
        FigurOutfit(name: "Date Look", geschlecht: .w, oberteil: 4, oberteilHex: "F7B6C8", jacke: 1, jackeHex: "2B2830", hose: 1, schuhe: 1, schuhHex: "2B2830"),
        FigurOutfit(name: "Gym Girl", geschlecht: .w, oberteil: 30, hose: 9, hoseHex: "2B2830", schuhe: 2, schuhHex: "F4F1EE"),
    ]

    static func outfits(fuer person: Person) -> [FigurOutfit] {
        outfits.filter { $0.geschlecht == .n || $0.geschlecht == person.figurGeschlecht }
    }

    mutating func anziehen(outfit o: FigurOutfit) {
        oberteil = o.oberteil
        oberteilfarbeHex = o.oberteilHex
        jacke = o.jacke
        jackenfarbeHex = o.jackeHex
        hose = o.hose
        hosenfarbeHex = o.hoseHex
        schuhe = o.schuhe
        schuhfarbeHex = o.schuhHex
    }

    /// The editor marks the preset that is worn right now.
    func traegt(outfit o: FigurOutfit) -> Bool {
        oberteil == o.oberteil && oberteilfarbeHex == o.oberteilHex && jacke == o.jacke && jackenfarbeHex == o.jackeHex
            && hose == o.hose && hosenfarbeHex == o.hoseHex && schuhe == o.schuhe && schuhfarbeHex == o.schuhHex
    }
}
