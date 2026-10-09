import Foundation
import CoreGraphics

/// Unser Zimmer, Worker I: reine Logik für Nähe und Zeit (Sternenhimmel, Katzenseite, Schublade, Faden,
/// Koffer, Kissenburg, Lichterkette). Keine Zustände, nur Rechnen; getestet in `ZimmerNaeheTests`.
enum ZimmerNaeheLogik {
    // MARK: Katze (7)

    /// So lange gilt der Partner als "gerade da".
    static let kurzZuvor: TimeInterval = 30 * 60

    /// Die Katze schläft auf der Seite dessen, der zuletzt da war: der Partner ist da oder war gerade da, dann bei ihm,
    /// sonst bei mir. Liefert `true`, wenn die Katze auf Ahmeds Seite (links) liegt.
    static func katzeBeiAhmed(ich: Person, partnerDa: Bool, partnerZuletzt: Date?, jetzt: Date) -> Bool {
        let partnerNah = partnerDa || (partnerZuletzt.map { jetzt.timeIntervalSince($0) < kurzZuvor } ?? false)
        let person = partnerNah ? ich.partner : ich
        return person == .ahmed
    }

    // MARK: Sternenhimmel (2)

    static let sterneMaximum = 40

    /// Nachts (21 bis 5 Uhr) zeigt die Decke die Sterne.
    static func nacht(stunde: Int) -> Bool { stunde >= 21 || stunde < 5 }

    /// Stabile Zahl aus einer Id (FNV-1a), damit ein Stern immer am selben Ort steht.
    static func hash(_ id: String) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }

    /// Ort eines Sterns in 0...1 (x, y) aus seiner Id; die Decke ist der obere Streifen.
    static func sternOrt(id: String) -> CGPoint {
        let h = hash(id)
        return CGPoint(x: Double(h % 1000) / 999, y: Double((h / 1000) % 1000) / 999)
    }

    /// Die Ids der Sterne: neueste zuerst, doppelte raus, höchstens `sterneMaximum`.
    static func sterne(ids: [String]) -> [String] {
        var gesehen = Set<String>()
        return Array(ids.filter { gesehen.insert($0).inserted }.prefix(sterneMaximum))
    }

    // MARK: Schublade (8)

    static let schubladeFenster: TimeInterval = 10
    static let zettelMaximum = 140
    static let zettelAnzahl = 12

    /// Die Schublade geht auf, wenn beide innerhalb des Fensters getippt haben.
    static func schubladeOffen(meinHalt: Date?, partnerHalt: Date?, jetzt: Date) -> Bool {
        guard let m = meinHalt, let p = partnerHalt else { return false }
        return abs(m.timeIntervalSince(p)) <= schubladeFenster && jetzt.timeIntervalSince(max(m, p)) <= schubladeFenster
    }

    struct Zettel: Codable, Equatable, Identifiable {
        var id: String
        var text: String
    }

    static func bereinigt(_ eingabe: String) -> String? {
        let t = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return String(t.prefix(zettelMaximum))
    }

    static func zettelHinzu(_ liste: [Zettel], text: String, id: String) -> [Zettel] {
        guard let t = bereinigt(text) else { return liste }
        return Array((liste + [Zettel(id: id, text: t)]).suffix(zettelAnzahl))
    }

    // MARK: Faden (11)

    /// Der Faden hängt zwischen 0,12 (ganz nah) und 1 (sehr weit); darunter hängt er durch.
    /// Schalter in Einstellungen, Standard aus. Nur auf diesem Gerät, nichts davon geht an den Server.
    static let fadenSchluessel = "lovea.zimmer.faden"
    static let fadenNah = 0.12
    static let fadenWeitKm = 1000.0

    /// Grob gerundete Kilometer: unter 10 km auf 1, bis 100 km auf 5, darüber auf 10.
    static func gerundeteKm(meter: Double) -> Int {
        let km = max(0, meter) / 1000
        if km < 10 { return Int(km.rounded()) }
        if km < 100 { return Int((km / 5).rounded()) * 5 }
        return Int((km / 10).rounded()) * 10
    }

    /// Länge des Fadens von `fadenNah` bis 1. Weiter als `fadenWeitKm` bleibt er bei 1.
    static func fadenLaenge(km: Int) -> Double {
        let anteil = min(max(Double(km), 0), fadenWeitKm) / fadenWeitKm
        return fadenNah + (1 - fadenNah) * anteil
    }

    /// Der Faden zeigt sich nur mit Schalter und beiden Orten; sonst nichts, es wird nichts gespeichert.
    static func fadenText(km: Int?) -> String? {
        km.map { $0 == 0 ? "Ihr seid am selben Ort" : "Noch rund \($0) km" }
    }

    // MARK: Koffer (12)

    static let koffer = ["Zahnbürste", "Pulli", "Socken", "Kuscheltier", "Ladekabel", "Geschenk"]

    /// Ganze Tage bis zum Besuch (heute = 0), nil bei Vergangenheit oder fehlendem Datum.
    static func tageBis(_ tag: String?, heute: String) -> Int? {
        guard let tag, !tag.isEmpty, tag >= heute else { return nil }
        return Datum.tageZwischen(heute, tag)
    }

    /// Wie viele Dinge sind gepackt? Ab 7 Tagen vorher beginnt es, jeden Tag eins mehr, am Tag selbst alles.
    static func gepackt(tageBis tage: Int) -> Int {
        let fenster = koffer.count + 1
        return min(max(fenster - tage, 0), koffer.count)
    }

    /// Der nächste Besuch: das früheste Datum ab heute.
    static func naechsterBesuch(_ tage: [String], heute: String) -> String? {
        tage.filter { $0 >= heute }.min()
    }

    // MARK: Kissenburg (15)

    static let deckenVoll = 6
    static let deckenProPerson = 3

    /// Wochenende: Samstag oder Sonntag (Berlin).
    static func wochenende(_ datum: Date, kalender: Calendar = .berlin) -> Bool {
        let t = kalender.component(.weekday, from: datum)
        return t == 1 || t == 7
    }

    /// Decken beider Personen, begrenzt je Person.
    static func decken(meine: Int, partner: Int) -> Int {
        min(max(meine, 0), deckenProPerson) + min(max(partner, 0), deckenProPerson)
    }

    static func burgVoll(meine: Int, partner: Int) -> Bool { decken(meine: meine, partner: partner) >= deckenVoll }

    // MARK: Lichterkette (20)

    static let kettenTage = 30

    /// Die letzten `kettenTage` Tage bis einschließlich heute als `yyyy-MM-dd`, ältester zuerst.
    static func letzteTage(heute: Date, kalender: Calendar = .berlin) -> [String] {
        (0..<kettenTage).reversed().compactMap { kalender.date(byAdding: .day, value: -$0, to: heute) }.map { Datum.text($0) }
    }

    /// Tage, an denen beide die App offen hatten, jeweils aus den Tageslisten beider Personen.
    static func gemeinsam(meine: [String], partner: [String]) -> Set<String> {
        Set(meine).intersection(partner)
    }

    /// Je Tag der letzten 30 eine Glühbirne: leuchtet sie?
    static func birnen(meine: [String], partner: [String], heute: Date) -> [Bool] {
        let beide = gemeinsam(meine: meine, partner: partner)
        return letzteTage(heute: heute).map { beide.contains($0) }
    }

    static func kettenVoll(_ birnen: [Bool]) -> Bool { birnen.count == kettenTage && !birnen.contains(false) }

    /// Die eigene Tagesliste: heute dazu, doppelte raus, nur die letzten 40 Tage.
    static func tagHinzu(_ liste: [String], heute: String) -> [String] {
        Array((liste.contains(heute) ? liste : liste + [heute]).suffix(kettenTage + 10))
    }

    // MARK: Plüschtier (18)

    /// Die neueste Sprachnachricht des Partners.
    static func neuesteSprachpost(_ liste: [Sprachpost], von partner: Person) -> Sprachpost? {
        liste.filter { $0.von == partner }.max { $0.zeit < $1.zeit }
    }
}
