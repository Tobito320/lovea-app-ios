import Foundation

/// Everything the living objects show, as plain values: the drawing and the render board both
/// take this, only `ZimmerLebenModell.stand` reads the app's models.
struct ZimmerLebenStand: Equatable {
    var termin: ZimmerTermin?
    var himmel: ZimmerHimmel?
    var andere: ZimmerAndere.Wo = .zuhause
    var polaroids: [ZimmerPolaroid] = []
    var pokale: [ZimmerPokal] = []
    var film: ZimmerFilm?
    var pflanze = ZimmerPflanzenStand(stufe: 0, haengt: false, serie: 0)
    var ziel: ZimmerZiel?
}

@MainActor
enum ZimmerLebenModell {
    /// Shared settings (`EinstellungenModell.geteilt`, newest write wins) holding the film list and the goal as JSON text.
    static let filmeSchluessel = "zimmer.filme"
    static let zielSchluessel = "zimmer.ziel"

    static func lesen<T: Decodable>(_ schluessel: String, als typ: T.Type) -> T? {
        guard case .string(let text)? = EinstellungenModell.shared.geteilt(schluessel) else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(text.utf8))
    }

    static func schreiben<T: Encodable>(_ schluessel: String, _ wert: T) {
        guard let daten = try? JSONEncoder().encode(wert) else { return }
        EinstellungenModell.shared.setzen(schluessel, .string(String(decoding: daten, as: UTF8.self)))
    }

    static func filme() -> [ZimmerFilm] { lesen(filmeSchluessel, als: [ZimmerFilm].self) ?? [] }

    /// Whose sky the window shows (the brief: Annika's city), from `WetterModell` at her position.
    static let wetterPerson = Person.annika

    static func stand(zimmer: Zimmer, person: Person, jetzt: Date = Date()) -> ZimmerLebenStand {
        let heute = Datum.text(jetzt)
        let stunde = Calendar.berlin.component(.hour, from: jetzt)
        return ZimmerLebenStand(
            termin: ZimmerKalenderblatt.naechster(KalenderModell.shared.zustand.daten, heute: heute),
            himmel: WetterModell.shared.staende[wetterPerson].map { ZimmerHimmel(code: $0.code, tag: $0.tag, stunde: stunde) },
            andere: wo(person.partner, heute: heute, stunde: stunde),
            polaroids: ZimmerFotos.letzte(ChatModell.shared.nachrichten),
            pokale: ZimmerPokale.aus(SpieleModell.shared.bilanz),
            film: ZimmerFilme.laeuft(filme()),
            pflanze: pflanze(ich: Raum.shared.ich ?? person, heute: heute),
            ziel: lesen(zielSchluessel, als: ZimmerZiel.self)
        )
    }

    /// Where `p` is right now: the shared place state, else the saved place at their last fix.
    static func wo(_ p: Person, heute: String, stunde: Int) -> ZimmerAndere.Wo {
        let ort: String? = ProfilSzene.geteilterZustand(p) == .gym ? "gym"
            : Standort.shared.positionen[p].flatMap { OrteModell.shared.ortBei(lat: $0.lat, lon: $0.lon)?.kategorie }
        return ZimmerAndere.bestimmen(schlaf: ProfilSzene.schlafGerade(p), ort: ort, gymHeute: HealthModell.shared.gymAbgehakt(p, heute), stunde: stunde)
    }

    /// The habits both share (`fuer == "beide"`: Gym, Wasser and the own ones made for both).
    static func pflanze(ich: Person, heute: String) -> ZimmerPflanzenStand {
        let health = HealthModell.shared
        func serie(_ h: Habit, _ p: Person) -> Int {
            HabitLogik.serie(h, werte: health.habitWerte(h.id, p), ziel: health.habitZiel(h.id, p), heute: heute)
        }
        let geteilt = health.sichtbareHabits(fuer: ich).filter { $0.fuer == "beide" }
        return ZimmerPflanzenStand.aus(geteilt.map { (ahmed: serie($0, .ahmed), annika: serie($0, .annika)) })
    }
}
