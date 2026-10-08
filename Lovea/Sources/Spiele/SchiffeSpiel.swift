import SwiftUI

// MARK: - Schiffe versenken (rundenweise, über Tage spielbar)
//
// Flotten und Schüsse sind gespeicherte Ops (`spiel.flotte`, `spiel.schuss`). Der Stand wird bei
// jedem Rendern aus ihnen berechnet, deshalb übersteht das Spiel Neustarts und Pausen.

struct SchiffeSpiel: View {
    let k: SpielKontext
    @State private var entwurf: [Schiff] = Schiffe.zufaellig()
    @State private var gewuerfelt = 0
    @State private var ansicht = Ansicht.angriff

    private enum Ansicht: Hashable {
        case angriff
        case flotte
    }

    // MARK: Daten

    private var meineFlotte: [Schiff]? { k.spiel.flotten[k.partie]?[k.ich] }

    private var flotten: [Person: [Schiff]] { k.spiel.flotten[k.partie] ?? [:] }

    private var schussListen: [Person: [Int]] {
        let roh = k.spiel.schuesse[k.partie] ?? [:]
        var d: [Person: [Int]] = [:]
        for p in [Person.ahmed, Person.annika] {
            d[p] = Schiffe.liste(aus: roh[p] ?? [:])
        }
        return d
    }

    private var stand: Schiffe.Stand {
        Schiffe.stand(starter: k.starter, flotten: flotten, schuesse: schussListen)
    }

    var ende: PartieEnde? {
        guard let w = stand.sieger else { return nil }
        var p = SpielPunkte()
        p[w] = 1
        return PartieEnde(punkte: p, sieger: w, text: "Alle Schiffe versenkt.")
    }

    // MARK: Ansicht

    var body: some View {
        let s = stand
        return VStack(spacing: 14) {
            Text(status(s))
                .font(.headline)
                .foregroundStyle(s.amZug == k.ich ? Color.loveaRose : .secondary)
                .multilineTextAlignment(.center)
            if meineFlotte == nil {
                aufbau
            } else if !s.bereit {
                warten
            } else {
                gefecht(s)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .sensoryFeedback(.impact(weight: .medium), trigger: gewuerfelt)
        .sensoryFeedback(.success, trigger: meineFlotte != nil)
        .sensoryFeedback(trigger: s.verlauf.count) { alt, neu in
            guard neu > alt, let letzter = s.verlauf.last else { return nil }
            let wert: SensoryFeedback
            switch letzter.ausgang {
            case .wasser: wert = .impact(weight: .light)
            case .treffer: wert = .impact(weight: .heavy)
            case .versenkt: wert = .success
            }
            return wert
        }
    }

    private func status(_ s: Schiffe.Stand) -> String {
        if meineFlotte == nil { return "Stelle deine Flotte auf" }
        if !s.bereit { return "Warte auf \(k.partner.name) …" }
        if let w = s.sieger {
            return w == k.ich ? "Alle Schiffe versenkt, du hast gewonnen" : "\(w.name) hat alle deine Schiffe versenkt"
        }
        return s.amZug == k.ich ? "Du bist dran" : "\(k.partner.name) ist dran"
    }

    // MARK: Aufstellen

    private var aufbau: some View {
        VStack(spacing: 16) {
            Text("So liegt deine Flotte. Würfle, bis sie dir gefällt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SchiffeBrett(stile: Self.stile(flotte: entwurf))
            HStack(spacing: 12) {
                Button {
                    entwurf = Schiffe.zufaellig()
                    gewuerfelt += 1
                } label: {
                    Label("Neu würfeln", systemImage: "dice")
                }
                .buttonStyle(.bordered)
                Button {
                    SpieleModell.shared.flotteSenden(k.spiel.id, partie: k.partie, schiffe: entwurf)
                } label: {
                    Label("Bereit", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.loveaRose)
            }
            .controlSize(.large)
        }
    }

    private var warten: some View {
        VStack(spacing: 16) {
            Text("\(k.partner.name) stellt noch auf. Das Spiel darf auch über Nacht laufen, du bekommst den Stand beim nächsten Öffnen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SchiffeBrett(stile: Self.stile(flotte: meineFlotte ?? []))
        }
    }

    // MARK: Gefecht

    private func gefecht(_ s: Schiffe.Stand) -> some View {
        let anzahl = Schiffe.laengen.count
        let meineTreffer = s.schuesse(von: k.ich)
        let seineTreffer = s.schuesse(von: k.partner)
        return VStack(spacing: 12) {
            Picker("Ansicht", selection: $ansicht) {
                Text("Angriff").tag(Ansicht.angriff)
                Text("Meine Flotte").tag(Ansicht.flotte)
            }
            .pickerStyle(.segmented)
            if ansicht == .angriff {
                SchiffeBrett(
                    stile: Self.markieren([SchiffeZelle](repeating: .leer, count: Schiffe.felder), meineTreffer),
                    letzte: meineTreffer.last?.zelle,
                    aktiv: s.amZug == k.ich,
                    aktion: { zelle in schiessen(zelle, s) }
                )
                Text("\(s.versenkt(von: k.ich).count) von \(anzahl) Schiffen versenkt")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                SchiffeBrett(
                    stile: Self.markieren(Self.stile(flotte: meineFlotte ?? []), seineTreffer),
                    letzte: seineTreffer.last?.zelle
                )
                Text("\(k.partner.name) hat \(s.versenkt(von: k.partner).count) von \(anzahl) deiner Schiffe versenkt")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func schiessen(_ zelle: Int, _ s: Schiffe.Stand) {
        guard s.amZug == k.ich, s.sieger == nil, (0..<Schiffe.felder).contains(zelle),
              !s.beschossen(von: k.ich).contains(zelle) else { return }
        let nr = schussListen[k.ich]?.count ?? 0
        SpieleModell.shared.schiessen(k.spiel.id, partie: k.partie, nr: nr, zelle: zelle)
    }

    // MARK: Brett-Daten

    static func stile(flotte: [Schiff]) -> [SchiffeZelle] {
        var s = [SchiffeZelle](repeating: .leer, count: Schiffe.felder)
        for schiff in flotte {
            for c in schiff.zellen where (0..<Schiffe.felder).contains(c) { s[c] = .schiff }
        }
        return s
    }

    static func markieren(_ basis: [SchiffeZelle], _ schuesse: [Schiffe.Schuss]) -> [SchiffeZelle] {
        var s = basis
        for schuss in schuesse where s.indices.contains(schuss.zelle) {
            switch schuss.ausgang {
            case .wasser:
                s[schuss.zelle] = .wasser
            case .treffer:
                s[schuss.zelle] = .treffer
            case .versenkt(let schiff):
                for c in schiff.zellen where s.indices.contains(c) { s[c] = .versenkt }
            }
        }
        return s
    }
}

// MARK: - Brett

enum SchiffeZelle: Equatable, Sendable {
    case leer, schiff, wasser, treffer, versenkt

    var fuellung: Color {
        switch self {
        case .leer: Color(.tertiarySystemFill)
        case .schiff: Color(red: 0.35, green: 0.45, blue: 0.6)
        case .wasser: Color(red: 0.3, green: 0.55, blue: 0.8).opacity(0.55)
        case .treffer: Color.orange
        case .versenkt: Color(red: 0.78, green: 0.2, blue: 0.25)
        }
    }

    var beschreibung: String {
        switch self {
        case .leer: "unbekannt"
        case .schiff: "Schiff"
        case .wasser: "Wasser"
        case .treffer: "Treffer"
        case .versenkt: "versenkt"
        }
    }
}

private struct SchiffeBrett: View {
    let stile: [SchiffeZelle]
    var letzte: Int?
    var aktiv = false
    var aktion: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { g in
            let a = min(g.size.width, g.size.height)
            let luecke: CGFloat = 3
            let kante = (a - luecke * CGFloat(Schiffe.breite - 1)) / CGFloat(Schiffe.breite)
            VStack(spacing: luecke) {
                ForEach(0..<Schiffe.breite, id: \.self) { reihe in
                    HStack(spacing: luecke) {
                        ForEach(0..<Schiffe.breite, id: \.self) { spalte in
                            zelle(reihe * Schiffe.breite + spalte, kante: kante)
                        }
                    }
                }
            }
            .frame(width: a, height: a)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 480)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    private func zelle(_ i: Int, kante: CGFloat) -> some View {
        let stil: SchiffeZelle = stile.indices.contains(i) ? stile[i] : .leer
        return Button {
            aktion(i)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(stil.fuellung)
                switch stil {
                case .wasser:
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: kante * 0.25, height: kante * 0.25)
                case .treffer, .versenkt:
                    Image(systemName: "xmark")
                        .font(.system(size: kante * 0.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, options: .nonRepeating, value: stil)
                default:
                    EmptyView()
                }
            }
            .frame(width: kante, height: kante)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.loveaRose, lineWidth: 2.5)
                    .opacity(letzte == i ? 1 : 0)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: stil)
        }
        .buttonStyle(.plain)
        .disabled(!(aktiv && stil == .leer))
        .accessibilityLabel("\(Schiffe.koordinate(i)), \(stil.beschreibung)")
    }
}
