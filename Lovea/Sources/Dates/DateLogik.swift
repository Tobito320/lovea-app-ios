import Foundation

enum DateStatus: String, Sendable, CaseIterable { case alle, offen, erledigt }

struct DateFilter: Equatable, Sendable {
    var kategorie: DateKategorie?
    var status: DateStatus = .alle
    /// Ortsname, ohne Beachtung von Groß/Klein und Akzenten. nil = kein Ortsfilter.
    var ort: String?
    var suche: String = ""
}

enum DateLinkArt: Sendable, Equatable { case karte, tiktok, instagram, andere }

enum DateLogik {
    // MARK: - Filter, Sortierung, Fortschritt, Suche

    static func filtern(_ ideen: [DateIdee], _ filter: DateFilter = DateFilter()) -> [DateIdee] {
        let ortGesucht = filter.ort.map(falten)
        let woerter = falten(filter.suche).split(separator: " ").map(String.init)
        return sortiert(ideen.filter { idee in
            guard !idee.geloescht else { return false }
            if let k = filter.kategorie, idee.kategorie != k { return false }
            switch filter.status {
            case .alle: break
            case .offen: if idee.erledigt { return false }
            case .erledigt: if !idee.erledigt { return false }
            }
            if let gesucht = ortGesucht, idee.ort.map({ falten($0.name) }) != gesucht { return false }
            return woerter.isEmpty || passt(idee, woerter: woerter)
        })
    }

    /// Offene zuerst nach Titel, dann Erledigte (neueste zuerst, ohne Datum zuletzt), je nach Titel.
    static func sortiert(_ ideen: [DateIdee]) -> [DateIdee] {
        ideen.sorted { a, b in
            if a.erledigt != b.erledigt { return !a.erledigt }
            if a.erledigt, a.erledigtAm != b.erledigtAm { return (a.erledigtAm ?? "") > (b.erledigtAm ?? "") }
            let vergleich = a.titel.localizedStandardCompare(b.titel)
            return vergleich == .orderedSame ? a.id < b.id : vergleich == .orderedAscending
        }
    }

    /// Ohne gelöschte Ideen.
    static func fortschritt(_ ideen: [DateIdee]) -> (erledigt: Int, gesamt: Int, anteil: Double) {
        let sichtbar = ideen.filter { !$0.geloescht }
        let erledigt = sichtbar.filter(\.erledigt).count
        return (erledigt, sichtbar.count, sichtbar.isEmpty ? 0 : Double(erledigt) / Double(sichtbar.count))
    }

    /// Alle Wörter der Suche müssen irgendwo in Titel, Notiz, Ortsname, Kategorie oder Link vorkommen.
    private static func passt(_ idee: DateIdee, woerter: [String]) -> Bool {
        var teile = [idee.titel, idee.kategorie.titel]
        teile += [idee.notiz, idee.ort?.name, idee.ort?.adresse].compactMap { $0 }
        for link in idee.links { teile += [link.titel, domain(link.url)].compactMap { $0 } }
        let heu = falten(teile.joined(separator: " "))
        return woerter.allSatisfy { heu.contains($0) }
    }

    /// Verschiedene Ortsnamen der sichtbaren Ideen, für die Ortsfilter-Leiste.
    static func ortNamen(_ ideen: [DateIdee]) -> [String] {
        var gesehen: Set<String> = []
        return ideen.filter { !$0.geloescht }.compactMap { $0.ort?.name }
            .filter { gesehen.insert(falten($0)).inserted }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func hatKoordinate(_ ort: PunktOrt) -> Bool { ort.lat != 0 || ort.lon != 0 }

    static func falten(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Löschen und Rückgängig (nur Flag, neuer Zeitstempel)

    static func geloescht(_ idee: DateIdee, von: Person, jetzt: Date) -> DateIdee {
        geaendert(idee, von: von, jetzt: jetzt) { $0.geloescht = true }
    }

    static func wiederhergestellt(_ idee: DateIdee, von: Person, jetzt: Date) -> DateIdee {
        geaendert(idee, von: von, jetzt: jetzt) { $0.geloescht = false }
    }

    /// Abhaken setzt das Datum, Zurücknehmen löscht es.
    static func abgehakt(_ idee: DateIdee, erledigt: Bool, von: Person, jetzt: Date, heute: String) -> DateIdee {
        geaendert(idee, von: von, jetzt: jetzt) {
            $0.erledigt = erledigt
            $0.erledigtAm = erledigt ? heute : nil
        }
    }

    /// Der Zeitstempel liegt immer hinter dem alten, auch wenn die Uhr zurückgeht. Sonst verlöre die Änderung gegen die alte Fassung.
    static func geaendert(_ idee: DateIdee, von: Person, jetzt: Date, _ aenderung: (inout DateIdee) -> Void) -> DateIdee {
        var neu = idee
        aenderung(&neu)
        neu.geaendert = max(jetzt, idee.geaendert.addingTimeInterval(0.001))
        neu.von = von
        return neu
    }

    // MARK: - Last-writer-wins

    /// Die neuere Fassung gewinnt, bei gleichem Zeitstempel die später angewendete (Faltung läuft nach `seq`).
    static func zusammenfuehren(_ ideen: inout [String: DateIdee], _ neu: DateIdee) {
        if let alt = ideen[neu.id], alt.geaendert > neu.geaendert { return }
        ideen[neu.id] = neu
    }

    // MARK: - Links

    /// Nimmt eine getippte oder eingefügte Adresse. Ohne Schema wird https davor gesetzt. Nur http und https mit Domain, sonst nil.
    static func link(aus text: String, titel: String? = nil, id: String = UUID().uuidString) -> DateLink? {
        guard let url = normalisiert(text) else { return nil }
        let t = titel?.trimmingCharacters(in: .whitespacesAndNewlines)
        return DateLink(id: id, url: url.absoluteString, titel: (t?.isEmpty ?? true) ? nil : t)
    }

    static func normalisiert(_ text: String) -> URL? {
        let roh = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roh.isEmpty, roh.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        var kandidat = roh
        if let trenner = roh.range(of: "://") {
            let name = roh[..<trenner.lowerBound].lowercased()
            guard name == "http" || name == "https" else { return nil }
        } else {
            let klein = roh.lowercased()
            let fremd = ["javascript:", "data:", "mailto:", "tel:", "sms:", "file:", "about:", "blob:"]
            guard !fremd.contains(where: { klein.hasPrefix($0) }) else { return nil }
            kandidat = "https://" + roh
        }
        guard let teile = URLComponents(string: kandidat), let schema = teile.scheme?.lowercased(),
              schema == "http" || schema == "https", let host = teile.host, host.contains("."),
              !host.hasPrefix("."), !host.hasSuffix("."), let url = teile.url else { return nil }
        return url
    }

    /// Nur für gespeicherte Links, die geöffnet werden: auch Ops vom Partner laufen durch die Prüfung.
    static func oeffnenURL(_ link: DateLink) -> URL? { normalisiert(link.url) }

    /// Domain für den Chip, ohne `www.` und `m.`.
    static func domain(_ url: String) -> String? {
        guard let host = normalisiert(url)?.host?.lowercased() else { return nil }
        for vorsatz in ["www.", "m."] where host.hasPrefix(vorsatz) { return String(host.dropFirst(vorsatz.count)) }
        return host
    }

    static func chipText(_ link: DateLink) -> String {
        if let titel = link.titel, !titel.isEmpty { return titel }
        return domain(link.url) ?? link.url
    }

    static func linkArt(_ url: String) -> DateLinkArt {
        guard let u = normalisiert(url), let host = u.host?.lowercased() else { return .andere }
        let pfad = u.path.lowercased()
        func ist(_ d: String) -> Bool { host == d || host.hasSuffix("." + d) }
        if ist("tiktok.com") { return .tiktok }
        if ist("instagram.com") || host == "instagr.am" { return .instagram }
        if host == "maps.app.goo.gl" || host == "maps.google.com" || host.hasPrefix("maps.google.") { return .karte }
        if host == "goo.gl", pfad.hasPrefix("/maps") { return .karte }
        let google = host.range(of: #"(^|\.)google\.[a-z]{2,3}(\.[a-z]{2})?$"#, options: .regularExpression) != nil
        if google, pfad.hasPrefix("/maps") { return .karte }
        return .andere
    }

    // MARK: - IDs

    /// `Frühstücken zusammen` -> `fruehstuecken-zusammen`.
    static func slug(_ text: String) -> String {
        var s = text.lowercased()
        for (von, nach) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] { s = s.replacingOccurrences(of: von, with: nach) }
        s = s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de_DE"))
        let teile = s.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
        return teile.joined(separator: "-")
    }
}
