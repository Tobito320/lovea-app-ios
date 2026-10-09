import SwiftUI
import TipKit

/// Insights: Zykluslängen, Periode, Regelmäßigkeit, Symptome und Stimmung je Phase, Temperatur, Hinweise, Wissen.
/// Diagramme sind eigene Shapes (reines SwiftUI), damit ImageRenderer sie zeichnet.
struct ZyklusInsightsView: View {
    let speicher: any ZyklusSpeicher
    var heute: String = Datum.text(Date())

    var body: some View {
        ZyklusInsightsInhalt(auswertung: ZyklusInsightsLogik(tage: Array(speicher.tage.values), einstellung: speicher.einstellung, heute: heute))
    }
}

/// Reiner Inhalt ohne Speicher, damit die Render-Tafel ihn direkt zeigen kann.
struct ZyklusInsightsInhalt: View {
    let auswertung: ZyklusInsightsLogik
    /// Aus bei der Render-Tafel: ImageRenderer zeichnet keine ScrollView.
    var scrollt = true
    @State private var wissensPhase: Phase = .periode
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ZStack {
            ZyklusHintergrund(deko: false)
            if scrollt { ScrollView { stapel } } else { stapel }
        }
    }

    private var stapel: some View {
        VStack(spacing: 14) {
            Text("Insights").font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(ZyklusFarbe.tinte(schema)).frame(maxWidth: .infinity, alignment: .leading)
            zahlenKarte
            verlaufKarte
            if !auswertung.auffaelligkeiten.isEmpty { hinweisKarte }
            phasenKarte
            temperaturKarte
            wissenKarte
            Text(ZyklusInsightsLogik.arztHinweis).font(.system(.footnote, design: .rounded))
                .foregroundStyle(ZyklusFarbe.tinteLeise(schema)).multilineTextAlignment(.center)
        }
        .padding(16)
    }

    private func kopf(_ text: String) -> some View {
        Text(text).font(.system(.headline, design: .rounded)).foregroundStyle(ZyklusFarbe.tinte(schema))
    }

    private func leise(_ text: String) -> some View {
        Text(text).font(.system(.subheadline, design: .rounded)).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func zahl(_ wert: String, _ titel: String) -> some View {
        VStack(spacing: 2) {
            Text(wert).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(ZyklusFarbe.himbeere.farbe(schema))
            Text(titel).font(.system(.caption, design: .rounded)).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var zahlenKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    zahl("\(auswertung.mittlereZyklusLaenge)", "Tage Zyklus")
                    zahl("\(auswertung.mittlerePeriodenLaenge)", "Tage Periode")
                    zahl(auswertung.hatZyklen ? "\(auswertung.streuung)" : "-", "Tage Streuung")
                }
                kopf(auswertung.regelmaessigkeit.titel)
                leise(auswertung.regelmaessigkeit.text)
            }
        }
        .popoverTip(ZyklusZahlenTip())
    }

    private var verlaufKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                kopf("Deine Zyklen")
                let werte = auswertung.zyklusVerlauf()
                if werte.isEmpty {
                    leise("Sobald du zwei Perioden eingetragen hast, siehst du hier deinen Verlauf.")
                } else {
                    ZyklusBalkenDiagramm(werte: werte, mittel: auswertung.mittlereZyklusLaenge,
                                         farbe: ZyklusFarbe.zuckerrosa.farbe(schema), linie: ZyklusFarbe.himbeere.farbe(schema),
                                         beschriftung: ZyklusFarbe.tinteLeise(schema))
                        .frame(height: 130)
                    leise("Die Linie zeigt deinen Durchschnitt.")
                }
            }
        }
    }

    private var hinweisKarte: some View {
        ZyklusKarte(akzent: ZyklusFarbe.pfirsich.farbe(schema)) {
            VStack(alignment: .leading, spacing: 8) {
                kopf("Mir fällt etwas auf")
                ForEach(Array(auswertung.auffaelligkeiten.enumerated()), id: \.offset) { _, a in
                    leise(a.text)
                }
                leise(ZyklusInsightsLogik.arztHinweis)
            }
        }
    }

    private var phasenKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 12) {
                kopf("Je Phase")
                ForEach(Phase.allCases, id: \.self) { phase in
                    let sym = auswertung.haeufigsteSymptome(in: phase, maximal: 2)
                    let stim = auswertung.haeufigsteStimmung(in: phase, maximal: 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(phase.ton.name).font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(phase.ton.farbe(schema))
                        if sym.isEmpty && stim.isEmpty {
                            leise("Noch nichts eingetragen.")
                        } else {
                            if !sym.isEmpty { chips(sym.map { ($0.wert.anzeige, $0.anzahl) }, phase.ton.farbe(schema)) }
                            if !stim.isEmpty { chips(stim.map { ($0.wert.anzeige, $0.anzahl) }, phase.ton.farbe(schema)) }
                        }
                    }
                }
            }
        }
    }

    private func chips(_ eintraege: [(String, Int)], _ farbe: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(eintraege.enumerated()), id: \.offset) { _, e in
                ZyklusChip(titel: "\(e.0) \(e.1)", farbe: farbe)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var temperaturKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                kopf("Temperatur")
                let punkte = auswertung.temperaturKurve
                if punkte.count < 2 {
                    leise("Miss morgens deine Temperatur, dann zeichne ich hier die Kurve.")
                } else {
                    ZyklusTemperaturKurve(punkte: punkte, farbe: ZyklusPhasenTon.eisprung.farbe(schema), raster: ZyklusFarbe.tinteLeise(schema).opacity(0.25))
                        .frame(height: 120)
                    leise("Nach dem Eisprung steigt sie meist um etwa 0,3 Grad.")
                }
            }
        }
    }

    private var wissenKarte: some View {
        let karte = ZyklusWissen.karte(fuer: wissensPhase)
        return ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                kopf("Gut zu wissen")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Phase.allCases, id: \.self) { p in
                            Button { wissensPhase = p } label: {
                                ZyklusChip(titel: p.ton.name, gewaehlt: p == wissensPhase, farbe: p.ton.farbe(schema))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                leise(karte.kurz)
                zeile("fork.knife", "Essen", karte.ernaehrung)
                zeile("figure.walk", "Bewegung", karte.sport)
                zeile("moon.zzz.fill", "Schlaf", karte.schlaf)
                zeile("heart.fill", "Stimmung", karte.stimmung)
            }
        }
    }

    private func zeile(_ symbol: String, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(ZyklusFarbe.himbeere.farbe(schema)).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(ZyklusFarbe.tinte(schema))
                leise(text)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Diagramme

/// Balken je Zyklus mit Durchschnittslinie. Die Zahl steht über dem Balken.
struct ZyklusBalkenDiagramm: View {
    let werte: [Int]
    let mittel: Int
    let farbe: Color
    let linie: Color
    let beschriftung: Color

    var body: some View {
        GeometryReader { geo in
            let hoechst = CGFloat(max(werte.max() ?? 1, mittel, 1))
            let platz = geo.size.height - 18
            let breite = geo.size.width / CGFloat(max(werte.count, 1))
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(werte.enumerated()), id: \.offset) { i, w in
                    let h = platz * CGFloat(w) / hoechst
                    VStack(spacing: 2) {
                        Text("\(w)").font(.system(size: 11, design: .rounded).weight(.semibold)).foregroundStyle(beschriftung)
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(farbe).frame(width: breite * 0.6, height: h)
                    }
                    .frame(width: breite, height: h + 18, alignment: .bottom)
                    .offset(x: breite * CGFloat(i))
                }
                Path { p in
                    let y = geo.size.height - platz * CGFloat(mittel) / hoechst
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(linie, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zykluslängen: " + werte.map(String.init).joined(separator: ", ") + " Tage")
    }
}

/// Temperaturkurve nach Zyklustag; Achse passt sich den Werten an.
struct ZyklusTemperaturKurve: View {
    let punkte: [ZyklusInsightsLogik.TempPunkt]
    let farbe: Color
    let raster: Color

    var body: some View {
        GeometryReader { geo in
            let tiefst = (punkte.map(\.grad).min() ?? 36) - 0.1
            let hoechst = (punkte.map(\.grad).max() ?? 37) + 0.1
            let ersterTag = punkte.first?.zyklusTag ?? 1
            let letzterTag = max(punkte.last?.zyklusTag ?? 2, ersterTag + 1)
            let pt: (ZyklusInsightsLogik.TempPunkt) -> CGPoint = { p in
                CGPoint(x: geo.size.width * CGFloat(p.zyklusTag - ersterTag) / CGFloat(letzterTag - ersterTag),
                        y: geo.size.height * (1 - CGFloat((p.grad - tiefst) / (hoechst - tiefst))))
            }
            ZStack {
                Path { p in
                    for i in 0...2 {
                        let y = geo.size.height * CGFloat(i) / 2
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(raster, lineWidth: 1)
                Path { p in
                    for (i, q) in punkte.enumerated() { i == 0 ? p.move(to: pt(q)) : p.addLine(to: pt(q)) }
                }
                .stroke(farbe, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(punkte.enumerated()), id: \.offset) { _, q in
                    Circle().fill(farbe).frame(width: 6, height: 6).position(pt(q))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Temperaturkurve mit \(punkte.count) Messungen")
    }
}

// MARK: Namen

private extension Phase {
    var ton: ZyklusPhasenTon {
        switch self {
        case .periode: .periode
        case .follikel: .follikel
        case .fruchtbar: .fruchtbar
        case .eisprung: .eisprung
        case .luteal: .luteal
        }
    }
}

private extension Symptom {
    var anzeige: String {
        switch self {
        case .kopfschmerzen: "Kopfweh"
        case .kraempfe: "Krämpfe"
        case .rueckenschmerzen: "Rücken"
        case .brustspannen: "Brustspannen"
        case .uebelkeit: "Übelkeit"
        case .blaehbauch: "Blähbauch"
        case .akne: "Unreine Haut"
        case .muedigkeit: "Müde"
        case .heisshunger: "Heißhunger"
        case .schwindel: "Schwindel"
        case .verstopfung: "Verstopfung"
        case .durchfall: "Durchfall"
        }
    }
}

private extension Stimmung {
    var anzeige: String {
        switch self {
        case .froehlich: "Fröhlich"
        case .ruhig: "Ruhig"
        case .energiegeladen: "Energie"
        case .empfindlich: "Empfindlich"
        case .gereizt: "Gereizt"
        case .traurig: "Traurig"
        case .aengstlich: "Ängstlich"
        case .gestresst: "Gestresst"
        }
    }
}
