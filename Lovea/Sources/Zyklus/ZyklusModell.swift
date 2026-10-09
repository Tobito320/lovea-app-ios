import Foundation

enum Blutung: String, Codable, CaseIterable, Hashable {
    case schmierblutung, leicht, mittel, stark
}

enum Symptom: String, Codable, CaseIterable, Hashable {
    case kopfschmerzen, kraempfe, rueckenschmerzen, brustspannen, uebelkeit
    case blaehbauch, akne, muedigkeit, heisshunger, schwindel, verstopfung, durchfall
}

enum Stimmung: String, Codable, CaseIterable, Hashable {
    case froehlich, ruhig, energiegeladen, empfindlich, gereizt, traurig, aengstlich, gestresst
}

enum Ausfluss: String, Codable, CaseIterable, Hashable {
    case keiner, klebrig, cremig, waessrig, eiweissartig
}

enum TestErgebnis: String, Codable, CaseIterable, Hashable {
    case negativ, positiv
}

enum SexEintrag: String, Codable, CaseIterable, Hashable {
    case geschuetzt, ungeschuetzt
}

enum Modus: String, Codable, CaseIterable, Hashable {
    case zyklus, schwanger, kinderwunsch, pille
}

enum Phase: String, Codable, CaseIterable, Hashable {
    case periode, follikel, fruchtbar, eisprung, luteal
}

enum ZyklusQuelle: String, Codable, Hashable {
    case echt, demo
}

/// Ein Tag im Zyklus-Tagebuch. `id` ist das Datum als `yyyy-MM-dd` (siehe `Datum.kalender`).
struct ZyklusTag: Codable, Hashable, Identifiable {
    var id: String
    var blutung: Blutung?
    var symptome: Set<Symptom>
    var stimmung: Set<Stimmung>
    var ausfluss: Ausfluss?
    var temperatur: Double?
    var eisprungTest: TestErgebnis?
    var schwangerschaftsTest: TestErgebnis?
    var sex: SexEintrag?
    var pille: Bool?
    var wasserMl: Int?
    var schlafMin: Int?
    var gewicht: Double?
    var notiz: String?

    init(id: String,
         blutung: Blutung? = nil,
         symptome: Set<Symptom> = [],
         stimmung: Set<Stimmung> = [],
         ausfluss: Ausfluss? = nil,
         temperatur: Double? = nil,
         eisprungTest: TestErgebnis? = nil,
         schwangerschaftsTest: TestErgebnis? = nil,
         sex: SexEintrag? = nil,
         pille: Bool? = nil,
         wasserMl: Int? = nil,
         schlafMin: Int? = nil,
         gewicht: Double? = nil,
         notiz: String? = nil) {
        self.id = id
        self.blutung = blutung
        self.symptome = symptome
        self.stimmung = stimmung
        self.ausfluss = ausfluss
        self.temperatur = temperatur
        self.eisprungTest = eisprungTest
        self.schwangerschaftsTest = schwangerschaftsTest
        self.sex = sex
        self.pille = pille
        self.wasserMl = wasserMl
        self.schlafMin = schlafMin
        self.gewicht = gewicht
        self.notiz = notiz
    }

    /// Nichts eingetragen: der Speicher darf den Tag dann entfernen.
    var istLeer: Bool {
        blutung == nil && symptome.isEmpty && stimmung.isEmpty && ausfluss == nil
            && temperatur == nil && eisprungTest == nil && schwangerschaftsTest == nil
            && sex == nil && pille == nil && wasserMl == nil && schlafMin == nil
            && gewicht == nil && (notiz ?? "").isEmpty
    }
}

struct ZyklusEinstellung: Codable, Hashable {
    var zyklusLaenge: Int = 28
    var periodenLaenge: Int = 5
    var modus: Modus = .zyklus
}
