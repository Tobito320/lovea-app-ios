import Foundation

/// Schlaf als Punktesystem (Ahmed, 05.10.): keine einzelne Regel entscheidet, sondern viele Hinweise,
/// jeder gibt Plus- oder Minuspunkte. Reine Rechnung auf Daten, die iOS schon gespeichert hat
/// (CoreMotion-Verlauf, HealthKit) oder die Kurzbefehle aufgezeichnet haben. Kein Sensor läuft dafür,
/// kein Hintergrund-Timer: Akku kostet nur die Rechnung beim Öffnen der App.
///
/// Jede Minute des Fensters (18 Uhr Vortag bis 14 Uhr) bekommt eine Punktzahl. Ab `schwelle` zählt sie
/// als Schlaf. Lücken bis 60 min (Toilette, kurz aufs Handy) gehören zur selben Nacht, zählen aber nicht mit.
extension SchlafLogik {
    // MARK: - Gewichte (Plus = Schlaf, Minus = wach)

    enum Punkte {
        static let ruhe = 2.0          // Handy liegt still (CoreMotion, Konfidenz mittel oder hoch)
        static let zuhause = 1.0       // angenommen, solange `unterwegs` nichts anderes sagt
        static let nacht = 1.0         // 22 bis 7 Uhr; tagsüber (10 bis 18 Uhr) -1
        static let gewohnheit = 1.0    // innerhalb der üblichen Bett- bis Aufstehzeit
        static let guteNacht = 2.0     // 12 h nach "Gute Nacht" im Chat
        static let imBett = 2.0        // iPhone-Schlafenszeit (HealthKit inBed)
        static let laden = 2.0         // Handy lädt (Kurzbefehl)
        static let fokus = 2.0         // Fokus "Schlafen" an (Kurzbefehl)
        static let handInHand = -4.0   // Bewegung ohne Ruhe: Handy in der Hand
        static let tonLaeuft = -3.0    // Ton über AirPods (nur mit Schalter "Ich habe AirPods Pro 3")
        static let handyAus = -6.0     // Handy war aus: keine Beweise, kein Schlaf
        static let pcAktiv = -4.0      // echte Maus oder Tastatur am PC
        static let unterwegs = -4.0    // nicht zu Hause
        static let weckerAus = -6.0    // ab "Wecker aus"
    }

    static let schwelle = 4.0
    /// Wache Lücken bis hierhin (min) bleiben in derselben Nacht.
    static let nachtLuecke = 60

    struct PunkteEingabe: Sendable {
        var tag: String
        var fensterEnde: Date
        var aktivitaeten: [Aktivitaet] = []
        var imBett: [HealthLogik.SchlafIntervall] = []
        var ton: [HealthLogik.SchlafIntervall] = []
        var laden: [HealthLogik.SchlafIntervall] = []
        var fokus: [HealthLogik.SchlafIntervall] = []
        var aus: [HealthLogik.SchlafIntervall] = []
        var pc: [HealthLogik.SchlafIntervall] = []
        var unterwegs: [HealthLogik.SchlafIntervall] = []
        var guteNacht: Date?
        var wecker: Date?
        /// Übliche Bett- und Aufstehzeit in Minuten ab Mitternacht (aus den Korrekturen gelernt).
        var gewohnheit: (bett: Int, auf: Int)?
    }

    struct PunkteErgebnis: Sendable {
        var nacht: (minuten: Int, von: Date, bis: Date)?
        var konfidenz: Konfidenz
        /// Kurzer Schlaf (ab 20 min), der keine Nacht ist.
        var nickerchen: [HealthLogik.SchlafIntervall]
        /// Wache Lücken innerhalb der Nacht.
        var wachLuecken: [HealthLogik.SchlafIntervall]

        var quelle: String {
            switch konfidenz {
            case .hoch: "Punktesystem, sicher"
            case .mittel: "Punktesystem, wahrscheinlich"
            case .niedrig: "Punktesystem, unsicher"
            }
        }
    }

    static func punkte(_ e: PunkteEingabe) -> PunkteErgebnis {
        let leer = PunkteErgebnis(nacht: nil, konfidenz: .niedrig, nickerchen: [], wachLuecken: [])
        let kal = Calendar.berlin
        let tagStart = kal.startOfDay(for: Datum.datum(e.tag))
        guard let start = kal.date(byAdding: .hour, value: -6, to: tagStart),
              let fensterMax = kal.date(byAdding: .hour, value: 14, to: tagStart) else { return leer }
        let ende = min(e.fensterEnde, fensterMax)
        let n = Int(ende.timeIntervalSince(start) / 60)
        guard n > 0 else { return leer }

        func zeit(_ i: Int) -> Date { start.addingTimeInterval(Double(i) * 60) }
        func minute(_ d: Date) -> Int { Int(d.timeIntervalSince(start) / 60) }

        var score = [Double](repeating: 0, count: n)
        /// Eine Art von Hinweis zählt je Minute höchstens einmal, auch wenn sich Spannen überlappen.
        func addiere(_ spannen: [HealthLogik.SchlafIntervall], _ p: Double) {
            var belegt = Set<Int>()
            for s in spannen {
                let a = max(0, Int((s.von.timeIntervalSince(start) / 60).rounded(.down)))
                let b = min(n, Int((s.bis.timeIntervalSince(start) / 60).rounded(.up)))
                if a < b { belegt.formUnion(a..<b) }
            }
            for i in belegt { score[i] += p }
        }

        // Bewegung: Ruhe oder Handy in der Hand.
        let sortiert = e.aktivitaeten.sorted { $0.zeit < $1.zeit }
        var ruhe: [HealthLogik.SchlafIntervall] = []
        var hand: [HealthLogik.SchlafIntervall] = []
        for (i, a) in sortiert.enumerated() {
            let bis = i + 1 < sortiert.count ? sortiert[i + 1].zeit : ende
            guard bis > a.zeit else { continue }
            let spanne = HealthLogik.SchlafIntervall(von: a.zeit, bis: bis)
            if !a.stationaer { hand.append(spanne) } else if a.konfidenz >= .mittel { ruhe.append(spanne) }
        }
        addiere(ruhe, Punkte.ruhe)
        addiere(hand, Punkte.handInHand)
        addiere(e.imBett, Punkte.imBett)
        addiere(e.laden, Punkte.laden)
        addiere(e.fokus, Punkte.fokus)
        addiere(e.ton, Punkte.tonLaeuft)
        addiere(e.aus, Punkte.handyAus)
        addiere(e.pc, Punkte.pcAktiv)
        addiere(e.unterwegs, Punkte.unterwegs)

        // Hinweise, die für jede Minute gelten: Ort angenommen, Tageszeit, Gewohnheit, Gute Nacht, Wecker.
        for i in score.indices {
            let d = zeit(i)
            let c = kal.dateComponents([.hour, .minute], from: d)
            let h = c.hour ?? 0
            let m = h * 60 + (c.minute ?? 0)
            score[i] += Punkte.zuhause
            if h >= 22 || h < 7 { score[i] += Punkte.nacht } else if (10..<18).contains(h) { score[i] -= Punkte.nacht }
            if let g = e.gewohnheit {
                let drin = g.bett > g.auf ? (m >= g.bett || m < g.auf) : (m >= g.bett && m < g.auf)
                if drin { score[i] += Punkte.gewohnheit }
            }
            if let gn = e.guteNacht, d >= gn, d < gn.addingTimeInterval(12 * 3600) { score[i] += Punkte.guteNacht }
            if let w = e.wecker, d >= w { score[i] += Punkte.weckerAus }
        }

        // Schlaf-Minuten zu Läufen.
        var laeufe: [(von: Int, bis: Int)] = []
        var i = 0
        while i < n {
            if score[i] >= schwelle {
                var j = i
                while j < n, score[j] >= schwelle { j += 1 }
                laeufe.append((i, j))
                i = j
            } else {
                i += 1
            }
        }

        // Aufwachen: der erste Lauf von mindestens 1 h, der nach 5 Uhr endet, beendet die Nacht. Was danach
        // still liegt, ist Handy im Bett oder auf dem Tisch (Ahmed, 27.09.: Wecker 07:00 aus, 08:20 aufgestanden).
        // ponytail: feste 5-Uhr-Grenze; wer nach 5 aufwacht und weiterschläft, korrigiert in der Morgen-Karte.
        let fuenfUhr = kal.date(byAdding: .hour, value: 5, to: tagStart).map(minute) ?? Int.max
        if let wach = laeufe.first(where: { $0.bis >= fuenfUhr && $0.bis < n && $0.bis - $0.von >= 60 })?.bis {
            laeufe = laeufe.filter { $0.von < wach }
        }

        // Läufe mit kurzen Lücken zu Blöcken.
        struct Block { var von: Int; var bis: Int; var minuten: Int; var luecken: [(von: Int, bis: Int)] }
        var bloecke: [Block] = []
        for l in laeufe {
            if var letzter = bloecke.last, l.von - letzter.bis <= nachtLuecke {
                letzter.luecken.append((letzter.bis, l.von))
                letzter.bis = l.bis
                letzter.minuten += l.bis - l.von
                bloecke[bloecke.count - 1] = letzter
            } else {
                bloecke.append(Block(von: l.von, bis: l.bis, minuten: l.bis - l.von, luecken: []))
            }
        }

        // Die Nacht: endet am Aufwach-Tag, beginnt vor 6 Uhr, mindestens 3 h, der längste Block.
        let sechsUhr = kal.date(byAdding: .hour, value: 6, to: tagStart).map(minute) ?? Int.max
        let nacht = bloecke
            .filter { Datum.text(zeit($0.bis)) == e.tag && $0.von < sechsUhr && $0.minuten >= mindestNacht }
            .max { $0.minuten < $1.minuten }
        let nickerchen = bloecke
            .filter { b in b.minuten >= 20 && !(nacht.map { $0.von == b.von } ?? false) }
            .map { HealthLogik.SchlafIntervall(von: zeit($0.von), bis: zeit($0.bis)) }
        guard let nacht else {
            return PunkteErgebnis(nacht: nil, konfidenz: .niedrig, nickerchen: nickerchen, wachLuecken: [])
        }

        let schlafMinuten = (nacht.von..<nacht.bis).filter { score[$0] >= schwelle }
        let schnitt = schlafMinuten.isEmpty ? 0 : schlafMinuten.reduce(0.0) { $0 + score[$1] } / Double(schlafMinuten.count)
        let konfidenz: Konfidenz = schnitt >= 6 ? .hoch : (schnitt >= 5 ? .mittel : .niedrig)
        return PunkteErgebnis(
            nacht: (nacht.minuten, zeit(nacht.von), zeit(nacht.bis)),
            konfidenz: konfidenz,
            nickerchen: nickerchen,
            wachLuecken: nacht.luecken.map { HealthLogik.SchlafIntervall(von: zeit($0.von), bis: zeit($0.bis)) }
        )
    }
}
