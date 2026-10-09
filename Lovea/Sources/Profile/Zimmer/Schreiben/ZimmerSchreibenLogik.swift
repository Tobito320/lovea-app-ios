import Foundation

/// Unser Zimmer, Worker G: die reine Rechnung hinter Tagebuch, Kompliment-Glas, Zeitkapsel und Postkarten-Stempel.
/// Kein Zugriff auf Modelle, darum testbar. (Langsame Post liegt in `BriefeLogik`.)
enum ZimmerSchreibenLogik {
    // MARK: Tagebuch

    /// Ab so vielen Einträgen (beide Personen zusammen) wird es ein Buch.
    static let buchSchwelle = 365
    static let tagebuchPraefix = "zimmer.tagebuch."
    static let maxZeichen = 140

    /// Ein Schlüssel je Monat ("zimmer.tagebuch.2026-10"), damit kein Wert auf 365 Einträge anwächst.
    static func tagebuchSchluessel(tag: String) -> String { tagebuchPraefix + String(tag.prefix(7)) }

    static func eintragBereinigt(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return String(t.prefix(maxZeichen))
    }

    /// Zählt alle Tage mit Text über mehrere Monatswerte (je Person).
    static func anzahl(_ monate: [[String: String]]) -> Int {
        monate.reduce(0) { $0 + $1.values.filter { !$0.isEmpty }.count }
    }

    static func istBuch(anzahl: Int) -> Bool { anzahl >= buchSchwelle }

    struct Seite: Equatable, Identifiable {
        var tag: String
        var ahmed: String?
        var annika: String?
        var id: String { tag }
    }

    /// Eine Seite je Tag, älteste zuerst (Buch) oder neueste zuerst (Liste).
    static func seiten(ahmed: [String: String], annika: [String: String], neuesteZuerst: Bool = false) -> [Seite] {
        let tage = Set(ahmed.keys).union(annika.keys).sorted()
        let alle = tage.map { Seite(tag: $0, ahmed: ahmed[$0], annika: annika[$0]) }
        return neuesteZuerst ? alle.reversed() : alle
    }

    // MARK: Zeitkapsel

    /// Öffnet am selben Datum im nächsten Jahr, 0 Uhr Berliner Zeit.
    static func kapselOeffnung(geschrieben: Date) -> Date {
        let kal = Calendar.berlin
        let tag = kal.startOfDay(for: geschrieben)
        return kal.date(byAdding: .year, value: 1, to: tag) ?? tag.addingTimeInterval(365 * 86_400)
    }

    static func kapselOffen(oeffnung: Date, jetzt: Date = Date()) -> Bool { jetzt >= oeffnung }

    /// Tage bis zur Öffnung; 0 sobald offen.
    static func kapselTageBis(oeffnung: Date, jetzt: Date = Date()) -> Int {
        let kal = Calendar.berlin
        let tage = kal.dateComponents([.day], from: kal.startOfDay(for: jetzt), to: kal.startOfDay(for: oeffnung)).day ?? 0
        return max(0, tage)
    }

    // MARK: Postkarten-Stempel

    /// Stempeltext aus einem Ortsnamen, der schon in den Metadaten steht: Großbuchstaben, höchstens 14 Zeichen.
    static func stempel(ort: String?) -> String? {
        guard let t = ort?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return String(t.uppercased().prefix(14))
    }

    // MARK: Kompliment-Glas

    /// Tage seit 1.1.2026 (Berliner Kalender). Nie `hashValue`: der ist je Start zufällig.
    static func tageSeitBezug(_ datum: Date) -> Int {
        let kal = Calendar.berlin
        let start = kal.startOfDay(for: Datum.datum("2026-01-01"))
        return kal.dateComponents([.day], from: start, to: kal.startOfDay(for: datum)).day ?? 0
    }

    /// Dasselbe Kompliment für denselben Tag, auf jedem Gerät.
    static func kompliment(fuer datum: Date) -> String {
        let n = komplimente.count
        return komplimente[((tageSeitBezug(datum) % n) + n) % n]
    }

    static let komplimente: [String] = [
        "Dein Lachen macht jeden Raum heller.",
        "Ich bin so stolz auf dich.",
        "Mit dir fühlt sich alles leichter an.",
        "Du bist mein liebster Mensch.",
        "Du hast die schönsten Augen.",
        "Danke, dass es dich gibt.",
        "Du machst mich zu einem besseren Menschen.",
        "Ich liebe, wie du denkst.",
        "Du bist stärker, als du glaubst.",
        "Bei dir bin ich zu Hause.",
        "Dein Humor bringt mich jeden Tag zum Lachen.",
        "Ich vermisse dich schon, wenn du nur kurz weg bist.",
        "Du bist wunderschön, innen wie außen.",
        "Ich bin gern still neben dir.",
        "Du hast ein riesengroßes Herz.",
        "Mit dir wird jeder Alltag zum Abenteuer.",
        "Ich liebe deine Umarmungen.",
        "Du bist mein Lieblingsplatz.",
        "Du kannst alles schaffen, was du dir vornimmst.",
        "Ich bewundere deine Geduld.",
        "Du riechst einfach nach Zuhause.",
        "Ich mag, wie du mich ansiehst.",
        "Du bist mein Glück.",
        "Deine Stimme beruhigt mich sofort.",
        "Du bist so klug.",
        "Ich liebe unsere kleinen Rituale.",
        "Du siehst heute wieder umwerfend aus.",
        "Bei dir darf ich ganz ich selbst sein.",
        "Du bringst mich zum Strahlen.",
        "Ich bin so froh, dass ich dich gefunden habe.",
        "Du bist mutig.",
        "Ich liebe deine Art, die Welt zu sehen.",
        "Du bist das Beste, was mir passiert ist.",
        "Deine Nähe tut mir gut.",
        "Du machst selbst graue Tage bunt.",
        "Ich liebe dein Lächeln am Morgen.",
        "Du hörst mir immer zu.",
        "Du bist ein Mensch zum Festhalten.",
        "Ich bin dankbar für jeden gemeinsamen Moment.",
        "Du bist süß, wenn du dich konzentrierst.",
        "Mit dir kann ich über alles reden.",
        "Du gibst mir Ruhe.",
        "Ich glaube an dich.",
        "Du bist so fürsorglich.",
        "Ich liebe, wie du lachst, wenn du dich verschluckst.",
        "Du bist mein Ruhepol.",
        "Du hast ein wunderbares Herz.",
        "Mit dir ist alles schöner.",
        "Ich liebe es, mit dir Pläne zu machen.",
        "Du bist einfach einzigartig.",
        "Ich denke den ganzen Tag an dich.",
        "Du gibst mir Kraft.",
        "Du bist mein Lieblingsgeräusch am Abend.",
        "Ich mag dich genau so, wie du bist.",
        "Du hast so eine warme Art.",
        "Ich liebe deine kleinen Macken.",
        "Du bist mein Zuhause in Menschenform.",
        "Du bringst mich immer wieder zum Staunen.",
        "Ich freue mich so auf dich.",
        "Du bist großzügig und lieb.",
        "Du machst mich ruhig und glücklich zugleich.",
        "Ich liebe deine Hände.",
        "Du bist ein Geschenk.",
        "Mit dir lache ich am meisten.",
        "Du hast heute alles richtig gemacht.",
        "Ich bin gern dein Mensch.",
        "Du bist mein Sonnenschein.",
        "Du hast ein tolles Gespür für Menschen.",
        "Ich fühle mich bei dir sicher.",
        "Du bist fleißig und trotzdem so sanft.",
        "Ich liebe, wie du dich für Dinge begeisterst.",
        "Du bist mein Lieblingsmensch zum Quatschen.",
        "Du bist wirklich besonders.",
        "Ich bin so gern bei dir.",
        "Du hast ein Händchen für schöne Kleinigkeiten.",
        "Du machst mir jeden Tag Mut.",
        "Ich liebe, wie du für andere da bist.",
        "Du bist mein Wunsch, der wahr geworden ist.",
        "Mit dir fühle ich mich verstanden.",
        "Du bist ein Wunder.",
        "Ich mag deine ehrliche Art.",
        "Du bist so gut, wie du bist.",
        "Du bist mein Lieblingsanfang und mein Lieblingsende des Tages.",
        "Ich bin stolz, an deiner Seite zu sein.",
        "Du bist immer genug.",
        "Deine Ideen sind großartig.",
        "Ich liebe deine ruhige Stärke.",
        "Du machst unsere Welt kleiner und wärmer.",
        "Du hast mein Herz im Sturm erobert.",
        "Ich bin verliebt in dein Lachen.",
        "Du bist das Schönste an meinem Tag.",
        "Ich danke dir für deine Geduld mit mir.",
        "Du bist ein toller Mensch.",
        "Ich liebe dich mehr als gestern.",
        "Du bist mein bester Freund und mein Herz.",
        "Mit dir könnte ich überall leben.",
        "Du bist liebenswert, jeden Tag.",
        "Ich freue mich auf alles, was wir noch erleben.",
        "Du bist mein Fels.",
        "Du hast mich heute wieder zum Lächeln gebracht.",
        "Ich bin unendlich dankbar für dich.",
        "Du bist mein kleines großes Glück.",
        "Ich liebe dich, einfach so.",
    ]
}
