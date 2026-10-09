import Foundation

/// Ops `zyklus.tag` und `zyklus.einstellung`. Nur Annika schreibt (Absender muss Annika sein).
/// Ahmeds Gerät wendet sie an, um Annikas Zyklus nur anzusehen; er sendet nie eine.
enum ZyklusOps {
    static let tagArt = "zyklus.tag"
    static let einstellungArt = "zyklus.einstellung"
    static let arten: Set<String> = [tagArt, einstellungArt]

    static func istZyklus(_ art: String) -> Bool { art.hasPrefix("zyklus.") }

    /// `tag == nil` löscht den Tag.
    struct TagD: Codable, Equatable {
        var id: String
        var tag: ZyklusTag?
    }

    struct EinstellungD: Codable, Equatable {
        var einstellung: ZyklusEinstellung
    }

    static func tagOp(_ tag: ZyklusTag, von: Person) -> Op {
        Op.neu(tagArt, TagD(id: tag.id, tag: tag.istLeer ? nil : tag), von: von)
    }

    static func einstellungOp(_ e: ZyklusEinstellung, von: Person) -> Op {
        Op.neu(einstellungArt, EinstellungD(einstellung: e), von: von)
    }
}

/// Stand des Zyklus-Tagebuchs, wird als Ganzes auf Platte gelegt. Last-writer-wins je Tag:
/// die Op mit der neueren `zeit` gewinnt, bei gleicher Zeit die mit der größeren `id`.
struct ZyklusStand: Codable, Equatable {
    struct Stempel: Codable, Equatable, Comparable {
        var zeit: Date
        var id: String
        static func < (a: Stempel, b: Stempel) -> Bool {
            a.zeit != b.zeit ? a.zeit < b.zeit : a.id < b.id
        }
    }

    var tage: [String: ZyklusTag] = [:]
    /// Auch für gelöschte Tage, sonst käme eine alte Op nach dem Löschen wieder durch.
    var stempel: [String: Stempel] = [:]
    var einstellung = ZyklusEinstellung()
    var einstellungStempel: Stempel?

    /// `ich` ist die Person dieses Geräts (Annika oder Ahmed zum Ansehen). Angewendet werden nur Ops von Annika.
    /// Gibt zurück, ob sich etwas geändert hat.
    @discardableResult
    mutating func anwenden(_ op: Op, ich: Person?) -> Bool {
        guard ich != nil, op.von == .annika, ZyklusOps.istZyklus(op.art) else { return false }
        let s = Stempel(zeit: op.zeit, id: op.id)
        switch op.art {
        case ZyklusOps.tagArt:
            guard let d = op.daten(ZyklusOps.TagD.self) else { return false }
            if let alt = stempel[d.id], s <= alt { return false }
            stempel[d.id] = s
            if var t = d.tag, !t.istLeer {
                t.id = d.id
                tage[d.id] = t
            } else {
                tage[d.id] = nil
            }
            return true
        case ZyklusOps.einstellungArt:
            guard let d = op.daten(ZyklusOps.EinstellungD.self) else { return false }
            if let alt = einstellungStempel, s <= alt { return false }
            einstellungStempel = s
            einstellung = d.einstellung
            return true
        default:
            return false
        }
    }
}
