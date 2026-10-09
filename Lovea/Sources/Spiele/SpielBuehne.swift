import SwiftUI

extension View {
    /// Presents the open game full screen. Attach exactly once, at the app root.
    func spieleBuehne() -> some View { modifier(SpieleBuehneModifier()) }
}

private struct SpieleBuehneModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Read here (inside body) so Observation tracks it; the Binding getter alone would not.
        let offen = SpieleModell.shared.offen
        content.fullScreenCover(item: Binding(get: { offen }, set: { SpieleModell.shared.offen = $0 })) { o in
            SpielBuehne(spielId: o.id)
        }
    }
}

/// Full-screen frame around every game: both figures and the running tally on top, the game in
/// the middle, "Nochmal" / "Fertig" at the end of each round.
struct SpielBuehne: View {
    let spielId: String
    @State private var gezeigtesEnde: PartieEnde?
    @State private var jetzt = Date()

    private var modell: SpieleModell { .shared }

    var body: some View {
        NavigationStack {
            Group {
                if let spiel = modell.spiele[spielId], let ich = Raum.shared.ich {
                    buehne(SpielKontext.aus(spiel, ich: ich, modell: modell))
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", systemImage: "xmark") { modell.verlassen(spielId) }
                }
            }
        }
        .task {
            FigurenModell.shared.zustandSenden(FigurenModell.Zustand(haupt: .spielt))
            while !Task.isCancelled {
                modell.erneutSenden(spielId)
                jetzt = Date()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onDisappear { FigurenModell.shared.zustandSenden(FigurenModell.Zustand(haupt: .imChat)) }
    }

    private func buehne(_ k: SpielKontext) -> some View {
        let ende = Self.ende(k)
        return VStack(spacing: 0) {
            if !(k.spiel.art == .duell && DuellSpiel(k: k).zeichnetGerade) {
                kopf(k)
            }
            inhalt(k).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(k.spiel.art.titel)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let e = gezeigtesEnde {
                EndeKarte(k: k, ende: e)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay {
            if gezeigtesEnde?.sieger != nil { SpielKonfetti() }
        }
        .task(id: ende) {
            guard let ende else {
                gezeigtesEnde = nil
                return
            }
            modell.partieBeendet(spielId, partie: k.partie, punkte: ende.punkte)
            // A short pause so the last move (a reveal, the winning head) can be seen first.
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { gezeigtesEnde = ende }
        }
    }

    @ViewBuilder
    private func inhalt(_ k: SpielKontext) -> some View {
        switch k.spiel.art {
        case .duell: DuellSpiel(k: k)
        case .xo: XOSpiel(k: k)
        case .ssp: SSPSpiel(k: k)
        case .kennen: KennenSpiel(k: k)
        case .reaktion: ReaktionSpiel(k: k)
        case .memory: MemorySpiel(k: k)
        case .eher: EherSpiel(k: k).id(k.partie)
        case .wordle: WordleSpiel(k: k).id(k.partie)
        case .schiffe: SchiffeSpiel(k: k).id(k.partie)
        }
    }

    @MainActor static func ende(_ k: SpielKontext) -> PartieEnde? {
        switch k.spiel.art {
        case .duell: DuellSpiel(k: k).ende
        case .xo: XOSpiel(k: k).ende
        case .ssp: SSPSpiel(k: k).ende
        case .kennen: KennenSpiel(k: k).ende
        case .reaktion: ReaktionSpiel(k: k).ende
        case .memory: MemorySpiel(k: k).ende
        case .eher: EherSpiel(k: k).ende
        case .wordle: WordleSpiel(k: k).ende
        case .schiffe: SchiffeSpiel(k: k).ende
        }
    }

    private func kopf(_ k: SpielKontext) -> some View {
        let gesamt = k.spiel.ergebnis?.punkte ?? SpielPunkte()
        let da = modell.partnerGesehen[spielId].map { jetzt.timeIntervalSince($0) < 7 } ?? false
        // Schiffe lebt von gespeicherten Ops und läuft über Tage: "raus" und "da" gelten dort nicht.
        let dauerhaft = k.spiel.art == .schiffe
        let raus = !dauerhaft && k.partnerZug?.raus == true
        let status = raus ? "\(k.partner.name) ist raus" : (da || dauerhaft ? "\(k.spiel.ergebnis?.gespielt ?? 0)× gespielt" : "Warte auf \(k.partner.name) …")
        return HStack(alignment: .bottom) {
            spieler(k.ich, name: "Du", da: true)
            Spacer()
            VStack(spacing: 2) {
                Text(k.spiel.art.paarWertung ? "\(gesamt.ahmed) von \(gesamt.ahmed + gesamt.annika)" : "\(gesamt[k.ich]) : \(gesamt[k.partner])")
                    .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 18)
            Spacer()
            spieler(k.partner, name: k.partner.name, da: (da || dauerhaft) && !raus)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(k.spiel.art.paarWertung ? "\(k.spiel.art.bilanzText(gesamt)), \(status)" : "Du \(gesamt[k.ich]), \(k.partner.name) \(gesamt[k.partner]), \(status)")
    }

    private func spieler(_ p: Person, name: String, da: Bool) -> some View {
        VStack(spacing: 4) {
            FigurView(FigurenModell.shared.aussehen(p), zustand: da ? .spielt : .offline, groesse: 72, bildrate: 20)
            Text(name).font(.caption.weight(.semibold))
        }
    }
}

/// "Du gewinnst!" with the winner holding the cup, then "Nochmal" or "Fertig".
private struct EndeKarte: View {
    let k: SpielKontext
    let ende: PartieEnde

    private var titel: String {
        if let t = ende.titel { return t }
        guard let s = ende.sieger else { return "Unentschieden" }
        return s == k.ich ? "Du gewinnst!" : "\(s.name) gewinnt!"
    }

    var body: some View {
        let raus = k.spiel.art != .schiffe && k.partnerZug?.raus == true
        VStack(spacing: 12) {
            if let s = ende.sieger {
                FigurView(FigurenModell.shared.aussehen(s), zustand: .pokal, groesse: 120)
                    .accessibilityLabel(s.name)
            } else {
                HStack(spacing: -10) {
                    FigurKopf(person: k.ich, groesse: 64, zustand: .lacht)
                    FigurKopf(person: k.partner, groesse: 64, zustand: .lacht)
                }
            }
            Text(titel).font(.title2.bold())
            Text(ende.text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Fertig") { SpieleModell.shared.verlassen(k.spiel.id) }
                    .buttonStyle(.bordered)
                Button("Nochmal") { SpieleModell.shared.nochmal(k.spiel.id) }
                    .buttonStyle(.borderedProminent)
                    .tint(.loveaRose)
                    .disabled(raus)
            }
            .controlSize(.large)
            .padding(.top, 4)
            if raus {
                Text("\(k.partner.name) hat das Spiel verlassen.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
        .padding(16)
        .sensoryFeedback(.success, trigger: ende)
    }
}
