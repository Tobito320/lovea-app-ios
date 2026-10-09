import Foundation

// Health-Coach, Darstellung: reine Textlogik für den Chat. Das Modell antwortet mit Absätzen, Listen, Nummern und
// gelegentlich einer Überschrift. Hier wird das Zeile für Zeile erkannt, damit der Chat sie als Antwort ohne Blase
// setzen kann. Nichts hier liest Modelle oder die Uhr.

enum CoachText {
    enum Art: Equatable, Sendable {
        case absatz
        case ueberschrift
        case punkt
        case nummer(Int)
        /// `- [ ] Kniebeugen 3x8`: abhakbar, der Haken liegt nur auf diesem Gerät.
        case aufgabe
        /// Markdown-Tabelle: Kopfzeile plus Zeilen, jede Zeile hat genauso viele Zellen wie der Kopf.
        case tabelle(kopf: [String], zeilen: [[String]])
    }

    /// Eine Zeile der Antwort. `text` enthält noch Inline-Markdown (**fett**, *kursiv*), siehe `inline`.
    /// Bei einer Tabelle ist `text` leer, die Zellen stehen in der Art.
    struct Zeile: Equatable, Sendable {
        let art: Art
        let text: String
    }

    /// Leere Zeilen und Trennlinien (`---`) fallen weg, der Chat setzt den Abstand selbst. Aufeinanderfolgende
    /// Tabellenzeilen werden zu einer Tabelle zusammengefasst.
    static func zeilen(_ roh: String) -> [Zeile] {
        var ergebnis: [Zeile] = []
        var block: [(roh: String, zellen: [String])] = []
        for teil in roh.split(whereSeparator: \.isNewline) {
            let text = String(teil)
            if let zellen = tabellenZellen(text) {
                block.append((roh: text, zellen: zellen))
                continue
            }
            ergebnis += tabellenZeilen(block)
            block = []
            if let einzel = zeile(text) { ergebnis.append(einzel) }
        }
        ergebnis += tabellenZeilen(block)
        return ergebnis
    }

    /// Zeilenumbrüche bleiben, ohne gültiges Markdown gilt der Rohtext.
    static func inline(_ text: String) -> AttributedString {
        let optionen = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: optionen)) ?? AttributedString(text)
    }

    /// Eine Trennzeile über der Nachricht: bei der ersten, an einem neuen Tag oder nach mehr als 6 Stunden Pause.
    static func trennerNoetig(vorher: Date?, jetzt: Date, kalender: Calendar) -> Bool {
        guard let vorher else { return true }
        return !kalender.isDate(vorher, inSameDayAs: jetzt) || jetzt.timeIntervalSince(vorher) > 6 * 3600
    }

    static func begruessung(stunde: Int) -> String {
        switch stunde {
        case 5..<11: "Guten Morgen"
        case 18..<23: "Guten Abend"
        default: "Hallo"
        }
    }

    // MARK: - Tageszeit (Farbe des Orbs)

    enum Tageszeit: Equatable, Sendable { case morgen, tag, abend, nacht }

    static func tageszeit(stunde: Int) -> Tageszeit {
        switch stunde {
        case 5..<11: .morgen
        case 11..<18: .tag
        case 18..<23: .abend
        default: .nacht
        }
    }

    // MARK: - Wort für Wort

    /// Gesamtdauer des Einblendens ist etwa 2,5 s; jedes Wort braucht mindestens 15 ms, höchstens 50 ms.
    static func wortSchritt(gesamt: Int) -> TimeInterval {
        guard gesamt > 0 else { return 0 }
        return min(0.05, max(0.015, 2.5 / Double(gesamt)))
    }

    static func einblendDauer(gesamt: Int) -> TimeInterval { Double(max(gesamt, 0)) * wortSchritt(gesamt: gesamt) }

    /// Sehr lange Antworten (über 250 Wörter) erscheinen auf einmal, sonst dauert das Einblenden zu lang.
    static func einblendenLohnt(gesamt: Int) -> Bool { (1...250).contains(gesamt) }

    /// Die Zeitpunkte, zu denen ein neues Wort erscheint: `start` und dann je ein Schritt bis zum Ende. Danach
    /// zeichnet der Chat nichts mehr neu, es läuft kein Timer.
    static func einblendTermine(start: Date, gesamt: Int) -> [Date] {
        guard gesamt > 0 else { return [start] }
        let schritt = wortSchritt(gesamt: gesamt)
        return (0...gesamt).map { start.addingTimeInterval(Double($0) * schritt) }
    }

    /// Wie viele Wörter nach `vergangen` Sekunden zu sehen sind (0 bis `gesamt`).
    static func sichtbareWoerter(vergangen: TimeInterval, gesamt: Int) -> Int {
        guard gesamt > 0, vergangen > 0 else { return 0 }
        return min(gesamt, Int(vergangen / wortSchritt(gesamt: gesamt)))
    }

    static func woerter(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    /// Länge in Zeichen bis einschließlich dem `woerter`-ten Wort. Mehr Wörter als vorhanden: der ganze Text.
    static func praefixLaenge(_ text: String, woerter: Int) -> Int {
        guard woerter > 0 else { return 0 }
        var gezaehlt = 0
        var imWort = false
        var laenge = 0
        for zeichen in text {
            if zeichen.isWhitespace {
                if imWort {
                    gezaehlt += 1
                    imWort = false
                    if gezaehlt == woerter { return laenge }
                }
            } else {
                imWort = true
            }
            laenge += 1
        }
        return laenge
    }

    /// Text bis zum `woerter`-ten Wort. Ein offenes `**` wird geschlossen, damit beim Einblenden kein Sternchen aufblitzt.
    static func gekuerzt(_ text: String, woerter: Int) -> String {
        let laenge = praefixLaenge(text, woerter: woerter)
        guard laenge < text.count else { return text }
        let kopf = String(text.prefix(laenge))
        let offen = (kopf.components(separatedBy: "**").count - 1) % 2 == 1
        return offen ? kopf + "**" : kopf
    }

    /// Eine Tabelle zählt als ein Wort: sie erscheint auf einmal.
    static func wortAnzahl(_ zeile: Zeile) -> Int {
        if case .tabelle = zeile.art { return 1 }
        return woerter(zeile.text)
    }

    static func gesamtWoerter(_ zeilen: [Zeile]) -> Int { zeilen.reduce(0) { $0 + wortAnzahl($1) } }

    /// Die ersten `woerter` Wörter der ganzen Antwort; die Zeile, in der das Limit fällt, wird gekürzt, alle danach fehlen.
    static func eingeblendet(_ zeilen: [Zeile], woerter limit: Int) -> [Zeile] {
        var rest = limit
        var ergebnis: [Zeile] = []
        for zeile in zeilen {
            guard rest > 0 else { break }
            let n = wortAnzahl(zeile)
            if n <= rest {
                ergebnis.append(zeile)
                rest -= n
            } else {
                ergebnis.append(Zeile(art: zeile.art, text: gekuerzt(zeile.text, woerter: rest)))
                break
            }
        }
        return ergebnis
    }

    // MARK: - Zahlen mit Einheit

    private static let einheiten: Set<String> = [
        "kcal", "kg", "g", "h", "min", "schritte", "schritt", "sätze", "satz", "wdh", "km", "ml", "cm",
        "tage", "tagen", "stunden", "std", "wochen", "prozent",
    ]

    /// Zeichenbereiche (als Offsets in `Array(text)`) für Zahlen mit Einheit: "8.200 Schritte", "120 g", "85 %".
    /// Zahlen ohne Einheit (Jahre, Daten wie "12.10.") bleiben unberührt.
    static func zahlBereiche(_ text: String) -> [Range<Int>] {
        let z = Array(text)
        var ergebnis: [Range<Int>] = []
        var i = 0
        while i < z.count {
            guard ziffer(z[i]), i == 0 || !(z[i - 1].isLetter || ziffer(z[i - 1])) else { i += 1; continue }
            var j = i
            while j < z.count, ziffer(z[j]) { j += 1 }
            while j + 1 < z.count, z[j] == "." || z[j] == ",", ziffer(z[j + 1]) {
                j += 1
                while j < z.count, ziffer(z[j]) { j += 1 }
            }
            var k = j
            if k < z.count, z[k] == " " { k += 1 }
            if k < z.count, z[k] == "%" {
                ergebnis.append(i..<(k + 1))
                i = k + 1
                continue
            }
            var m = k
            while m < z.count, z[m].isLetter { m += 1 }
            if m > k, einheiten.contains(String(z[k..<m]).lowercased()) {
                ergebnis.append(i..<m)
                i = m
            } else {
                i = j
            }
        }
        return ergebnis
    }

    private static func ziffer(_ zeichen: Character) -> Bool { zeichen.isASCII && zeichen.isNumber }

    // MARK: - Vorschau

    /// Eine Zeile ohne Markdown und ohne Marker, für Suchtreffer und Merkliste.
    static func vorschau(_ roh: String, maximal: Int = 90) -> String {
        let text = CoachMarker.zerlegen(roh).text
        let flach = zeilen(text).map { zeile -> String in
            switch zeile.art {
            case .tabelle(let kopf, _): kopf.joined(separator: " ")
            default: zeile.text
            }
        }.joined(separator: " ")
        let ohne = flach.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        guard ohne.count > maximal else { return ohne }
        return String(ohne.prefix(maximal)).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - Eine Zeile

    private static let punktMarken = ["- ", "* ", "• "]

    private static func zeile(_ roh: String) -> Zeile? {
        let text = roh.trimmingCharacters(in: .whitespaces)
        if text.isEmpty || istTrennlinie(text) { return nil }

        let raute = text.prefix { $0 == "#" }
        if (1...6).contains(raute.count), text.dropFirst(raute.count).first == " " {
            return Zeile(art: .ueberschrift, text: rest(text, nach: raute.count + 1))
        }

        if let marke = punktMarken.first(where: { text.hasPrefix($0) }) {
            let danach = rest(text, nach: marke.count)
            for kasten in ["[ ] ", "[x] ", "[X] "] where danach.hasPrefix(kasten) {
                return Zeile(art: .aufgabe, text: rest(danach, nach: kasten.count))
            }
            return Zeile(art: .punkt, text: danach)
        }

        let ziffern = text.prefix { $0.isASCII && $0.isNumber }
        let danach = text.dropFirst(ziffern.count)
        if (1...3).contains(ziffern.count), let nummer = Int(ziffern),
           let zeichen = danach.first, zeichen == "." || zeichen == ")", danach.dropFirst().first == " " {
            return Zeile(art: .nummer(nummer), text: rest(text, nach: ziffern.count + 2))
        }

        return Zeile(art: .absatz, text: text)
    }

    private static func rest(_ text: String, nach n: Int) -> String {
        String(text.dropFirst(n)).trimmingCharacters(in: .whitespaces)
    }

    private static func istTrennlinie(_ text: String) -> Bool {
        text.count >= 3 && text.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
    }

    // MARK: - Tabellen

    /// Zellen einer Zeile `| a | b |`, sonst nil. Die Zeile muss mit `|` beginnen und mindestens zwei davon haben.
    private static func tabellenZellen(_ roh: String) -> [String]? {
        let text = roh.trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix("|"), text.filter({ $0 == "|" }).count >= 2 else { return nil }
        var innen = String(text.dropFirst())
        if innen.hasSuffix("|") { innen = String(innen.dropLast()) }
        return innen.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func istTabellenTrenner(_ zellen: [String]) -> Bool {
        !zellen.isEmpty && zellen.allSatisfy { zelle in
            zelle.contains("-") && zelle.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    /// Kopf, Trennzeile, mindestens eine Datenzeile: eine Tabelle. Sonst zählen die Zeilen einzeln wie Fließtext.
    private static func tabellenZeilen(_ block: [(roh: String, zellen: [String])]) -> [Zeile] {
        guard !block.isEmpty else { return [] }
        guard block.count >= 3, istTabellenTrenner(block[1].zellen), !block[0].zellen.isEmpty else {
            return block.compactMap { zeile($0.roh) }
        }
        let kopf = block[0].zellen
        let daten = block.dropFirst(2).map { eintrag -> [String] in
            let zellen = Array(eintrag.zellen.prefix(kopf.count))
            return zellen + Array(repeating: "", count: kopf.count - zellen.count)
        }
        return [Zeile(art: .tabelle(kopf: kopf, zeilen: daten), text: "")]
    }
}
