import SwiftUI
import UIKit

/// Kritzel-Duell (Z-14.2): per round both pick one of 3 words, 3-2-1, both draw the same word
/// in the Level-1 studio against the clock, the pictures travel as media (`spiel.bild`).
/// After the last round both vote per round (`spiel.stimme`); most votes wins.
struct DuellSpiel: View {
    let k: SpielKontext

    private var runden: Int { max(1, min(k.spiel.einstellungen.runden ?? 3, 5)) }
    private var dauer: Int { k.spiel.einstellungen.dauer ?? 60 }

    /// `spiel.bild`/`spiel.stimme` count rounds across "Nochmal": partie 1, round 0 is 10.
    private func g(_ r: Int) -> Int { k.partie * 10 + r }

    private func vibe(_ r: Int) -> String {
        let v = k.spiel.einstellungen.vibes ?? []
        return r < v.count ? v[r] : (v.last ?? "leicht")
    }

    private func vorschlaege(_ r: Int) -> [String] {
        let pool = Wortliste.pool(vibe: vibe(r), woerter: Wortliste.woerter, eigene: SpieleModell.shared.alleEigenenWoerter)
        return Duell.vorschlaege(pool: pool, seed: Duell.seed(spiel: k.spiel.id, runde: g(r)))
    }

    private func wort(_ r: Int) -> String? {
        guard k.mein.count > r, k.partnerZuege.count > r else { return nil }
        return Duell.wort(wahlA: k.mein[r], wahlB: k.partnerZuege[r], vorschlaege: vorschlaege(r), seed: Duell.seed(spiel: k.spiel.id, runde: g(r)))
    }

    private enum Phase: Equatable {
        case wahl(Int), warteWahl(Int), zeichnen(Int, String), warteBild(Int), abstimmen(Int), warteStimmen, fertig
    }

    private var phase: Phase {
        for r in 0..<runden {
            let bilder = k.spiel.bilder[g(r)] ?? [:]
            if bilder[k.ich] != nil, bilder[k.partner] != nil { continue }
            if k.mein.count <= r { return .wahl(r) }
            guard let w = wort(r) else { return .warteWahl(r) }
            return bilder[k.ich] == nil ? .zeichnen(r, w) : .warteBild(r)
        }
        for r in 0..<runden where k.spiel.stimmen[g(r)]?[k.ich] == nil { return .abstimmen(r) }
        for r in 0..<runden where k.spiel.stimmen[g(r)]?[k.partner] == nil { return .warteStimmen }
        return .fertig
    }

    var zeichnetGerade: Bool {
        if case .zeichnen = phase { return true }
        return false
    }

    private var stimmenFuer: SpielPunkte {
        var p = SpielPunkte()
        for r in 0..<runden { for fuer in (k.spiel.stimmen[g(r)] ?? [:]).values { p[fuer] += 1 } }
        return p
    }

    var ende: PartieEnde? {
        guard phase == .fertig else { return nil }
        let s = stimmenFuer
        var p = SpielPunkte()
        if let w = s.fuehrend { p[w] = 1 }
        return PartieEnde(punkte: p, sieger: s.fuehrend, text: "\(s.text) Stimmen")
    }

    var body: some View {
        switch phase {
        case .wahl(let r):
            wahl(r)
        case .warteWahl(let r):
            warten("Warte, bis \(k.partner.name) ein Wort gewählt hat …", unten: "Deine Wahl: \(vorschlaege(r)[safe: k.mein[r]] ?? "")")
        case .zeichnen(let r, let w):
            DuellZeichnen(spielId: k.spiel.id, runde: g(r), wort: w, dauer: dauer, ich: k.ich)
                .id(g(r))
        case .warteBild(let r):
            warten("Warte auf \(k.partner.name)s Bild …", unten: "Runde \(r + 1): \(wort(r) ?? "")")
        case .abstimmen(let r):
            abstimmen(r)
        case .warteStimmen:
            warten("\(k.partner.name) stimmt noch ab …", unten: nil)
        case .fertig:
            galerie
        }
    }

    private func wahl(_ r: Int) -> some View {
        VStack(spacing: 16) {
            Text("Runde \(r + 1) von \(runden)").font(.subheadline).foregroundStyle(.secondary)
            Text(Wortliste.titel(vibe(r)))
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Color.loveaRose.opacity(0.15)))
                .foregroundStyle(Color.loveaRose)
            Text("Was wollt ihr malen?").font(.title2.bold())
            ForEach(Array(vorschlaege(r).enumerated()), id: \.offset) { i, w in
                Button {
                    k.setzen(i)
                } label: {
                    Text(w)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
            }
            Text("Tippt ihr dasselbe, gilt es. Sonst entscheidet der Zufall.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func warten(_ text: String, unten: String?) -> some View {
        VStack(spacing: 16) {
            FigurView(FigurenModell.shared.aussehen(k.partner), zustand: .zeichnet, groesse: 160)
            Text(text).font(.headline).multilineTextAlignment(.center)
            if let unten { Text(unten).font(.subheadline).foregroundStyle(.secondary) }
        }
        .padding()
    }

    private func abstimmen(_ r: Int) -> some View {
        let bilder = k.spiel.bilder[g(r)] ?? [:]
        return VStack(spacing: 16) {
            Text("Runde \(r + 1): \(wort(r) ?? "")").font(.title2.bold())
            Text("Tippe auf dein Lieblingsbild").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach([k.ich, k.partner], id: \.self) { p in
                    Button {
                        SpieleModell.shared.stimmeSenden(k.spiel.id, runde: g(r), fuer: p)
                    } label: {
                        VStack(spacing: 8) {
                            SpielBild(medienId: bilder[p] ?? "")
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            Text(p == k.ich ? "Deins" : "\(p.name)s").font(.headline)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(p == k.ich ? "Dein Bild" : "Bild von \(p.name)")
                }
            }
        }
        .padding()
        .sensoryFeedback(.selection, trigger: r)
    }

    private var galerie: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(0..<runden, id: \.self) { r in
                    let bilder = k.spiel.bilder[g(r)] ?? [:]
                    let stimmen = k.spiel.stimmen[g(r)] ?? [:]
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Runde \(r + 1): \(wort(r) ?? "")").font(.headline)
                        HStack(spacing: 10) {
                            ForEach([k.ich, k.partner], id: \.self) { p in
                                let herzen = stimmen.values.filter { $0 == p }.count
                                SpielBild(medienId: bilder[p] ?? "")
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(alignment: .bottomTrailing) {
                                        if herzen > 0 {
                                            Label("\(herzen)", systemImage: "heart.fill")
                                                .font(.caption.bold())
                                                .padding(6)
                                                .background(.regularMaterial, in: Capsule())
                                                .foregroundStyle(Color.loveaRose)
                                                .padding(6)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 320)
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// One drawing round: 3-2-1, the studio with the word and a timer in the bar, then export,
/// upload and `spiel.bild`.
private struct DuellZeichnen: View {
    let spielId: String
    let runde: Int
    let wort: String
    let dauer: Int
    let ich: Person

    private enum Phase: Equatable { case countdown(Int), malen, hochladen, fehler }
    @State private var phase = Phase.countdown(3)
    @State private var ende = Date()
    @State private var abgegeben = Date()
    @State private var library: ArtworkLibrary?
    @State private var artworkID: UUID?

    var body: some View {
        Group {
            switch phase {
            case .countdown(let n):
                VStack(spacing: 12) {
                    Text("Malt: \(wort)").font(.title.bold())
                    Text("\(n)")
                        .font(.system(size: 140, weight: .black, design: .rounded))
                        .foregroundStyle(Color.loveaRose)
                        .contentTransition(.numericText(countsDown: true))
                    Text("\(dauer < 60 ? "\(dauer) s" : "\(dauer / 60) min") Zeit").foregroundStyle(.secondary)
                }
            case .malen:
                if let library, let artworkID {
                    DrawingStudioView(artworkID: artworkID, library: library, person: ich)
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                HStack(spacing: 8) {
                                    Text(wort).font(.headline)
                                    Text(timerInterval: Date.now...max(ende, Date.now), countsDown: true)
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(Color.loveaRose)
                                }
                            }
                        }
                }
            case .hochladen:
                ProgressView("Dein Bild wird verschickt …")
            case .fehler:
                VStack(spacing: 12) {
                    Text("Dein Bild ging nicht raus.").font(.headline)
                    Button("Nochmal senden") { Task { await senden() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.loveaRose)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: phase)
        .task { await ablauf() }
    }

    private func ablauf() async {
        guard library == nil else { return }
        let neu = ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("duell-\(UUID().uuidString)"))
        artworkID = neu.createArtwork(name: wort, projectID: nil, format: .square, customWidth: 1024, customHeight: 1024).id
        library = neu
        for n in [3, 2, 1] {
            withAnimation { phase = .countdown(n) }
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
        }
        ende = Date().addingTimeInterval(Double(dauer))
        phase = .malen
        try? await Task.sleep(for: .seconds(Double(dauer)))
        if Task.isCancelled { return }
        abgegeben = Date()
        phase = .hochladen // removes the studio: its onDisappear saves layers and the preview
        await senden()
    }

    private func senden() async {
        guard let library, let artworkID else { return }
        phase = .hochladen
        // `saveNow` runs in an unstructured Task; the preview is written after the layers, so a
        // fresh preview means the layers are queued too. Capped at 5 s.
        let vorschau = library.previewURL(for: artworkID)
        for _ in 0..<25 {
            let geaendert = (try? FileManager.default.attributesOfItem(atPath: vorschau.path))?[.modificationDate] as? Date
            if let geaendert, geaendert >= abgegeben { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        await library.waitForWrites()

        var daten: Data?
        var endung = "png"
        if let dokument = library.document(artworkID), let bild = await CanvasEngine.renderImage(document: dokument, library: library) {
            daten = ArtworkExport.encode(bild, format: .png)
        }
        if daten == nil {
            daten = try? Data(contentsOf: vorschau)
            endung = "jpg"
        }
        guard let daten else {
            phase = .fehler
            return
        }
        let medienId = UUID().uuidString
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent("\(medienId).\(endung)")
        do {
            try daten.write(to: datei)
            try await Medien.hochladen(id: medienId, original: datei)
            SpieleModell.shared.bildSenden(spielId, runde: runde, medienId: medienId)
        } catch {
            phase = .fehler
        }
    }
}
