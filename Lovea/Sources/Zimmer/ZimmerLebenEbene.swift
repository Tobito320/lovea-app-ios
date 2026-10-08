import SwiftUI

/// The objects behind the figures. `stand` only for the render board; live it reads the models.
struct ZimmerLebenBild: View {
    let zimmer: Zimmer
    let person: Person
    let nacht: Bool
    var stand: ZimmerLebenStand?
    /// p65: `.panorama` puts every object at its slot in the wide world.
    var welt: ProfilWelt = .einzel

    /// In the panorama the plant has no window sill under it any more: a small wall shelf carries it.
    private static func pflanzenBrett(_ g: GraphicsContext) {
        let p = ZimmerLebenLayout.pflanze, holz = Pal.holz
        for x in [p.minX + 6, p.maxX - 6] {
            teil(g, Path { b in
                b.move(to: P(x - 3, p.maxY + 6))
                b.addLine(to: P(x + 3, p.maxY + 6))
                b.addLine(to: P(x - 3, p.maxY + 14))
                b.closeSubpath()
            }, holz.mal(0.85), 1.2)
        }
        teil(g, box(p.minX - 4, p.maxY, p.width + 8, 6, 2), holz, 1.8)
    }

    var body: some View {
        let s = stand ?? ZimmerLebenModell.stand(zimmer: zimmer, person: person)
        let welt = welt
        ZStack {
            Canvas { g, size in
                if let h = s.himmel { welt.zeichne(SzenenZeichnung.raum(g, size, welt: welt), .fenster) { ZimmerLebenZeichnung.fenster($0, h) } }
            }
            Canvas { g, size in
                let r = SzenenZeichnung.raum(g, size, welt: welt)
                for f in zimmer.rahmen where ZimmerLebenLayout.rahmen.indices.contains(f.slot) {
                    welt.zeichne(r, .rahmen(f.slot)) { SzenenZeichnung.rahmen($0, ZimmerLebenLayout.rahmen[f.slot]) }
                }
                welt.zeichne(r, .kalender) { ZimmerLebenZeichnung.kalender($0, s.termin) }
                welt.zeichne(r, .pokale) { ZimmerLebenZeichnung.pokale($0, s.pokale) }
                welt.zeichne(r, .pinnwand) { ZimmerLebenZeichnung.pinnwand($0, anzahl: s.polaroids.count) }
                welt.zeichne(r, .fernseher) { ZimmerLebenZeichnung.fernseher($0, s.film) }
                welt.zeichne(r, .pflanze) {
                    if welt == .panorama { Self.pflanzenBrett($0) }
                    ZimmerLebenZeichnung.pflanze($0, s.pflanze)
                }
                welt.zeichne(r, .ziel) { ZimmerLebenZeichnung.ziel($0, s.ziel) }
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
    /// p65: `.panorama` puts every tap area at its slot, at least 44 pt, and drops the partner's round
    /// window (the one avatar of the profile is the floating "online" chip).
    var welt: ProfilWelt = .einzel
    @State private var blatt: ZimmerBlatt?
    private static let rueckblickSchluessel = "lovea.zimmer.rueckblick"

    private struct Ziel: Identifiable {
        let name: String
        let rect: CGRect
        let ding: ProfilDing?
        let blatt: ZimmerBlatt
        var id: String { name }
    }

    /// The object's tap rect in this world: moved to its slot and, in the panorama, widened to `tippMinimum` pt.
    private func flaeche(_ r: CGRect, _ d: ProfilDing?, _ k: CGFloat) -> CGRect {
        guard welt == .panorama, let d else { return r }
        let v = welt.versatz(d), mindest = ProfilSlots.tippMinimum / k
        let b = max(r.width, mindest), h = max(r.height, mindest)
        return CGRect(x: r.midX + v.width - b / 2, y: r.midY + v.height - h / 2, width: b, height: h)
    }

    private func ziele(_ s: ZimmerLebenStand) -> [Ziel] {
        let heute = Datum.text(Date())
        // Later ones sit on top: the plant over the window glass.
        var z: [Ziel] = []
        if let h = s.himmel { z.append(Ziel(name: "Fenster", rect: ZimmerLebenLayout.fenster, ding: .fenster, blatt: .info(titel: "Draußen bei \(ZimmerLebenModell.wetterPerson.name)", text: h.text))) }
        z += [
            Ziel(name: "Kalender", rect: ZimmerLebenLayout.kalender, ding: .kalender, blatt: .kalender(s.termin?.tag ?? heute)),
            Ziel(name: "Pokale", rect: ZimmerLebenLayout.pokale, ding: .pokale, blatt: .pokale),
            Ziel(name: "Fernseher", rect: ZimmerLebenLayout.fernseher, ding: .fernseher, blatt: .film),
            Ziel(name: "Pflanze", rect: ZimmerLebenLayout.pflanze, ding: .pflanze, blatt: .info(titel: "Eure Pflanze", text: s.pflanze.text)),
            Ziel(name: "Ziel", rect: ZimmerLebenLayout.ziel, ding: .ziel, blatt: .ziel),
        ]
        if welt == .einzel {
            z.append(Ziel(name: "Andere", rect: ZimmerLebenLayout.andere, ding: nil, blatt: .info(titel: "\(person.partner.name) ist", text: s.andere.text)))
        }
        for r in zimmer.rahmen where ZimmerLebenLayout.rahmen.indices.contains(r.slot) {
            z.append(Ziel(name: "Rahmen \(r.slot)", rect: ZimmerLebenLayout.rahmen[r.slot], ding: .rahmen(r.slot), blatt: .foto(medienId: r.medienId, titel: "Eure Erinnerung")))
        }
        if s.polaroids.isEmpty {
            z.append(Ziel(name: "Pinnwand", rect: ZimmerLebenLayout.pinnwand, ding: .pinnwand, blatt: .info(titel: "Pinnwand", text: "Gespeicherte Snaps hängen hier als Polaroids.")))
        }
        for (i, p) in s.polaroids.enumerated() {
            let m = ZimmerLebenLayout.polaroid(i).mitte, g = ZimmerLebenLayout.polaroidGroesse
            let titel = p.zeit.formatted(Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone).day().month(.wide))
            z.append(Ziel(name: "Polaroid \(i)", rect: CGRect(x: m.x - g.width / 2, y: m.y - g.height / 2, width: g.width, height: g.height), ding: .pinnwand, blatt: .foto(medienId: p.medienId, titel: titel)))
        }
        return z
    }

    var body: some View {
        let s = stand ?? ZimmerLebenModell.stand(zimmer: zimmer, person: person)
        let welt = welt
        GeometryReader { geo in
            let k = geo.size.width / welt.breite
            let oben = geo.size.height - SzenenZeichnung.hoehe * k
            ZStack(alignment: .topLeading) {
                ForEach(zimmer.rahmen.filter { ZimmerLebenLayout.rahmen.indices.contains($0.slot) }, id: \.slot) { r in
                    let foto = ZimmerLebenLayout.rahmen[r.slot].insetBy(dx: 7, dy: 7)
                    let mitte = welt.ort(CGPoint(x: foto.midX, y: foto.midY), .rahmen(r.slot))
                    ProfilFoto(medienId: r.medienId)
                        .overlay(Color(red: 0.1, green: 0.12, blue: 0.23).opacity(Tageszeit.um(Date()).dunkel ? 0.45 : 0))
                        .frame(width: foto.width * k, height: foto.height * k)
                        .position(x: mitte.x * k, y: oben + mitte.y * k)
                }
                ForEach(Array(s.polaroids.enumerated()), id: \.element.id) { i, p in
                    let l = ZimmerLebenLayout.polaroid(i), foto = ZimmerLebenLayout.polaroidFoto, g = ZimmerLebenLayout.polaroidGroesse
                    let mitte = welt.ort(l.mitte, .pinnwand)
                    ProfilFoto(medienId: p.medienId)
                        .frame(width: foto.width * k, height: foto.height * k)
                        .offset(x: foto.midX * k, y: foto.midY * k)
                        .frame(width: g.width * k, height: g.height * k)
                        .rotationEffect(.degrees(l.grad))
                        .position(x: mitte.x * k, y: oben + mitte.y * k)
                }
                if welt == .einzel {
                    let a = ZimmerLebenLayout.andere
                    FigurView(FigurenModell.shared.aussehen(person.partner), zustand: s.andere.figur, groesse: a.width * k, animiert: false)
                        .frame(width: a.width * k, height: a.height * k)
                        .background(.thinMaterial, in: Circle())
                        .clipShape(Circle())
                        .position(x: a.midX * k, y: oben + a.midY * k)
                }
                ForEach(ziele(s)) { z in
                    let r = flaeche(z.rect, z.ding, k)
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: r.width * k, height: r.height * k)
                        .position(x: r.midX * k, y: oben + r.midY * k)
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
