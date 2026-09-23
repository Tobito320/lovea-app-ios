import SwiftUI

// MARK: - XO mit Figur-Köpfen (Z-14.3)

struct XOSpiel: View {
    let k: SpielKontext

    private var stand: XO.Stand { XO.stand(starter: k.starter, zuege: k.zuege) }

    var ende: PartieEnde? {
        let s = stand
        guard s.amZug == nil else { return nil }
        var p = SpielPunkte()
        if let w = s.sieger { p[w] = 1 }
        return PartieEnde(punkte: p, sieger: s.sieger, text: s.sieger == nil ? "Das Feld ist voll, keiner hat drei in einer Reihe." : "Drei in einer Reihe.")
    }

    var body: some View {
        let s = stand
        let linie = XO.gewinnLinie(feld: s.feld) ?? []
        let binDran = s.amZug == k.ich
        VStack(spacing: 28) {
            Text(status(s))
                .font(.headline)
                .foregroundStyle(binDran ? Color.loveaRose : .secondary)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<3, id: \.self) { reihe in
                    GridRow {
                        ForEach(0..<3, id: \.self) { spalte in
                            zelle(reihe * 3 + spalte, s: s, linie: linie, binDran: binDran)
                        }
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 30).fill(Color(.secondarySystemBackground)))
        }
        .padding()
        .sensoryFeedback(.impact(weight: .light), trigger: s.feld.compactMap { $0 }.count)
    }

    private func status(_ s: XO.Stand) -> String {
        if s.amZug == nil {
            guard let w = s.sieger else { return "Unentschieden" }
            return w == k.ich ? "Du hast gewonnen" : "\(w.name) hat gewonnen"
        }
        return s.amZug == k.ich ? "Du bist dran" : "\(k.partner.name) ist dran"
    }

    private func zelle(_ i: Int, s: XO.Stand, linie: [Int], binDran: Bool) -> some View {
        Button {
            k.setzen(i)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(linie.contains(i) ? Color.loveaRose.opacity(0.2) : Color(.tertiarySystemBackground))
                if let p = s.feld[i] {
                    FigurKopf(person: p, groesse: 76, zustand: linie.contains(i) ? .lacht : .ruhig)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: 96, height: 96)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: s.feld[i])
        }
        .buttonStyle(.plain)
        .disabled(!binDran || s.feld[i] != nil)
        .accessibilityLabel("Feld \(i + 1)")
        .accessibilityValue(s.feld[i].map { $0 == k.ich ? "du" : $0.name } ?? "leer")
    }
}

// MARK: - Schere-Stein-Papier, Best of 3 (Z-14.3)

struct SSPSpiel: View {
    let k: SpielKontext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Rounds whose reveal already played. Lags behind `beide` while the fists shake.
    @State private var gezeigt = 0
    @State private var wackelt = false

    private var beide: Int { min(k.mein.count, k.partnerZuege.count) }

    var ende: PartieEnde? {
        let s = SSP.stand(k.zuege)
        guard let w = s.sieger else { return nil }
        var p = SpielPunkte()
        p[w] = 1
        return PartieEnde(punkte: p, sieger: w, text: "\(s.siege[w]) : \(s.siege[w.partner]) nach \(s.runden) Runden")
    }

    var body: some View {
        let sichtbar = min(gezeigt, beide)
        let siege = SSP.stand([.ahmed: Array((k.zuege[.ahmed] ?? []).prefix(sichtbar)), .annika: Array((k.zuege[.annika] ?? []).prefix(sichtbar))]).siege
        let meine = sichtbar > 0 ? SSP(rawValue: k.mein[sichtbar - 1]) : nil
        let seine = sichtbar > 0 ? SSP(rawValue: k.partnerZuege[sichtbar - 1]) : nil
        let habeGewaehlt = k.mein.count > beide
        VStack(spacing: 20) {
            Text("\(siege[k.ich]) : \(siege[k.partner])")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy).monospacedDigit())
            HStack(alignment: .bottom, spacing: 12) {
                spieler(k.ich, hand: meine, gegen: seine, gespiegelt: false)
                Text("vs").font(.headline).foregroundStyle(.secondary).padding(.bottom, 40)
                spieler(k.partner, hand: seine, gegen: meine, gespiegelt: true)
            }
            Text(wackelt ? "Schere … Stein … Papier!" : (habeGewaehlt ? "Warte auf \(k.partner.name) …" : "Wähle deine Hand"))
                .font(.headline)
                .foregroundStyle(habeGewaehlt || wackelt ? .secondary : Color.loveaRose)
            HStack(spacing: 16) {
                ForEach(SSP.allCases, id: \.self) { hand in
                    Button {
                        k.setzen(hand.rawValue)
                    } label: {
                        Text(hand.emoji)
                            .font(.system(size: 44))
                            .frame(width: 88, height: 88)
                            .background(Circle().fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hand.titel)
                    .disabled(habeGewaehlt || wackelt || ende != nil)
                }
            }
        }
        .padding()
        .onAppear { gezeigt = beide }
        .onChange(of: beide) { _, neu in
            guard neu > gezeigt else {
                gezeigt = neu
                return
            }
            wackelt = true
            Task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.2))
                wackelt = false
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { gezeigt = neu }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: gezeigt)
    }

    private func spieler(_ p: Person, hand: SSP?, gegen: SSP?, gespiegelt: Bool) -> some View {
        let zustand: FigurZustand
        if wackelt || hand == nil || gegen == nil {
            zustand = .spielt
        } else if let h = hand, let g = gegen, let w = SSP.sieger(a: h, b: g) {
            zustand = w == h ? .lacht : .mittel
        } else {
            zustand = .ruhig
        }
        return VStack(spacing: 6) {
            Text(wackelt || hand == nil ? SSP.stein.emoji : hand?.emoji ?? "")
                .font(.system(size: 60))
                .scaleEffect(x: gespiegelt ? -1 : 1, y: 1)
                .offset(y: wackelt && !reduceMotion ? -18 : 0)
                .animation(wackelt && !reduceMotion ? .easeInOut(duration: 0.2).repeatCount(6, autoreverses: true) : .default, value: wackelt)
                .opacity(hand == nil && !wackelt ? 0.3 : 1)
                .frame(height: 90)
            FigurView(FigurenModell.shared.aussehen(p), zustand: zustand, groesse: 140)
                .scaleEffect(x: gespiegelt ? -1 : 1, y: 1)
            Text(p == k.ich ? "Du" : p.name).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reaktions-Duell (Z-14.5)

struct ReaktionSpiel: View {
    let k: SpielKontext

    private enum Phase { case pause, warten, jetzt, getippt }
    @State private var phase = Phase.pause
    @State private var erschienen = Date()
    @State private var zuFrueh = false

    var ende: PartieEnde? {
        let s = Reaktion.stand(k.zuege)
        guard let w = s.sieger else { return nil }
        var p = SpielPunkte()
        p[w] = 1
        return PartieEnde(punkte: p, sieger: w, text: "\(s.siege[w]) : \(s.siege[w.partner]) Runden")
    }

    private var runde: Int { k.mein.count }
    /// My next round starts once the partner finished the previous one too.
    private var kannStarten: Bool { k.partnerZuege.count >= runde && ende == nil }

    var body: some View {
        let s = Reaktion.stand(k.zuege)
        ZStack {
            (phase == .jetzt ? Color.loveaRose.opacity(0.14) : Color.clear).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("\(s.siege[k.ich]) : \(s.siege[k.partner])")
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy).monospacedDigit())
                Text("Wer zuerst 3 Runden holt").font(.caption).foregroundStyle(.secondary)
                Spacer()
                ZStack {
                    if phase == .jetzt {
                        FigurView(FigurenModell.shared.aussehen(k.partner), zustand: .anstupsen, groesse: 240)
                            .transition(.scale(scale: 0.2).combined(with: .opacity))
                    } else {
                        Text(anweisung)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(zuFrueh && phase == .getippt ? Color.loveaRose : .primary)
                            .transition(.opacity)
                    }
                }
                .frame(height: 280)
                Spacer()
                if let letzte = letzteRunde {
                    Text(letzte).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture { tippen() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(phase == .jetzt ? "Jetzt tippen" : anweisung)
        .task(id: "\(k.partie)-\(runde)-\(kannStarten)") { await starten() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: phase) { _, neu in neu == .jetzt }
        .sensoryFeedback(.error, trigger: zuFrueh) { _, neu in neu }
    }

    private var anweisung: String {
        switch phase {
        case .pause: return runde == 0 ? "Tippe, sobald \(k.partner.name) auftaucht." : "Nächste Runde …"
        case .warten: return "Gleich …\nnicht zu früh tippen!"
        case .jetzt: return ""
        case .getippt: return zuFrueh ? "Zu früh!" : "Warte auf \(k.partner.name) …"
        }
    }

    private var letzteRunde: String? {
        let r = min(k.mein.count, k.partnerZuege.count) - 1
        guard r >= 0 else { return nil }
        func zeit(_ ms: Int) -> String { ms < 0 ? "zu früh" : "\(ms) ms" }
        return "Runde \(r + 1): du \(zeit(k.mein[r])) · \(k.partner.name) \(zeit(k.partnerZuege[r]))"
    }

    private func starten() async {
        guard kannStarten else { return }
        zuFrueh = false
        phase = .pause
        try? await Task.sleep(for: .seconds(1.6))
        guard !Task.isCancelled else { return }
        phase = .warten
        try? await Task.sleep(for: .seconds(Reaktion.verzoegerung(spiel: k.spiel.id, partie: k.partie, runde: runde)))
        guard !Task.isCancelled, phase == .warten else { return }
        erschienen = Date()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { phase = .jetzt }
    }

    private func tippen() {
        switch phase {
        case .warten:
            zuFrueh = true
            phase = .getippt
            k.setzen(Reaktion.zuFrueh)
        case .jetzt:
            let ms = max(1, Int(Date().timeIntervalSince(erschienen) * 1000))
            phase = .getippt
            k.setzen(ms)
        default:
            break
        }
    }
}
