import Foundation

enum Wochenplan {
    /// Die Blöcke eines Tages für eine Person: Muster (nach Wechselwoche, Ferien und Feiertagen
    /// gefiltert), Ausnahmen darauf angewandt, dazu Termine und Treffen des Tages. `feiertage`:
    /// vorberechnete NRW-Feiertage des Jahres (Monatsraster), sonst hier berechnet.
    static func tag(_ tag: String, person: String, daten: KalenderDaten, feiertage: Set<String>? = nil) -> [Block] {
        let jahr = Int(tag.prefix(4)) ?? 0
        let istFeiertag = (feiertage ?? Feiertage.nrw(jahr: jahr)).contains(tag)
        let istFerien = Ferien.istFerien(tag)
        let wochentag = Datum.wochentag(tag)
        let woche = Datum.wechselwoche(tag)

        var eintraege = daten.muster
            .filter {
                $0.person == person
                    && $0.wochentage.contains(wochentag)
                    && $0.ab <= tag
                    && ($0.wochen == "alle" || $0.wochen == woche)
            }
            .map { muster in
                (muster: muster, block: Block(titel: muster.titel, typ: muster.typ, start: muster.start, ende: muster.ende, status: "normal", quelle: "muster", musterId: muster.id))
            }

        if istFeiertag {
            eintraege.removeAll { $0.block.typ == "schule" || $0.block.typ == "arbeit" }
        } else if istFerien {
            eintraege.removeAll { $0.block.typ == "schule" }
        }

        for ausnahme in daten.ausnahmen where ausnahme.person == person {
            let giltHeute = ausnahme.bisDatum.map { ausnahme.datum <= tag && tag <= $0 } ?? (ausnahme.datum == tag)
            guard giltHeute else { continue }
            for i in eintraege.indices {
                if let musterId = ausnahme.musterId, eintraege[i].muster.id != musterId { continue }
                eintraege[i].block.status = ausnahme.status
                eintraege[i].block.ausnahme = ausnahme
                if let start = ausnahme.start { eintraege[i].block.start = start }
                if let ende = ausnahme.ende { eintraege[i].block.ende = ende }
            }
        }

        var bloecke = eintraege.map { $0.block }

        for termin in daten.termine where termin.datum == tag && termin.fuer.contains(person) {
            bloecke.append(Block(titel: termin.titel, typ: termin.typ, start: termin.start, ende: termin.ende, status: "normal", quelle: "termin", terminId: termin.id))
        }

        for treffen in daten.treffen where treffen.datum == tag {
            bloecke.append(Block(titel: treffen.wasMachenWir ?? "Treffen", typ: "treffen", start: treffen.uhrzeit, ende: nil, status: "normal", quelle: "treffen"))
        }

        return bloecke
    }
}
