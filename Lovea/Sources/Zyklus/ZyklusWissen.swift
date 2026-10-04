import Foundation

/// Kurze eigene Tipps je Phase. Keine Heilversprechen, nur sanfte Ideen.
enum ZyklusWissen {
    struct Karte: Equatable {
        let titel: String
        let kurz: String
        let ernaehrung: String
        let sport: String
        let schlaf: String
        let stimmung: String
    }

    static func karte(fuer phase: Phase) -> Karte {
        switch phase {
        case .periode:
            Karte(titel: "Periode",
                  kurz: "Dein Körper darf jetzt langsam machen.",
                  ernaehrung: "Warme Suppe, Linsen und Spinat tun gut. Trink viel Tee.",
                  sport: "Spazieren, Dehnen oder sanftes Yoga. Du musst nichts leisten.",
                  schlaf: "Gönn dir etwas mehr Schlaf. Eine Wärmflasche hilft beim Einschlafen.",
                  stimmung: "Du bist vielleicht empfindlicher. Das ist völlig in Ordnung.")
        case .follikel:
            Karte(titel: "Follikelphase",
                  kurz: "Die Energie kommt zurück.",
                  ernaehrung: "Frisches Obst, Gemüse und Eiweiß geben dir Schwung.",
                  sport: "Gute Zeit für Neues und für Kraft. Probier etwas aus.",
                  schlaf: "Du schläfst oft leichter ein. Bleib bei deiner Zeit.",
                  stimmung: "Viele fühlen sich jetzt leicht und mutig.")
        case .fruchtbar:
            Karte(titel: "Fruchtbare Tage",
                  kurz: "Dein Körper ist auf Hochtouren.",
                  ernaehrung: "Bunte Teller, Nüsse und viel Wasser.",
                  sport: "Intervalle, Tanzen oder eine Runde Laufen passen gut.",
                  schlaf: "Die Nächte können unruhiger sein. Lüfte vor dem Schlafen.",
                  stimmung: "Du bist oft offen und gesprächig.")
        case .eisprung:
            Karte(titel: "Eisprung",
                  kurz: "Der Höhepunkt des Zyklus.",
                  ernaehrung: "Leichte Kost mit Gemüse. Trink genug.",
                  sport: "Du darfst richtig loslegen. Wärm dich gut auf.",
                  schlaf: "Die Temperatur steigt danach ein wenig. Ein kühles Zimmer hilft.",
                  stimmung: "Viele fühlen sich jetzt strahlend. Genieß es.")
        case .luteal:
            Karte(titel: "Lutealphase",
                  kurz: "Es wird ruhiger und gemütlicher.",
                  ernaehrung: "Vollkorn, Banane und etwas Schokolade gegen Heißhunger.",
                  sport: "Pilates, Schwimmen oder lange Spaziergänge.",
                  schlaf: "Plane früher Feierabend ein. Dein Körper braucht mehr Ruhe.",
                  stimmung: "Gereizt oder wehmütig? Das gehört oft dazu. Sei lieb zu dir.")
        }
    }
}
