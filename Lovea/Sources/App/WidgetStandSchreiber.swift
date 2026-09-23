import Foundation
import Observation
import SwiftUI
import UIKit
import WidgetKit

/// Schreibt `WidgetStand` (Z-28.2) nach jeder relevanten Änderung in die App Group, gedrosselt auf
/// höchstens einen Schreibvorgang pro 15 s, und ruft danach `WidgetCenter.reloadAllTimelines()`.
/// Beobachtet über `withObservationTracking` statt eigener `Raum.beobachten`-Registrierungen — so
/// müssen `HealthModell`/`PunkteModell`/`FigurenModell`/... (E/F/G-Territorium) nicht angefasst
/// werden, jeder gelesene `@Observable`-Zugriff in `baueStand()`/`beobachten()` meldet sich hier
/// von selbst.
@MainActor
final class WidgetStandSchreiber {
    static let shared = WidgetStandSchreiber()

    private var wartetAufSchreiben = false
    private var letzterSchreibZeitpunkt = Date.distantPast
    private var letzteDaten: Data?
    private var letzteFigurZustand: FigurenModell.Zustand?
    private var letzteFigurAussehen: Data?
    private var letzteFotoQuelle: String?

    private init() {}

    /// Von `LoveaApp.starten`, NACH `Raum.shared.start()`. Wartet auf die erste vollständige
    /// Faltung, sonst würde eine leere Replay-Faltung einen guten alten Stand überschreiben, dann
    /// sofort ein erster Schreibversuch — ohne den bliebe ein Offline-Start ganz ohne Stand, bis
    /// die nächste Änderung eintrifft.
    func start() {
        Task { @MainActor [weak self] in
            await Raum.shared.leer()
            self?.aenderungBehandeln()
        }
    }

    /// Nur zum Registrieren der Beobachtung (kein Schreibversuch) — `aenderungBehandeln` ruft das
    /// selbst zuerst auf, jeder Folge-Aufruf kommt über `onChange`.
    private func beobachten() {
        withObservationTracking {
            _ = baueStand()
            let partner = Raum.shared.ich?.partner
            _ = partner.map { FigurenModell.shared.anzeige($0) }
            _ = partner.map { FigurenModell.shared.aussehen($0) }
            _ = partner.map { letztesFotoDesPartners($0) }
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.aenderungBehandeln() }
        }
    }

    private func aenderungBehandeln() {
        beobachten() // sofort neu registrieren, sonst verpasst die nächste Änderung die Beobachtung
        guard !wartetAufSchreiben else { return }
        wartetAufSchreiben = true
        let wartezeit = WidgetThrottle.wartezeit(zuletzt: letzterSchreibZeitpunkt, jetzt: Date(), minAbstand: 15)
        Task { @MainActor [weak self] in
            if wartezeit > 0 { try? await Task.sleep(for: .seconds(wartezeit)) }
            self?.wartetAufSchreiben = false
            await self?.schreibenFallsGeaendert()
        }
    }

    /// Reihenfolge ist wichtig: Figur/Foto zuerst auf die Platte, DANACH `baueStand()` — der liest
    /// `partnerFigurVorhanden`/`partnerFotoVorhanden` per Datei-Check, ein Stand vor dem Schreiben
    /// der Bilder würde also immer `false` melden. Neu laden bei geänderter JSON ODER geändertem Bild
    /// (ein neues Partnerfoto ändert den Stand selbst nicht, nur die Datei daneben).
    private func schreibenFallsGeaendert() async {
        guard let ich = Raum.shared.ich else { return }
        let bildGeaendert = await figurUndFotoAktualisieren(partner: ich.partner)

        let stand = baueStand()
        guard let daten = try? JSONEncoder().encode(stand) else { return }
        let standGeaendert = daten != letzteDaten
        guard standGeaendert || bildGeaendert else { return }

        letzteDaten = daten
        letzterSchreibZeitpunkt = Date()
        if let url = WidgetGruppe.standURL() { try? daten.write(to: url, options: .atomic) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Stand bauen

    private func baueStand() -> WidgetStand {
        guard let ich = Raum.shared.ich else { return WidgetStand(eigenePerson: Person.ahmed.rawValue) }
        var stand = WidgetStand(eigenePerson: ich.rawValue)
        healthEintragen(&stand)
        challengeEintragen(&stand)
        treffenEintragen(&stand)
        partnerEintragen(&stand, partner: ich.partner)
        stand.frageDesTages = FrageDesTages.waehlen(vorrat: FrageDesTages.vorrat, tag: Datum.text(Date()))?.text
        return stand
    }

    /// Montag bis Sonntag, wie `zielGym`/`ChallengeLogik` (Zielplan Review-Fokus 1) — nicht die
    /// letzten 7 Tage bis heute, sonst würde ein Montag Freitag/Samstag der Vorwoche mitzählen und
    /// gegen dasselbe Wochenziel wie der Health-Tab ein anderes Ergebnis zeigen.
    private func healthEintragen(_ stand: inout WidgetStand) {
        let health = HealthModell.shared
        let heute = Datum.text(Date())
        let montag = Datum.montagDerWoche(heute)
        // `verfuegbar` (Kontostand nach Käufen), nicht `stand` (Lebenszeit-verdient) — sonst zeigt
        // das Widget nach dem ersten Kauf eine andere Zahl als die Punktestand-Kapsel in der App.
        let verfuegbar = PunkteModell.shared.einkaufsStand(preis: { ShopKatalog.artikel($0)?.preis }).verfuegbar
        for person in Person.allCases {
            stand.schritteHeute[person.rawValue] = health.heuteSchritte(person)
            stand.zielSchritte[person.rawValue] = health.zielSchritte(person)
            stand.zielGymWoche[person.rawValue] = health.zielGym(person)
            stand.gymLetzte7[person.rawValue] = (0..<7).map { versatz in
                let tag = Datum.addTage(montag, versatz)
                return WidgetStand.TagEintrag(datum: tag, erledigt: health.gymAbgehakt(person, tag))
            }
            stand.punkte[person.rawValue] = verfuegbar[person]
        }
    }

    private func challengeEintragen(_ stand: inout WidgetStand) {
        guard let woche = PunkteModell.shared.aktuelleWoche else { return }
        stand.gemeinsamZielWoche = woche.gemeinsamZiel
        stand.gemeinsamSchritteWoche = woche.schritteGesamt
    }

    private func treffenEintragen(_ stand: inout WidgetStand) {
        guard let treffen = KalenderModell.shared.naechstesTreffen else { return }
        stand.naechstesTreffenDatum = treffen.datum
        stand.naechstesTreffenText = treffen.wasMachenWir
    }

    private func partnerEintragen(_ stand: inout WidgetStand, partner: Person) {
        if let position = Standort.shared.positionen[partner] {
            stand.partnerOrtName = OrteModell.shared.aktuellerOrt(partner, lat: position.lat, lon: position.lon)?.name
            if let akku = position.akku { stand.partnerAkku = (akku * 20).rounded() / 20 }
        }
        stand.partnerFigurVorhanden = (WidgetGruppe.partnerFigurURL()).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        stand.partnerFotoVorhanden = (WidgetGruppe.partnerFotoURL()).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        // Brief I.3: `WetterModell` existiert jetzt (Block 27) — Temperaturtext plus SF-Symbol-Name
        // fürs Widget-Icon (Spec 9 "kleines Wetter-Symbol").
        if let wetter = WetterModell.shared.partner {
            stand.partnerWetter = "\(Int(wetter.temperatur.rounded()))°"
            stand.partnerWetterSymbol = wetter.symbol
        }
    }

    // MARK: - Partner-Figur und -Foto

    private func figurUndFotoAktualisieren(partner: Person) async -> Bool {
        let figur = await figurAktualisieren(partner)
        let foto = await fotoAktualisieren(partner)
        return figur || foto
    }

    @discardableResult
    private func figurAktualisieren(_ partner: Person) async -> Bool {
        let aussehen = FigurenModell.shared.aussehen(partner)
        let zustand = FigurenModell.shared.anzeige(partner)
        let aussehenDaten = try? JSONEncoder().encode(aussehen)
        guard zustand != letzteFigurZustand || aussehenDaten != letzteFigurAussehen else { return false }
        letzteFigurZustand = zustand
        letzteFigurAussehen = aussehenDaten
        guard let url = WidgetGruppe.partnerFigurURL() else { return false }
        let ansicht = FigurView(aussehen, zustand: zustand.haupt, abzeichen: zustand.abzeichen, groesse: 160, animiert: false, ganzkoerper: true)
        let renderer = ImageRenderer(content: ansicht)
        renderer.scale = 2
        guard let bild = renderer.uiImage else { return false }
        guard let daten = await Task.detached(priority: .utility, operation: { bild.pngData() }).value else { return false }
        try? daten.write(to: url, options: .atomic)
        return true
    }

    @discardableResult
    private func fotoAktualisieren(_ partner: Person) async -> Bool {
        guard let url = WidgetGruppe.partnerFotoURL() else { return false }
        guard let quelle = letztesFotoDesPartners(partner) else {
            guard letzteFotoQuelle != nil else { return false }
            try? FileManager.default.removeItem(at: url)
            letzteFotoQuelle = nil
            return true
        }
        guard quelle.lastPathComponent != letzteFotoQuelle else { return false }
        letzteFotoQuelle = quelle.lastPathComponent
        return await Task.detached(priority: .utility) {
            guard let miniatur = WidgetBildSkalierung.miniatur(von: quelle, langeKante: 640) else { return false }
            try? miniatur.write(to: url, options: .atomic)
            return true
        }.value
    }

    /// Letztes Foto ODER als Foto geteilte Zeichnung des Partners (`typ == "foto"` für beides,
    /// siehe `Drawing/Teilen/StandPaket.swift`) — nie ein Snap (`snap != nil`, Einmal-Ansicht darf
    /// nie in einem Widget landen), nur bereits lokal zwischengespeicherte Medien. `Medien.lokal`
    /// ist ein reiner Datei-Check: ein Foto, das erst NACH diesem Aufruf fertig herunterlädt, taucht
    /// erst beim nächsten beobachteten Zustandswechsel auf (Grenze, siehe Bericht).
    private func letztesFotoDesPartners(_ partner: Person) -> URL? {
        for nachricht in ChatModell.shared.nachrichten.reversed() {
            // Minor 5: nie ein gelöschtes Foto ins Widget.
            guard nachricht.von == partner, nachricht.snap == nil, !nachricht.geloescht else { continue }
            guard let medium = nachricht.medien.first(where: { $0.typ == "foto" }) else { continue }
            if let lokal = Medien.lokal(medium.id) { return lokal }
        }
        return nil
    }
}
