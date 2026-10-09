import Foundation

/// Paar-Galerie: Fotos, Videos und behaltene Snaps aus dem Chat, nach Monat gruppiert. Reine Logik, getestet.
struct GalerieStueck: Identifiable, Equatable, Sendable {
    enum Art: Sendable { case foto, video }
    let id: String            // Medien-ID
    let nachrichtID: String
    let von: Person
    let zeit: Date
    let art: Art
    let snap: Bool
    let medium: ChatModell.MedienEintrag
}

enum GalerieFilter: String, CaseIterable, Identifiable, Sendable {
    case alle, fotos, snaps, videos
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .alle: "Alle"
        case .fotos: "Fotos"
        case .snaps: "Snaps"
        case .videos: "Videos"
        }
    }
}

struct GalerieMonat: Identifiable, Equatable, Sendable {
    let id: String            // "2026-10"
    let titel: String
    let stuecke: [GalerieStueck]
}

enum GalerieLogik {
    /// Alle Foto/Video-Medien. Snaps nur, wenn sie bleiben oder gespeichert wurden (flüchtige Snaps bleiben flüchtig).
    static func stuecke(aus nachrichten: [ChatModell.Nachricht]) -> [GalerieStueck] {
        var liste: [GalerieStueck] = []
        for n in nachrichten where !n.geloescht {
            if let snap = n.snap, !(snap.bleibt || n.snapGespeichert) { continue }
            for m in n.medien where m.typ == "foto" || m.typ == "video" {
                liste.append(GalerieStueck(id: m.id, nachrichtID: n.id, von: n.von, zeit: n.zeit,
                                           art: m.typ == "video" ? .video : .foto, snap: n.snap != nil, medium: m))
            }
        }
        return liste.sorted { $0.zeit > $1.zeit }
    }

    static func filtern(_ liste: [GalerieStueck], _ filter: GalerieFilter) -> [GalerieStueck] {
        switch filter {
        case .alle: liste
        case .fotos: liste.filter { $0.art == .foto && !$0.snap }
        case .snaps: liste.filter(\.snap)
        case .videos: liste.filter { $0.art == .video }
        }
    }

    /// Neueste Monate zuerst, innerhalb eines Monats neueste zuerst.
    static func monate(_ liste: [GalerieStueck], kalender: Calendar = Datum.kalender, sprache: Locale = Locale(identifier: "de_DE")) -> [GalerieMonat] {
        let sortiert = liste.sorted { $0.zeit > $1.zeit }
        var gruppen: [(schluessel: String, datum: Date, stuecke: [GalerieStueck])] = []
        for s in sortiert {
            let k = kalender.dateComponents([.year, .month], from: s.zeit)
            let schluessel = String(format: "%04d-%02d", k.year ?? 0, k.month ?? 0)
            if let i = gruppen.firstIndex(where: { $0.schluessel == schluessel }) {
                gruppen[i].stuecke.append(s)
            } else {
                gruppen.append((schluessel, s.zeit, [s]))
            }
        }
        var format = Date.FormatStyle().year().month(.wide).locale(sprache)
        format.timeZone = kalender.timeZone
        return gruppen.map { GalerieMonat(id: $0.schluessel, titel: $0.datum.formatted(format), stuecke: $0.stuecke) }
    }

    /// "Heute vor X": Stücke vom selben Kalendertag in früheren Jahren. Gibt es keine, vom selben Tag in früheren Monaten.
    /// Das Ergebnis ist der Rückblick mit der längsten Zeitspanne zuerst nicht nötig: nächster Treffer (jüngster) gewinnt.
    static func rueckblick(_ liste: [GalerieStueck], jetzt: Date = Date(), kalender: Calendar = Datum.kalender) -> (titel: String, stuecke: [GalerieStueck])? {
        let heute = kalender.dateComponents([.year, .month, .day], from: jetzt)
        func gleicherTag(_ d: Date) -> DateComponents { kalender.dateComponents([.year, .month, .day], from: d) }
        let frueher = liste.filter { s in
            let k = gleicherTag(s.zeit)
            return k.day == heute.day && ((k.year ?? 0) < (heute.year ?? 0) || ((k.year ?? 0) == (heute.year ?? 0) && (k.month ?? 0) < (heute.month ?? 0)))
        }
        guard let neuestes = frueher.max(by: { $0.zeit < $1.zeit }) else { return nil }
        let k = gleicherTag(neuestes.zeit)
        let jahre = (heute.year ?? 0) - (k.year ?? 0)
        let monate = jahre * 12 + (heute.month ?? 0) - (k.month ?? 0)
        let gleiche = frueher.filter { gleicherTag($0.zeit) == k }.sorted { $0.zeit < $1.zeit }
        return (rueckblickTitel(monate: monate), gleiche)
    }

    static func rueckblickTitel(monate: Int) -> String {
        if monate % 12 == 0 {
            let j = monate / 12
            return j == 1 ? "Heute vor einem Jahr" : "Heute vor \(j) Jahren"
        }
        return monate == 1 ? "Heute vor einem Monat" : "Heute vor \(monate) Monaten"
    }
}
