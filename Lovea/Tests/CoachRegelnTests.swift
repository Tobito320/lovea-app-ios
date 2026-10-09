import XCTest
@testable import Lovea

/// Health-Coach: reine Regeln, Verlaufs-Logik und Fehler-Zuordnung (`CoachRegeln.swift`). Kein Netz, keine Modelle.
final class CoachRegelnTests: XCTestCase {

    /// Donnerstag, Wochentag 4.
    private let heute = "2026-10-08"
    private let montag = "2026-10-05"

    private func tag(_ zurueck: Int, ab start: String? = nil) -> String {
        Datum.addTage(start ?? heute, -zurueck)
    }

    /// Essen an den `anzahl` Tagen vor heute (gestern zuerst).
    private func essen(_ e: inout CoachEingabe, tage anzahl: Int, kcal: Double, protein: Double = 100) {
        for zurueck in 1...anzahl {
            e.essenKcal[tag(zurueck, ab: e.heute)] = kcal
            e.essenProtein[tag(zurueck, ab: e.heute)] = protein
        }
    }

    private func arten(_ karten: [CoachKarte]) -> [CoachKarte.Art] { karten.map(\.art) }

    // MARK: - Konstanten und Tag-Prüfung

    func testUntergrenze() {
        XCTAssertEqual(CoachRegeln.untergrenze(geschlecht: 1), 1200)
        XCTAssertEqual(CoachRegeln.untergrenze(geschlecht: 0), 1500)
    }

    func testSchnellfragen() {
        XCTAssertEqual(CoachRegeln.schnellfragen, ["Tagesbericht", "Wie läuft mein Training?", "Was soll ich heute essen?"])
    }

    func testIstTagNimmtNurJahrMonatTag() {
        XCTAssertTrue(CoachRegeln.istTag("2026-10-08"))
        XCTAssertFalse(CoachRegeln.istTag(""))
        XCTAssertFalse(CoachRegeln.istTag("2026-1-8"))
        XCTAssertFalse(CoachRegeln.istTag("2026/10/08"))
        XCTAssertFalse(CoachRegeln.istTag("2026-10-0x"))
        XCTAssertFalse(CoachRegeln.istTag("2026-10-08T00"))
        XCTAssertFalse(CoachRegeln.istTag("kaputt"))
        XCTAssertFalse(CoachRegeln.istTag("2026-10-0\u{0668}"), "nur ASCII-Ziffern")
    }

    // MARK: - Essens-Log

    func testLeeresLogIstLueckigOhneSchnitt() {
        let stand = CoachRegeln.essenStand(CoachEingabe(heute: heute))
        XCTAssertEqual(stand.geloggteTage, 0)
        XCTAssertNil(stand.kcalSchnitt)
        XCTAssertNil(stand.proteinSchnitt)
        XCTAssertTrue(stand.lueckig)
        XCTAssertFalse(stand.sehrWenig)
    }

    func testTagMitNurKaffeeZaehltNichtAlsGeloggt() {
        var e = CoachEingabe(heute: heute)
        essen(&e, tage: 14, kcal: 4)
        let stand = CoachRegeln.essenStand(e)
        XCTAssertEqual(stand.geloggteTage, 0)
        XCTAssertNil(stand.kcalSchnitt)
        XCTAssertFalse(stand.sehrWenig, "ein Kaffee-Log ist keine Aufnahme")
    }

    func testHeuteZaehltInKeinemSchnittMit() {
        var e = CoachEingabe(heute: heute)
        essen(&e, tage: 12, kcal: 2000)
        e.essenKcal[heute] = 9000
        e.essenProtein[heute] = 900
        let stand = CoachRegeln.essenStand(e)
        XCTAssertEqual(stand.geloggteTage, 12)
        XCTAssertEqual(stand.kcalSchnitt ?? 0, 2000, accuracy: 0.001)
        XCTAssertEqual(stand.proteinSchnitt ?? 0, 100, accuracy: 0.001)
    }

    func testTageAusserhalbDes14TageFenstersZaehlenNicht() {
        var e = CoachEingabe(heute: heute)
        e.essenKcal[tag(15)] = 2000
        e.essenKcal[tag(14)] = 2000
        XCTAssertEqual(CoachRegeln.essenStand(e).geloggteTage, 1)
    }

    func testLueckigUnterZehnTagen() {
        var e = CoachEingabe(heute: heute)
        essen(&e, tage: 9, kcal: 2000)
        XCTAssertTrue(CoachRegeln.essenStand(e).lueckig)
        essen(&e, tage: 10, kcal: 2000)
        XCTAssertFalse(CoachRegeln.essenStand(e).lueckig)
    }

    func testSehrWenigBrauchtZehnGeloggteTage() {
        var e = CoachEingabe(heute: heute)
        essen(&e, tage: 9, kcal: 800)
        XCTAssertFalse(CoachRegeln.essenStand(e).sehrWenig, "neun Tage sind ein lückenhaftes Log, keine Aufnahme")
        essen(&e, tage: 10, kcal: 800)
        XCTAssertTrue(CoachRegeln.essenStand(e).sehrWenig)
    }

    func testSehrWenigVergleichtMitDerUntergrenzeDesGeschlechts() {
        var e = CoachEingabe(heute: heute)
        essen(&e, tage: 12, kcal: 1300)
        e.geschlecht = 0
        XCTAssertTrue(CoachRegeln.essenStand(e).sehrWenig, "Mann: unter 1500")
        e.geschlecht = 1
        XCTAssertFalse(CoachRegeln.essenStand(e).sehrWenig, "Frau: 1300 liegt über 1200")

        essen(&e, tage: 12, kcal: 1500)
        e.geschlecht = 0
        XCTAssertFalse(CoachRegeln.essenStand(e).sehrWenig, "genau die Grenze ist nicht darunter")
        essen(&e, tage: 12, kcal: 1199)
        e.geschlecht = 1
        XCTAssertTrue(CoachRegeln.essenStand(e).sehrWenig)
    }

    // MARK: - Karten: Sicherheit und Log

    func testSehrWenigGibtZuerstDieSicherheitsKarteUndKeinGewichtUndKeinProtein() {
        var e = CoachEingabe(heute: heute)
        e.geschlecht = 1
        e.zieleEingerichtet = true
        e.proteinZiel = 150
        essen(&e, tage: 12, kcal: 900, protein: 30)
        for zurueck in 1...10 { e.gewicht[tag(zurueck)] = 700 }
        let karten = CoachRegeln.karten(e)
        XCTAssertEqual(karten.first?.art, .sicherheit)
        XCTAssertFalse(arten(karten).contains(.gewicht))
        XCTAssertFalse(arten(karten).contains(.protein))
        XCTAssertFalse(arten(karten).contains(.essenLog))
        let text = karten.first?.text ?? ""
        XCTAssertTrue(text.contains(HealthText.zahl(1200)), "nennt die Untergrenze")
        XCTAssertTrue(text.contains("Arzt"), "verweist auf Hilfe")
        XCTAssertTrue(text.contains("Vielleicht fehlt nur Essen im Log"))
    }

    func testWenigeLogTageMitNiedrigenWertenGebenKeineSicherheitsKarte() {
        var e = CoachEingabe(heute: heute)
        essen(&e, tage: 5, kcal: 700)
        XCTAssertEqual(CoachRegeln.karten(e).first?.art, .essenLog, "wer selten trackt, isst nicht automatisch zu wenig")
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.sicherheit))
    }

    func testLueckigGibtEssenLogKarteUndKeineProteinKarte() {
        var e = CoachEingabe(heute: heute)
        e.zieleEingerichtet = true
        e.proteinZiel = 150
        essen(&e, tage: 6, kcal: 1800, protein: 40)
        let karten = CoachRegeln.karten(e)
        XCTAssertEqual(karten.first?.art, .essenLog)
        XCTAssertTrue(karten.first?.text.contains("6 von 14") ?? false)
        XCTAssertTrue(karten.first?.text.contains("rechne ich nicht als echte Aufnahme") ?? false)
        XCTAssertFalse(arten(karten).contains(.protein), "Lücken sind keine echte Aufnahme")
    }

    func testOhneEinenLogTagKeineEssenKarte() {
        let karten = CoachRegeln.karten(CoachEingabe(heute: heute))
        XCTAssertFalse(arten(karten).contains(.sicherheit))
        XCTAssertFalse(arten(karten).contains(.essenLog))
        XCTAssertTrue(karten.isEmpty)
    }

    // MARK: - Karten: Protein

    func testProteinKarteBeiLuecke() {
        var e = CoachEingabe(heute: heute)
        e.zieleEingerichtet = true
        e.proteinZiel = 150
        essen(&e, tage: 12, kcal: 2000, protein: 100)
        let karte = CoachRegeln.karten(e).first { $0.art == .protein }
        XCTAssertNotNil(karte)
        XCTAssertTrue(karte?.text.hasPrefix("Im Log liegst du bei etwa 100 g Protein") ?? false)
        XCTAssertTrue(karte?.text.contains("150 g") ?? false)
    }

    func testProteinKarteFehltOhneEingerichtetesZiel() {
        var e = CoachEingabe(heute: heute)
        e.zieleEingerichtet = false
        e.proteinZiel = 150
        essen(&e, tage: 12, kcal: 2000, protein: 100)
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.protein), "Schätzwert aus dem Gewicht ist kein Ziel")
    }

    func testProteinKarteSchwelleBei85Prozent() {
        var e = CoachEingabe(heute: heute)
        e.zieleEingerichtet = true
        e.proteinZiel = 150
        essen(&e, tage: 12, kcal: 2000, protein: 127)
        XCTAssertTrue(arten(CoachRegeln.karten(e)).contains(.protein))
        essen(&e, tage: 12, kcal: 2000, protein: 128)
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.protein))
    }

    // MARK: - Karten: Schritte

    func testSchritteKarte() {
        var e = CoachEingabe(heute: heute)
        e.schrittZiel = 10_000
        for zurueck in 1...3 { e.schritte[tag(zurueck)] = 5000 }
        let karte = CoachRegeln.karten(e).first { $0.art == .schritte }
        XCTAssertNotNil(karte)
        XCTAssertTrue(karte?.text.contains(HealthText.zahl(5000)) ?? false)
        XCTAssertTrue(karte?.text.contains(HealthText.zahl(10_000)) ?? false)
    }

    func testSchritteKarteBrauchtDreiTageUndZiel() {
        var e = CoachEingabe(heute: heute)
        e.schrittZiel = 10_000
        e.schritte[tag(1)] = 3000
        e.schritte[tag(2)] = 3000
        e.schritte[heute] = 100
        e.schritte[tag(8)] = 3000
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.schritte), "heute und Tag 8 zählen nicht")

        e.schritte[tag(3)] = 3000
        XCTAssertTrue(arten(CoachRegeln.karten(e)).contains(.schritte))

        e.schrittZiel = 0
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.schritte), "ohne Ziel keine Karte")
    }

    func testSchritteKarteGrenzeBei70Prozent() {
        var e = CoachEingabe(heute: heute)
        e.schrittZiel = 10_000
        for zurueck in 1...3 { e.schritte[tag(zurueck)] = 7000 }
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.schritte), "genau 70 % ist nicht darunter")
        for zurueck in 1...3 { e.schritte[tag(zurueck)] = 6999 }
        XCTAssertTrue(arten(CoachRegeln.karten(e)).contains(.schritte))
    }

    // MARK: - Karten: Training

    func testTrainingKarteErstAbDonnerstag() {
        let gruppen = [CoachGruppe(name: "Brust", saetze: 2.5, ziel: 10, faellig: true)]
        var e = CoachEingabe(heute: montag)
        e.gruppen = gruppen
        XCTAssertEqual(Datum.wochentag(montag), 1)
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.training), "Montag: noch zu früh")

        e.heute = Datum.addTage(montag, 2)
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.training), "Mittwoch")

        e.heute = heute
        XCTAssertEqual(Datum.wochentag(heute), 4)
        let karte = CoachRegeln.karten(e).first { $0.art == .training }
        XCTAssertNotNil(karte)
        XCTAssertTrue(karte?.text.contains("Brust \(TrainingLogik.kgText(2.5)) von 10 Sätzen") ?? false)
    }

    func testTrainingKarteNenntHoechstensZweiOffeneGruppen() {
        var e = CoachEingabe(heute: heute)
        e.gruppen = [
            CoachGruppe(name: "Brust", saetze: 1, ziel: 10, faellig: true),
            CoachGruppe(name: "Rücken", saetze: 12, ziel: 12, faellig: false),
            CoachGruppe(name: "Beine", saetze: 2, ziel: 12, faellig: true),
            CoachGruppe(name: "Schultern", saetze: 0, ziel: 8, faellig: true),
            CoachGruppe(name: "Arme", saetze: 0, ziel: 0, faellig: true),
        ]
        let text = CoachRegeln.karten(e).first { $0.art == .training }?.text ?? ""
        XCTAssertTrue(text.contains("Brust"))
        XCTAssertTrue(text.contains("Beine"))
        XCTAssertFalse(text.contains("Rücken"), "nicht fällig")
        XCTAssertFalse(text.contains("Schultern"), "nur zwei Gruppen")
        XCTAssertFalse(text.contains("Arme"), "ohne Ziel")
    }

    func testTrainingKarteFehltWennNichtsFaelligIst() {
        var e = CoachEingabe(heute: heute)
        e.gruppen = [CoachGruppe(name: "Brust", saetze: 9, ziel: 10, faellig: false)]
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.training))
    }

    // MARK: - Karten: Steigerung

    func testSteigerungsKarteNimmtMehrGewichtZuerstUndHoechstensZwei() {
        let a = KoerperLogik.Vorschlag(kg: 60, wdh: 9, mehrGewicht: false)
        let b = KoerperLogik.Vorschlag(kg: 42.5, wdh: 8, mehrGewicht: true)
        let c = KoerperLogik.Vorschlag(kg: nil, wdh: 10, mehrGewicht: false)
        var e = CoachEingabe(heute: heute)
        e.uebungen = [
            CoachUebung(name: "Bankdrücken", vorschlag: a),
            CoachUebung(name: "Rudern", vorschlag: b),
            CoachUebung(name: "Klimmzüge", vorschlag: c),
        ]
        let karte = CoachRegeln.karten(e).first { $0.art == .steigerung }
        XCTAssertEqual(karte?.titel, "Nächstes Mal")
        XCTAssertEqual(karte?.text, "Rudern: \(KoerperLogik.vorschlagText(b))\nBankdrücken: \(KoerperLogik.vorschlagText(a))")
        XCTAssertFalse(karte?.text.contains("Klimmzüge") ?? true)
    }

    func testSteigerungsKarteFehltOhneUebungen() {
        XCTAssertFalse(arten(CoachRegeln.karten(CoachEingabe(heute: heute))).contains(.steigerung))
    }

    // MARK: - Karten: Gewicht

    private func gewichtswochen(_ e: inout CoachEingabe, neuester: String, jetzt: Int, davor: Int) {
        for zurueck in 0...6 { e.gewicht[tag(zurueck, ab: neuester)] = jetzt }
        for zurueck in 7...13 { e.gewicht[tag(zurueck, ab: neuester)] = davor }
    }

    func testGewichtKarteZeigtSchnittUndWocheDavor() {
        var e = CoachEingabe(heute: heute)
        gewichtswochen(&e, neuester: "2026-10-07", jetzt: 800, davor: 810)
        let karte = CoachRegeln.karten(e).first { $0.art == .gewicht }
        XCTAssertNotNil(karte)
        XCTAssertTrue(karte?.text.contains("Schnitt der letzten 7 Tage: \(GewichtText.anzeige(800))") ?? false)
        XCTAssertTrue(karte?.text.contains("Woche davor: \(GewichtText.anzeige(810))") ?? false)
        XCTAssertTrue(karte?.text.contains("Einzelne Tage schwanken") ?? false)
    }

    func testGewichtKarteBrauchtZweiEintraegeInDerWoche() {
        var e = CoachEingabe(heute: heute)
        e.gewicht["2026-10-07"] = 800
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.gewicht))
        e.gewicht["2026-10-06"] = 802
        XCTAssertTrue(arten(CoachRegeln.karten(e)).contains(.gewicht))
    }

    func testGewichtKarteFehltBeiLetztemEintragAelterAlsZehnTage() {
        var e = CoachEingabe(heute: heute)
        e.gewicht["2026-09-28"] = 800
        e.gewicht["2026-09-27"] = 802
        XCTAssertTrue(arten(CoachRegeln.karten(e)).contains(.gewicht), "zehn Tage alt gilt noch")
        e.gewicht = ["2026-09-27": 800, "2026-09-26": 802]
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.gewicht), "elf Tage alt")
    }

    func testGewichtKarteUeberlebtKaputteSchluesselUndNullwerte() {
        var e = CoachEingabe(heute: heute)
        e.gewicht["kaputt"] = 700
        e.gewicht["2026-1-7"] = 700
        e.gewicht["2026-10-06"] = 0
        e.gewicht["2026-10-05"] = 800
        XCTAssertFalse(arten(CoachRegeln.karten(e)).contains(.gewicht), "nur ein gültiger Eintrag")
        e.gewicht["2026-10-04"] = 804
        XCTAssertTrue(arten(CoachRegeln.karten(e)).contains(.gewicht))
    }

    // MARK: - Reihenfolge und Ton

    private func vollesBild() -> CoachEingabe {
        var e = CoachEingabe(heute: heute)
        e.zieleEingerichtet = true
        e.proteinZiel = 150
        essen(&e, tage: 12, kcal: 2000, protein: 100)
        e.schrittZiel = 10_000
        for zurueck in 1...4 { e.schritte[tag(zurueck)] = 4000 }
        e.gruppen = [CoachGruppe(name: "Brust", saetze: 1, ziel: 10, faellig: true)]
        e.uebungen = [CoachUebung(name: "Rudern", vorschlag: KoerperLogik.Vorschlag(kg: 40, wdh: 9, mehrGewicht: false))]
        gewichtswochen(&e, neuester: "2026-10-07", jetzt: 800, davor: 810)
        return e
    }

    func testKartenReihenfolgeIstWichtigkeit() {
        XCTAssertEqual(arten(CoachRegeln.karten(vollesBild())), [.training, .steigerung, .protein, .schritte, .gewicht])
    }

    func testKartenIdsSindEindeutig() {
        let ids = CoachRegeln.karten(vollesBild()).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testKeineKarteEmpfiehltEinDefizitOderNutztStreaksOderEmojis() {
        var sehrWenig = CoachEingabe(heute: heute)
        essen(&sehrWenig, tage: 12, kcal: 900)
        var luecke = CoachEingabe(heute: heute)
        essen(&luecke, tage: 4, kcal: 1800)
        let alle = CoachRegeln.karten(vollesBild()) + CoachRegeln.karten(sehrWenig) + CoachRegeln.karten(luecke)
        XCTAssertFalse(alle.isEmpty)
        let verboten = ["defizit", "abnehmen", "streak", "serie", "in folge", "weniger essen"]
        for karte in alle {
            let text = (karte.titel + " " + karte.text).lowercased()
            for wort in verboten {
                XCTAssertFalse(text.contains(wort), "\(karte.art): \(wort)")
            }
            XCTAssertFalse(karte.text.unicodeScalars.contains { $0.properties.isEmojiPresentation }, "\(karte.art): Emoji")
            XCTAssertFalse(karte.titel.isEmpty)
            XCTAssertFalse(karte.text.isEmpty)
        }
    }

    // MARK: - Verlauf

    private func nachricht(_ id: String, _ rolle: CoachNachricht.Rolle, _ text: String, _ sekunden: Double,
                           seq: Int? = nil, lokal: Bool = false) -> CoachNachricht {
        CoachNachricht(id: id, rolle: rolle, text: text, zeit: Date(timeIntervalSince1970: 1_800_000_000 + sekunden), seq: seq, lokal: lokal)
    }

    func testSortierenNachZeitDannSeqDannDuVorCoachDannId() {
        let spaet = nachricht("s", .coach, "spät", 50)
        let frueh = nachricht("f", .du, "früh", 10)
        XCTAssertEqual(CoachVerlauf.sortieren([spaet, frueh]).map(\.id), ["f", "s"])

        let zweite = nachricht("a", .coach, "x", 10, seq: 9)
        let erste = nachricht("b", .coach, "y", 10, seq: 4)
        XCTAssertEqual(CoachVerlauf.sortieren([zweite, erste]).map(\.id), ["b", "a"])

        let coach = nachricht("1", .coach, "Antwort", 10)
        let du = nachricht("2", .du, "Frage", 10)
        XCTAssertEqual(CoachVerlauf.sortieren([coach, du]).map(\.rolle), [.du, .coach])

        let b = nachricht("b", .du, "x", 10)
        let a = nachricht("a", .du, "x", 10)
        XCTAssertEqual(CoachVerlauf.sortieren([b, a]).map(\.id), ["a", "b"])
    }

    func testZusammenfuehrenLaesstEineBestaetigteFrageNurEinmalErscheinen() {
        let op = nachricht("op-1", .du, "Tagesbericht", 100, seq: 1)
        let lokal = nachricht("lokal-1", .du, "Tagesbericht ", 100, lokal: true)
        let liste = CoachVerlauf.zusammenfuehren(ops: [op], lokal: [lokal])
        XCTAssertEqual(liste.map(\.id), ["op-1"])
    }

    func testZusammenfuehrenBehaeltUnbestaetigteLokaleEintraege() {
        let op = nachricht("op-1", .du, "Frage", 100, seq: 1)
        let lokal = nachricht("lokal-1", .coach, "Antwort aus HTTP", 105, lokal: true)
        let liste = CoachVerlauf.zusammenfuehren(ops: [op], lokal: [lokal])
        XCTAssertEqual(liste.map(\.id), ["op-1", "lokal-1"])
    }

    func testWiederholteSchnellfrageFrisstKeineAlteOp() {
        let alt = nachricht("op-alt", .du, "Tagesbericht", 0, seq: 1)
        let lokal = nachricht("lokal-neu", .du, "Tagesbericht", 1000, lokal: true)
        let nurAlt = CoachVerlauf.zusammenfuehren(ops: [alt], lokal: [lokal])
        XCTAssertEqual(nurAlt.map(\.id), ["op-alt", "lokal-neu"], "die alte Op passt nicht zur neuen Frage")

        let neu = nachricht("op-neu", .du, "Tagesbericht", 1001, seq: 5)
        let beide = CoachVerlauf.zusammenfuehren(ops: [alt, neu], lokal: [lokal])
        XCTAssertEqual(beide.map(\.id), ["op-alt", "op-neu"])
    }

    func testZweiGleicheLokaleFragenBrauchenZweiOps() {
        let eins = nachricht("lokal-1", .du, "Hallo", 1000, lokal: true)
        let zwei = nachricht("lokal-2", .du, "Hallo", 1010, lokal: true)
        let op = nachricht("op-1", .du, "Hallo", 1005, seq: 1)
        let liste = CoachVerlauf.zusammenfuehren(ops: [op], lokal: [eins, zwei])
        XCTAssertEqual(liste.map(\.id), ["op-1", "lokal-2"])
    }

    func testZusammenfuehrenBrauchtGleicheRolle() {
        let op = nachricht("op-1", .coach, "Hallo", 100, seq: 1)
        let lokal = nachricht("lokal-1", .du, "Hallo", 100, lokal: true)
        XCTAssertEqual(CoachVerlauf.zusammenfuehren(ops: [op], lokal: [lokal]).count, 2)
    }

    func testZusammenfuehrenVertrautDerServerUhrNurInnerhalbDerToleranz() {
        let lokal = nachricht("lokal-1", .du, "Hallo", 1000, lokal: true)
        let knapp = nachricht("op-knapp", .du, "Hallo", 1000 - CoachVerlauf.zeitToleranz + 1, seq: 1)
        XCTAssertEqual(CoachVerlauf.zusammenfuehren(ops: [knapp], lokal: [lokal]).map(\.id), ["op-knapp"])
        let zuFrueh = nachricht("op-frueh", .du, "Hallo", 1000 - CoachVerlauf.zeitToleranz - 1, seq: 1)
        XCTAssertEqual(CoachVerlauf.zusammenfuehren(ops: [zuFrueh], lokal: [lokal]).count, 2)
    }

    func testSichtbarBlendetAltesAus() {
        let alt = nachricht("alt", .du, "alt", 10)
        let neu = nachricht("neu", .coach, "neu", 200)
        XCTAssertEqual(CoachVerlauf.sichtbar([alt, neu], ausgeblendetBis: nil).map(\.id), ["alt", "neu"])
        let grenze = Date(timeIntervalSince1970: 1_800_000_000 + 100)
        XCTAssertEqual(CoachVerlauf.sichtbar([alt, neu], ausgeblendetBis: grenze).map(\.id), ["neu"])
        let genau = nachricht("genau", .du, "genau", 100)
        XCTAssertTrue(CoachVerlauf.sichtbar([genau], ausgeblendetBis: grenze).isEmpty, "nur was danach entstand")
    }

    // MARK: - Op -> Nachricht

    func testNachrichtAusOp() {
        let op = Op.neu("coach.nachricht", ["rolle": "du", "text": "Hallo", "tag": "2026-10-08"], von: .ahmed)
        let n = CoachNachricht.aus(op)
        XCTAssertEqual(n?.id, op.id)
        XCTAssertEqual(n?.rolle, .du)
        XCTAssertEqual(n?.text, "Hallo")
        XCTAssertEqual(n?.zeit, op.zeit)
        XCTAssertNil(n?.seq)
        XCTAssertEqual(n?.lokal, false)
    }

    func testNachrichtAusOpLiestRolleUndTagWeich() {
        let coach = Op.neu("coach.nachricht", ["rolle": "coach", "text": "Antwort"], von: .annika)
        XCTAssertEqual(CoachNachricht.aus(coach)?.rolle, .coach, "tag fehlt: kein Problem")
        let fremd = Op.neu("coach.nachricht", ["rolle": "system", "text": "Antwort"], von: .annika)
        XCTAssertEqual(CoachNachricht.aus(fremd)?.rolle, .coach, "alles außer du zeigt sich als Coach")
    }

    func testNachrichtAusOpUebernimmtSeq() {
        let roh = Op.neu("coach.nachricht", ["rolle": "du", "text": "Hallo"], von: .ahmed)
        let op = Op(id: roh.id, seq: 7, art: roh.art, von: roh.von, zeit: roh.zeit, d: roh.d)
        XCTAssertEqual(CoachNachricht.aus(op)?.seq, 7)
    }

    func testNachrichtAusOpLehntFalscheArtLeerenTextUndKaputtesAb() {
        XCTAssertNil(CoachNachricht.aus(Op.neu("chat.nachricht", ["rolle": "du", "text": "Hallo"], von: .ahmed)))
        XCTAssertNil(CoachNachricht.aus(Op.neu("coach.nachricht", ["rolle": "du", "text": "  \n "], von: .ahmed)))
        XCTAssertNil(CoachNachricht.aus(Op.neu("coach.nachricht", ["rolle": "du"], von: .ahmed)))
        let kaputt = Op(id: "x", seq: nil, art: "coach.nachricht", von: .ahmed, zeit: Date(), d: Data("kaputt".utf8))
        XCTAssertNil(CoachNachricht.aus(kaputt))
    }

    // MARK: - Fehler

    func testFehlerAusStatus() {
        for status in [200, 201, 204, 299] { XCTAssertNil(CoachFehler.aus(status: status), "\(status)") }
        XCTAssertEqual(CoachFehler.aus(status: 503), .nichtEingerichtet)
        XCTAssertEqual(CoachFehler.aus(status: 429), .tageslimit)
        XCTAssertEqual(CoachFehler.aus(status: 0), .netz)
        for status in [300, 400, 401, 404, 500, 502] { XCTAssertEqual(CoachFehler.aus(status: status), .server, "\(status)") }
    }

    func testFehlerTexteSindVerschiedenUndRuhig() {
        let alle: [CoachFehler] = [.nichtEingerichtet, .tageslimit, .netz, .server]
        XCTAssertEqual(Set(alle.map(\.text)).count, 4)
        XCTAssertTrue(CoachFehler.nichtEingerichtet.text.hasPrefix("Coach noch nicht eingerichtet"))
        XCTAssertTrue(CoachFehler.tageslimit.text.hasPrefix("Tageslimit erreicht"))
        for fehler in alle {
            XCTAssertFalse(fehler.text.contains("!"), "ruhiger Ton")
            XCTAssertFalse(fehler.text.unicodeScalars.contains { $0.properties.isEmojiPresentation })
        }
    }

    func testSchluesselProPerson() {
        XCTAssertEqual(CoachSchluessel.ausgeblendet(.ahmed), "lovea.coach.ausgeblendetBis.ahmed")
        XCTAssertNotEqual(CoachSchluessel.ausgeblendet(.ahmed), CoachSchluessel.ausgeblendet(.annika))
        XCTAssertEqual(CoachSchluessel.morgen, "coach.morgen")
    }
}
