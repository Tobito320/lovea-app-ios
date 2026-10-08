import SwiftUI

/// The objects behind the figures. `stand` only for the render board; live it reads the models.
struct ZimmerLebenBild: View {
    let zimmer: Zimmer
    let person: Person
    let nacht: Bool
    var stand: ZimmerLebenStand?

    var body: some View {
        let s = stand ?? ZimmerLebenModell.stand(zimmer: zimmer, person: person)
        ZStack {
            Canvas { g, size in
                if let h = s.himmel { ZimmerLebenZeichnung.fenster(SzenenZeichnung.raum(g, size), h) }
            }
            Canvas { g, size in
                let r = SzenenZeichnung.raum(g, size)
                for f in zimmer.rahmen where ZimmerLebenLayout.rahmen.indices.contains(f.slot) { SzenenZeichnung.rahmen(r, ZimmerLebenLayout.rahmen[f.slot]) }
                ZimmerLebenZeichnung.kalender(r, s.termin)
                ZimmerLebenZeichnung.pokale(r, s.pokale)
                ZimmerLebenZeichnung.pinnwand(r, anzahl: s.polaroids.count)
                ZimmerLebenZeichnung.fernseher(r, s.film)
                ZimmerLebenZeichnung.pflanze(r, s.pflanze)
                ZimmerLebenZeichnung.ziel(r, s.ziel)
            }
            // The room dims at night except the window.
            .colorMultiply(nacht ? Color(white: 0.72) : .white)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The photos on the board, the other person's figure and the tap targets, above the figures but
/// only as big as the objects themselves. Sheets open from here.
struct ZimmerLebenTippen: View {
    let zimmer: Zimmer
    let person: Person
    var stand: ZimmerLebenStand?
    @State private var blatt: ZimmerBlatt?
    private static let rueckblickSchluessel = "lovea.zimmer.rueckblick"

    private struct Ziel: Identifiable {
        let name: String
        let rect: CGRect
        let blatt: ZimmerBlatt
        var id: String { name }
    }

    private func ziele(_ s: ZimmerLebenStand) -> [Ziel] {
        let heute = Datum.text(Date())
        // Later ones sit on top: the plant over the window glass.
        var z: [Ziel] = []
        if let h = s.himmel { z.append(Ziel(name: "Fenster", rect: ZimmerLebenLayout.fenster, blatt: .info(titel: "Draußen bei \(ZimmerLebenModell.wetterPerson.name)", text: h.text))) }
        z += [
            Ziel(name: "Kalender", rect: ZimmerLebenLayout.kalender, blatt: .kalender(s.termin?.tag ?? heute)),
            Ziel(name: "Pokale", rect: ZimmerLebenLayout.pokale, blatt: .pokale),
            Ziel(name: "Fernseher", rect: ZimmerLebenLayout.fernseher, blatt: .film),
            Ziel(name: "Pflanze", rect: ZimmerLebenLayout.pflanze, blatt: .info(titel: "Eure Pflanze", text: s.pflanze.text)),
            Ziel(name: "Ziel", rect: ZimmerLebenLayout.ziel, blatt: .ziel),
            Ziel(name: "Andere", rect: ZimmerLebenLayout.andere, blatt: .info(titel: "\(person.partner.name) ist", text: s.andere.text)),
        ]
        for r in zimmer.rahmen where ZimmerLebenLayout.rahmen.indices.contains(r.slot) {
            z.append(Ziel(name: "Rahmen \(r.slot)", rect: ZimmerLebenLayout.rahmen[r.slot], blatt: .foto(medienId: r.medienId, titel: "Eure Erinnerung")))
        }
        if s.polaroids.isEmpty {
            z.append(Ziel(name: "Pinnwand", rect: ZimmerLebenLayout.pinnwand, blatt: .info(titel: "Pinnwand", text: "Gespeicherte Snaps hängen hier als Polaroids.")))
        }
        for (i, p) in s.polaroids.enumerated() {
            let m = ZimmerLebenLayout.polaroid(i).mitte, g = ZimmerLebenLayout.polaroidGroesse
            let titel = p.zeit.formatted(Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone).day().month(.wide))
            z.append(Ziel(name: "Polaroid \(i)", rect: CGRect(x: m.x - g.width / 2, y: m.y - g.height / 2, width: g.width, height: g.height), blatt: .foto(medienId: p.medienId, titel: titel)))
        }
        return z
    }

    var body: some View {
        let s = stand ?? ZimmerLebenModell.stand(zimmer: zimmer, person: person)
        GeometryReader { geo in
            let k = geo.size.width / SzenenZeichnung.breite
            let oben = geo.size.height - SzenenZeichnung.hoehe * k
            ZStack(alignment: .topLeading) {
                ForEach(zimmer.rahmen.filter { ZimmerLebenLayout.rahmen.indices.contains($0.slot) }, id: \.slot) { r in
                    let foto = ZimmerLebenLayout.rahmen[r.slot].insetBy(dx: 7, dy: 7)
                    ProfilFoto(medienId: r.medienId)
                        .overlay(Color(red: 0.1, green: 0.12, blue: 0.23).opacity(Tageszeit.um(Date()).dunkel ? 0.45 : 0))
                        .frame(width: foto.width * k, height: foto.height * k)
                        .position(x: foto.midX * k, y: oben + foto.midY * k)
                }
                ForEach(Array(s.polaroids.enumerated()), id: \.element.id) { i, p in
                    let l = ZimmerLebenLayout.polaroid(i), foto = ZimmerLebenLayout.polaroidFoto, g = ZimmerLebenLayout.polaroidGroesse
                    ProfilFoto(medienId: p.medienId)
                        .frame(width: foto.width * k, height: foto.height * k)
                        .offset(x: foto.midX * k, y: foto.midY * k)
                        .frame(width: g.width * k, height: g.height * k)
                        .rotationEffect(.degrees(l.grad))
                        .position(x: l.mitte.x * k, y: oben + l.mitte.y * k)
                }
                let a = ZimmerLebenLayout.andere
                FigurView(FigurenModell.shared.aussehen(person.partner), zustand: s.andere.figur, groesse: a.width * k, animiert: false)
                    .frame(width: a.width * k, height: a.height * k)
                    .background(.thinMaterial, in: Circle())
                    .clipShape(Circle())
                    .position(x: a.midX * k, y: oben + a.midY * k)
                ForEach(ziele(s)) { z in
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: z.rect.width * k, height: z.rect.height * k)
                        .position(x: z.rect.midX * k, y: oben + z.rect.midY * k)
                        .onTapGesture { blatt = z.blatt }
                        .accessibilityElement()
                        .accessibilityLabel(z.name)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .sheet(item: $blatt) { ZimmerBlattInhalt(blatt: $0) }
        .task { rueckblick() }
    }

    /// Once a day "Heute vor …" (`HeuteVorLogik`: a month, three months, a year), when that day has a photo.
    private func rueckblick() {
        let heute = Datum.text(Date())
        guard stand == nil, UserDefaults.standard.string(forKey: Self.rueckblickSchluessel) != heute,
              let treffer = HeuteVorLogik.auswahl(ChatModell.shared.nachrichten),
              let foto = treffer.nachricht.medien.first(where: { $0.typ == "foto" }) else { return }
        UserDefaults.standard.set(heute, forKey: Self.rueckblickSchluessel)
        blatt = .foto(medienId: foto.id, titel: "Heute: \(treffer.zeitraum.titel)")
    }
}
