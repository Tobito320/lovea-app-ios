import SwiftUI

/// p59: Blumen im Zuhause. Bis zu 3 Sträuße stehen auf dem Schrank, einer in der Vase auf dem
/// Tisch; p68: bei Ahmed auf seinem Bord neben dem Bett. Gespeichert pro Person als `profil.straeusse` = `{schrank: [id], vase: id}` über denselben
/// Weg wie `profil.raeume` (`EinstellungenModell.setzen`), also ohne eigenen Sync. Lesen ist tolerant:
/// Unbekanntes, Doppeltes und alles über dem dritten Platz fällt weg.
struct ZimmerStraeusse: Equatable, Sendable {
    static let schrankPlaetze = 3
    static let schluessel = "profil.straeusse"

    /// In the order they were picked, left to right on the dresser.
    var schrank: [StraussArt] = []
    var vase: StraussArt?
    /// p70 (33): per bouquet (`StraussArt.rawValue`) the day it was put there, `yyyy-MM-dd`. Optional in the
    /// stored value, the old app ignores it. Missing means fresh.
    var frisch: [String: String] = [:]
    /// p70 (34): the ID of the last gift this person put in the vase, so it is not offered twice.
    var angenommen: String?

    var schrankVoll: Bool { schrank.count >= Self.schrankPlaetze }

    /// Takes the bouquet off the dresser, or puts it on when a place is free.
    mutating func schrankUmschalten(_ art: StraussArt, heute: String = Datum.text(Date())) {
        if let i = schrank.firstIndex(of: art) {
            schrank.remove(at: i)
        } else if !schrankVoll {
            schrank.append(art)
            frisch[art.rawValue] = frisch[art.rawValue] ?? heute
        }
        vergessen()
    }

    /// The same one again empties the vase.
    mutating func vaseUmschalten(_ art: StraussArt, heute: String = Datum.text(Date())) {
        vase = vase == art ? nil : art
        if vase != nil { frisch[art.rawValue] = frisch[art.rawValue] ?? heute }
        vergessen()
    }

    /// New water: every bouquet that stands there is fresh from `heute` on.
    mutating func auffrischen(heute: String = Datum.text(Date())) {
        for art in schrank + (vase.map { [$0] } ?? []) { frisch[art.rawValue] = heute }
    }

    /// A gift goes into the vase, fresh, and is marked as taken.
    mutating func annehmen(_ art: StraussArt, geschenk: String, heute: String = Datum.text(Date())) {
        vase = art
        frisch[art.rawValue] = heute
        angenommen = geschenk
    }

    /// Arrangements from before p70 have no dates: they start counting on the first look.
    @discardableResult
    mutating func stempelnFallsFehlt(heute: String = Datum.text(Date())) -> Bool {
        var geaendert = false
        for art in schrank + (vase.map { [$0] } ?? []) where frisch[art.rawValue] == nil {
            frisch[art.rawValue] = heute
            geaendert = true
        }
        return geaendert
    }

    /// Dates of bouquets that stand nowhere any more fall away.
    private mutating func vergessen() {
        let da = Set((schrank + (vase.map { [$0] } ?? [])).map(\.rawValue))
        frisch = frisch.filter { da.contains($0.key) }
    }

    /// Only the tired and wilted ones, by `StraussArt.rawValue`; fresh ones need no entry.
    func frische(heute: String) -> [String: StraussFrische] {
        var stufen: [String: StraussFrische] = [:]
        for (id, tag) in frisch {
            let stufe = StraussFrische.von(gestellt: tag, heute: heute)
            if stufe != .frisch { stufen[id] = stufe }
        }
        return stufen
    }

    /// Whether any bouquet on the dresser or in the vase is no longer fresh.
    func welkt(heute: String) -> Bool { !frische(heute: heute).isEmpty }

    static func lesen(_ wert: JSONValue?) -> ZimmerStraeusse {
        guard case .object(let o)? = wert else { return ZimmerStraeusse() }
        var z = ZimmerStraeusse()
        if case .array(let liste)? = o["schrank"] {
            for eintrag in liste {
                guard case .string(let id) = eintrag, let art = StraussArt(rawValue: id), !z.schrank.contains(art), !z.schrankVoll else { continue }
                z.schrank.append(art)
            }
        }
        if case .string(let id)? = o["vase"] { z.vase = StraussArt(rawValue: id) }
        if case .object(let tage)? = o["frisch"] {
            for (id, wert) in tage {
                if case .string(let tag) = wert, StraussArt(rawValue: id) != nil { z.frisch[id] = tag }
            }
        }
        if case .string(let id)? = o["angenommen"] { z.angenommen = id }
        return z
    }

    var json: JSONValue {
        var o: [String: JSONValue] = ["schrank": .array(schrank.map { .string($0.rawValue) })]
        if let vase { o["vase"] = .string(vase.rawValue) }
        if !frisch.isEmpty { o["frisch"] = .object(frisch.mapValues { .string($0) }) }
        if let angenommen { o["angenommen"] = .string(angenommen) }
        return .object(o)
    }

    /// What the home scene (p58) takes: the same choice as IDs for `StraussView`, with how fresh each one is.
    var fuerBuehne: ZuhauseStraeusse { fuerBuehne(heute: Datum.text(Date())) }

    func fuerBuehne(heute: String) -> ZuhauseStraeusse {
        ZuhauseStraeusse(schrank: schrank.map(\.rawValue), vase: vase?.rawValue, frische: frische(heute: heute))
    }
}

@MainActor
extension ZimmerStraeusse {
    /// Per person like `Zimmer.von`: each one's own value, the partner reads it.
    static func von(_ person: Person) -> ZimmerStraeusse {
        lesen(EinstellungenModell.shared.werte[person]?[schluessel])
    }

    func sichern() {
        EinstellungenModell.shared.setzen(Self.schluessel, json)
    }
}

/// The plain sheet: all five bouquets, tap to pick. On the dresser up to three (the rest dims when
/// it is full), in the vase one (tapping it again empties the vase).
struct StraeusseBlatt: View {
    enum Stelle: String, Identifiable {
        case schrank, vase
        var id: String { rawValue }
    }

    let stelle: Stelle
    @Binding var auswahl: ZimmerStraeusse
    /// p68: Ahmed's go on his board, Annika's on the dresser and the table.
    var person: Person = .annika
    @Environment(\.dismiss) private var dismiss
    /// p70: the gift sheet (34).
    @State private var schenken = false

    private var titel: String {
        switch (stelle, person) {
        case (.schrank, .ahmed): "Auf das Bord"
        case (.schrank, _): "Auf den Schrank"
        case (.vase, _): "In die Vase"
        }
    }
    private var hinweis: String {
        stelle == .schrank ? "Bis zu drei Sträuße, \(auswahl.schrank.count) von \(ZimmerStraeusse.schrankPlaetze) gewählt."
            : (person == .ahmed ? "Ein Strauß für die kleine Vase am Bord." : "Ein Strauß für die Vase auf dem Tisch.")
    }

    private func gewaehlt(_ art: StraussArt) -> Bool {
        stelle == .schrank ? auswahl.schrank.contains(art) : auswahl.vase == art
    }

    private func gesperrt(_ art: StraussArt) -> Bool {
        stelle == .schrank && auswahl.schrankVoll && !gewaehlt(art)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(hinweis)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if auswahl.welkt(heute: Datum.text(Date())) {
                        // p70 (33): new water makes every bouquet that stands there fresh again.
                        Button {
                            withAnimation(Feder.schnell) { auswahl.auffrischen() }
                            Haptik.erfolg()
                        } label: {
                            Label("Frisches Wasser", systemImage: "drop.fill")
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.loveaRose)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(StraussArt.allCases) { art in kachel(art) }
                    }
                }
                .padding()
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Verschenken") { schenken = true } }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .sheet(isPresented: $schenken) { StraussSchenkenBlatt() }
        }
        .presentationDetents([.medium, .large])
    }

    private func kachel(_ art: StraussArt) -> some View {
        let an = gewaehlt(art)
        return Button {
            withAnimation(Feder.schnell) {
                if stelle == .schrank { auswahl.schrankUmschalten(art) } else { auswahl.vaseUmschalten(art) }
            }
            Haptik.auswahl()
        } label: {
            VStack(spacing: 6) {
                StraussBild(art: art, breite: 112)
                Text(art.name).font(.caption.weight(.semibold)).foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(an ? Color.loveaRose : .clear, lineWidth: 3))
            .opacity(gesperrt(art) ? 0.4 : 1)
        }
        .buttonStyle(.federnd)
        .disabled(gesperrt(art))
        .accessibilityLabel(art.name)
        .accessibilityAddTraits(an ? .isSelected : [])
    }
}
