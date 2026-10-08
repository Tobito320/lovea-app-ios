import CoreGraphics

/// Alle Dinge im Panorama, die immer zu sehen sind, als Rechtecke in Entwurfseinheiten (975 x 430).
/// Ein Eintrag je Ding; Test: keine zwei überlappen. Dinge, die nur zeitweise da sind (Paket, Feier, Regen), stehen nicht drin.
@MainActor
enum ZimmerPlatzLogik {
    static let weltBreite: CGFloat = 975
    static let weltHoehe: CGFloat = 430

    /// Kleiderschrank (Feature B), neben der Kleiderstange des Slots `.kleiderschrank`.
    static let kleiderschrank = CGRect(x: 868, y: 196, width: 90, height: 116)

    static var alle: [String: CGRect] {
        var r: [String: CGRect] = [:]
        let slots: [(String, ProfilDing)] = [
            ("spiegel", .spiegel), ("zettel", .zettel), ("regalDeko", .regalDeko), ("pinnwand", .pinnwand),
            ("pokale", .pokale), ("kleiderstange", .kleiderschrank), ("ziel", .ziel), ("kuehl", .kuehl),
            ("sofa", .sofa), ("fernseher", .fernseher), ("wandkalender", .kalender),
        ]
        for (name, ding) in slots { r[name] = ProfilSlots.welt(ding) }
        for (name, rect) in ZimmerObjekteEbene.flaechen { r[name] = rect }
        r["kleiderschrank"] = kleiderschrank
        r["termine"] = ZimmerSpielEbene.termineBrett
        r["radio"] = ZimmerAnlassEbene.radioFlaeche
        // Erweiterung für Rituale (D) und Erinnerung (E): hier eine Zeile je festes Ding anfügen.
        return r
    }
}
