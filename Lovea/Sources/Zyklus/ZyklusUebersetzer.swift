import Foundation

/// Übersetzt Annikas Phase und ihren Eintrag von heute in kurze Hinweise für Ahmed:
/// was sie sich heute wünscht und was er konkret tun kann. Keine Diagnose, nur Ideen.
enum ZyklusUebersetzer {
    struct Botschaft: Equatable {
        let wunsch: String
        let satz: String
        let tipps: [String]
        let symbol: String
    }

    static func fuer(phase: Phase?, tag: ZyklusTag?) -> Botschaft? {
        guard let phase else { return nil }
        let basis = basis(phase)
        let extra = hinweise(tag)
        // Die Stimmung von heute wiegt mehr als die Phase: sie kommt zuerst.
        var tipps: [String] = []
        for t in extra.tipps + basis.tipps where !tipps.contains(t) { tipps.append(t) }
        return Botschaft(wunsch: extra.wunsch ?? basis.wunsch,
                         satz: extra.satz ?? basis.satz,
                         tipps: Array(tipps.prefix(3)),
                         symbol: basis.symbol)
    }

    private static func basis(_ phase: Phase) -> Botschaft {
        switch phase {
        case .periode:
            Botschaft(wunsch: "Wärme und Fürsorge",
                      satz: "Ihr Körper arbeitet heute hart. Sie braucht keinen Plan, sondern dich.",
                      tipps: ["Frag, ob du ihr etwas Warmes oder Süßes bringen kannst",
                              "Schreib ihr zwischendurch, dass du an sie denkst",
                              "Kein Druck, keine großen Diskussionen"],
                      symbol: "heart.circle.fill")
        case .follikel:
            Botschaft(wunsch: "Zeit zu zweit und Neues",
                      satz: "Ihre Energie kommt zurück. Gute Tage für Pläne und Abenteuer.",
                      tipps: ["Plan ein kleines Date oder etwas Neues zusammen",
                              "Lach mit ihr, schick ihr was Lustiges",
                              "Erzähl ihr von deinem Tag, sie will dabei sein"],
                      symbol: "sparkles")
        case .fruchtbar, .eisprung:
            Botschaft(wunsch: "Aufmerksamkeit und Komplimente",
                      satz: "Sie fühlt sich heute oft strahlend. Zeig ihr, dass du es siehst.",
                      tipps: ["Sag ihr, wie schön sie ist, ganz konkret",
                              "Flirte mit ihr wie am Anfang",
                              "Ruf an statt nur zu schreiben"],
                      symbol: "flame.fill")
        case .luteal:
            Botschaft(wunsch: "Geduld und liebe Worte",
                      satz: "Gefühle sind jetzt näher an der Oberfläche. Kleine Worte wiegen doppelt.",
                      tipps: ["Sag ihr, dass du sie liebst und bleibst",
                              "Nimm Gereiztheit nicht persönlich",
                              "Ein Snack oder Schokolade wirkt Wunder"],
                      symbol: "bubble.left.and.text.bubble.right.fill")
        }
    }

    private static func hinweise(_ tag: ZyklusTag?) -> (wunsch: String?, satz: String?, tipps: [String]) {
        guard let tag else { return (nil, nil, []) }
        var wunsch: String?
        var satz: String?
        var tipps: [String] = []
        if !tag.stimmung.isDisjoint(with: [.traurig, .aengstlich]) {
            wunsch = "Sicherheit und Nähe"
            satz = "Sie fühlt sich heute verletzlich. Sie muss hören, dass du da bist."
            tipps.append("Sag ihr klar: Ich bin da und ich bleibe")
        }
        if tag.stimmung.contains(.gereizt) {
            wunsch = wunsch ?? "Geduld"
            tipps.append("Hör zu, statt zu erklären")
        }
        if tag.stimmung.contains(.gestresst) {
            wunsch = wunsch ?? "Entlastung"
            tipps.append("Frag, was du ihr heute abnehmen kannst")
        }
        if tag.stimmung.contains(.empfindlich) {
            tipps.append("Sei heute besonders sanft mit Worten")
        }
        if !tag.symptome.isDisjoint(with: [.kraempfe, .rueckenschmerzen, .kopfschmerzen]) {
            tipps.append("Sie hat Schmerzen: Wärmflasche, Tee, Ruhe")
        }
        if tag.symptome.contains(.muedigkeit) {
            tipps.append("Sie ist müde: lass den Abend ruhig sein")
        }
        if tag.symptome.contains(.heisshunger) {
            tipps.append("Überrasch sie mit ihrem Lieblingssnack")
        }
        return (wunsch, satz, tipps)
    }
}
