import Foundation
import Observation

/// Stand des Paar-Alltags (Plattenspieler, Wecker, Spiegel, Kühlschrank, Wärme). Gespeichert wird im
/// Op-Log wie bei den Signalen, `Raum.beobachtenStapel` spielt beim ersten Zugriff alles ein.
/// Nichts läuft von allein und nichts wird beim Start geladen.
@MainActor @Observable
final class AlltagSpeicher {
    static let shared = AlltagSpeicher()

    private(set) var stand = AlltagStand()

    @ObservationIgnored private let wer: () -> Person?
    @ObservationIgnored private let senden: (Op) -> Void

    init(ich: @escaping () -> Person?, senden: @escaping (Op) -> Void) {
        self.wer = ich
        self.senden = senden
    }

    private convenience init() {
        self.init(ich: { Raum.shared.ich }, senden: { Raum.shared.einreihen($0) })
        Raum.shared.beobachtenStapel(AlltagLogik.arten) { [weak self] ops in self?.einarbeiten(ops) }
    }

    func einarbeiten(_ ops: [Op]) { stand = AlltagLogik.anwenden(ops, auf: stand) }

    var ich: Person? { wer() }

    // MARK: Plattenspieler

    func platteSetzen(_ t: SpotifyAbfrage.Titel) {
        guard let ich = wer() else { return }
        absenden(Op.neu(AlltagLogik.artPlatte, AlltagLogik.PlatteD(id: t.id, titel: t.titel, kuenstler: t.kuenstler, cover: t.cover), von: ich))
    }

    // MARK: Wecker

    func weckerSetzen(minuten: Int?, an: Bool) {
        guard let ich = wer() else { return }
        absenden(Op.neu(AlltagLogik.artWecker, AlltagLogik.WeckerD(min: minuten, an: an), von: ich))
    }

    // MARK: Spiegel

    /// Hängt mein Outfit für heute an den Spiegel der anderen Person; `nil` nimmt es wieder ab.
    func outfitHaengen(medium: String?, heute: String = Datum.text(Date())) {
        guard let ich = wer() else { return }
        absenden(Op.neu(AlltagLogik.artSpiegel, AlltagLogik.SpiegelD(medium: medium, tag: heute), von: ich))
    }

    // MARK: Kühlschrank (beide sehen alles, beide dürfen abhaken und wegnehmen)

    var zettel: [KuehlZettel] { AlltagLogik.zettelListe(stand) }

    @discardableResult
    func zettelNeu(_ eingabe: String, link: String? = nil, notiz: String? = nil, bild: String? = nil) -> Bool {
        guard let text = AlltagLogik.kurz(eingabe, hoechstens: AlltagLogik.zettelMaxZeichen), let ich = wer() else { return false }
        let d = AlltagLogik.ZettelD(id: "kz-" + UUID().uuidString, text: text, erledigt: false,
                                    link: link.flatMap(AlltagLogik.zettelLink),
                                    notiz: notiz.flatMap { AlltagLogik.kurz($0, hoechstens: AlltagLogik.notizMaxZeichen) }, bild: bild)
        absenden(Op.neu(AlltagLogik.artZettel, d, von: ich))
        return true
    }

    func zettelAbhaken(_ z: KuehlZettel) {
        guard let ich = wer() else { return }
        let d = AlltagLogik.ZettelD(id: z.id, text: z.text, erledigt: !z.erledigt, link: z.link, notiz: z.notiz, bild: z.bild)
        absenden(Op.neu(AlltagLogik.artZettel, d, von: ich))
    }

    func zettelLoeschen(_ z: KuehlZettel) {
        guard let ich = wer() else { return }
        absenden(Op.neu(AlltagLogik.artZettelWeg, AlltagLogik.ZettelWegD(id: z.id), von: ich))
    }

    // MARK: Wärmflasche und Tee

    /// Sendet "heute an" oder "heute aus", wenn sich etwas ändert. Mehr als dieses Ja/Nein verlässt das Gerät nicht.
    func waermeAbgleichen(soll: Bool, heute: String = Datum.text(Date())) {
        guard let ich = wer(), let neu = AlltagLogik.waermeSenden(soll: soll, heute: heute, bisher: stand.waerme[ich]) else { return }
        absenden(Op.neu(AlltagLogik.artWaerme, AlltagLogik.WaermeD(tag: heute, an: neu), von: ich))
    }

    /// Ruft die Ansicht beim Öffnen und der Schalter in den Zyklus-Einstellungen. Ohne Freigabe wird der
    /// Zyklus nicht einmal angefasst; auf dem Gerät, wo er nur lesbar ist (Ahmed), passiert nichts.
    func waermePruefen(heute: String = Datum.text(Date())) {
        guard let ich = wer() else { return }
        var soll = false
        if UserDefaults.standard.bool(forKey: ZyklusSchalter.waerme) {
            let zyklus = ZyklusSpeicherWahl.fuer(person: ich)
            guard !zyklus.nurLesen else { return }
            soll = AlltagLogik.schwererTag(tage: Array(zyklus.tage.values), einstellung: zyklus.einstellung, heute: heute)
        }
        waermeAbgleichen(soll: soll, heute: heute)
    }

    private func absenden(_ op: Op) {
        stand = AlltagLogik.anwenden([op], auf: stand)
        senden(op)
    }
}
