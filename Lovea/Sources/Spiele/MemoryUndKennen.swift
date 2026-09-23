import SwiftUI

// MARK: - Memory mit euren Bildern (Z-14.5)

struct MemorySpiel: View {
    let k: SpielKontext

    /// Motifs come from the inviter's device (only it knows which of its media to use) and travel
    /// in its snapshot, so both boards are identical.
    private var motive: [String]? { (k.spiel.von == k.ich ? k.meinZug : k.partnerZug)?.texte }
    private var karten: [String]? { motive.map { Memory.karten(motive: $0, seed: k.seed) } }

    var ende: PartieEnde? {
        guard let karten else { return nil }
        let s = Memory.stand(karten: karten, starter: k.starter, zuege: k.zuege)
        guard s.fertig else { return nil }
        var p = SpielPunkte()
        if let w = s.paare.fuehrend { p[w] = 1 }
        return PartieEnde(punkte: p, sieger: s.paare.fuehrend, text: "\(s.paare.text) Paare")
    }

    var body: some View {
        if let karten {
            feld(karten)
        } else {
            ProgressView(k.spiel.von == k.ich ? "Karten werden gemischt …" : "\(k.spiel.von.name) mischt die Karten …")
                .task(id: k.partie) {
                    guard k.spiel.von == k.ich else { return }
                    let m = Self.motiveWaehlen(seed: k.seed)
                    k.ziehen { $0.texte = m }
                }
        }
    }

    private func feld(_ karten: [String]) -> some View {
        let s = Memory.stand(karten: karten, starter: k.starter, zuege: k.zuege)
        let binDran = s.amZug == k.ich && !s.fertig
        return VStack(spacing: 14) {
            HStack {
                Text(s.fertig ? "Alle Paare gefunden" : (binDran ? "Du bist dran" : "\(k.partner.name) ist dran"))
                    .font(.headline)
                    .foregroundStyle(binDran ? Color.loveaRose : .secondary)
                Spacer()
                Text("Paare \(s.paare[k.ich]) : \(s.paare[k.partner])").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(karten.indices, id: \.self) { i in
                    karte(i, motiv: karten[i], s: s, binDran: binDran)
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .sensoryFeedback(.selection, trigger: k.mein.count + k.partnerZuege.count)
        .sensoryFeedback(.success, trigger: s.gefunden.count)
    }

    private func karte(_ i: Int, motiv: String, s: Memory.Stand, binDran: Bool) -> some View {
        let finder = s.gefunden[i]
        let offen = finder != nil || s.offen.contains(i) || s.zuletzt.contains(i)
        return Button {
            k.setzen(i)
        } label: {
            ZStack {
                if offen {
                    MotivView(motiv: motiv)
                } else {
                    LinearGradient(colors: [.loveaRose, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(Image(systemName: "heart.fill").font(.title3).foregroundStyle(.white.opacity(0.9)))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(finder.map { Color.person($0) } ?? .clear, lineWidth: 3))
            .opacity(s.zuletzt.contains(i) ? 0.65 : 1)
            .rotation3DEffect(.degrees(offen ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: offen)
        }
        .buttonStyle(.plain)
        .disabled(!binDran || finder != nil || s.offen.contains(i))
        .accessibilityLabel("Karte \(i + 1)")
        .accessibilityValue(finder.map { "gefunden von \($0 == k.ich ? "dir" : $0.name)" } ?? (offen ? "aufgedeckt" : "verdeckt"))
    }

    /// 8 motifs: up to 4 chat photos or stickers, up to 2 Duell drawings, the rest friendship
    /// stickers. Only synced media, so the partner can load every card.
    static func motiveWaehlen(seed: UInt64) -> [String] {
        var z = Zufall(seed &+ 1)
        let fotos = ChatModell.shared.nachrichten
            .filter { !$0.geloescht && $0.snap == nil }
            .flatMap { n in n.medien.filter { $0.typ == "foto" }.map(\.id) + (n.sticker.map { [$0.medienId] } ?? []) }
        let bilder = SpieleModell.shared.spiele.values.flatMap { $0.bilder.values.flatMap { $0.values } }.sorted()
        var m = z.gemischt(fotos).prefix(4).map { "m:" + $0 }
        m += z.gemischt(bilder).prefix(2).map { "m:" + $0 }
        m += z.gemischt(FreundschaftsSticker.alle.map(\.rawValue)).prefix(8 - m.count).map { "s:" + $0 }
        return m
    }
}

// MARK: - Wie gut kennst du mich? (Z-14.4)

struct KennenSpiel: View {
    let k: SpielKontext

    /// The one asked answers about themselves; the other guesses. "Nochmal" swaps.
    private var befragter: Person { k.starter }
    private var rater: Person { k.starter.partner }
    private var fragen: [KennenFrage]? { (befragter == k.ich ? k.meinZug : k.partnerZug)?.fragen }

    var ende: PartieEnde? {
        guard let fragen, !fragen.isEmpty else { return nil }
        let antworten = k.zuege[befragter] ?? [], tipps = k.zuege[rater] ?? []
        guard antworten.count >= fragen.count, tipps.count >= fragen.count else { return nil }
        let t = Kennen.treffer(antworten: antworten, tipps: tipps)
        var p = SpielPunkte()
        p[rater] = t
        let wer = rater == k.ich ? "Du hast" : "\(rater.name) hat"
        let titel = t >= 4 ? (rater == k.ich ? "Du kennst \(befragter.name) richtig gut!" : "\(rater.name) kennt dich richtig gut!") : "Auflösung"
        return PartieEnde(punkte: p, sieger: t >= 3 ? rater : nil, text: "\(wer) \(t) von \(fragen.count) richtig.", titel: titel)
    }

    var body: some View {
        if let fragen {
            let i = k.mein.count
            if i < fragen.count {
                frageKarte(fragen[i], index: i, anzahl: fragen.count)
                    .id(i)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: i)
            } else if ende == nil {
                VStack(spacing: 16) {
                    FigurView(FigurenModell.shared.aussehen(k.partner), zustand: .spielt, groesse: 150)
                    Text(befragter == k.ich ? "\(k.partner.name) rät noch …" : "\(k.partner.name) antwortet noch …")
                        .font(.headline).foregroundStyle(.secondary)
                }
            } else {
                aufloesung(fragen)
            }
        } else if befragter == k.ich {
            ProgressView("Fragen werden gemischt …")
                .task(id: k.partie) {
                    let f = Kennen.fragen(eigene: Self.eigeneFragen(ich: k.ich, seed: k.seed), seed: k.seed)
                    k.ziehen { $0.fragen = f }
                }
        } else {
            ProgressView("\(k.partner.name) sucht Fragen aus …")
        }
    }

    private func frageKarte(_ frage: KennenFrage, index: Int, anzahl: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(befragter == k.ich ? "Über dich · \(index + 1) von \(anzahl)" : "Rate · \(index + 1) von \(anzahl)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.loveaRose)
                Text(frage.text(fuer: befragter))
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                if befragter != k.ich {
                    Text("Was hat \(befragter.name) wohl gewählt?").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(frage.optionen.indices, id: \.self) { o in
                    Button {
                        k.setzen(o)
                    } label: {
                        Text(frage.optionen[o])
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .sensoryFeedback(.selection, trigger: index)
    }

    private func aufloesung(_ fragen: [KennenFrage]) -> some View {
        let antworten = k.zuege[befragter] ?? [], tipps = k.zuege[rater] ?? []
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(fragen.indices, id: \.self) { i in
                    let a = antworten[i], t = tipps[i]
                    let richtig = a == t
                    VStack(alignment: .leading, spacing: 6) {
                        Text(fragen[i].text(fuer: befragter)).font(.subheadline.weight(.semibold))
                        Label(fragen[i].optionen.indices.contains(a) ? fragen[i].optionen[a] : "–", systemImage: richtig ? "checkmark.circle.fill" : "heart.fill")
                            .foregroundStyle(richtig ? Color.green : Color.person(befragter))
                        if !richtig {
                            Text("\(rater == k.ich ? "Dein" : "\(rater.name)s") Tipp: \(fragen[i].optionen.indices.contains(t) ? fragen[i].optionen[t] : "–")")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                }
            }
            .padding(20)
            .padding(.bottom, 300)
        }
    }

    /// Questions from own data: own answers to the question of the day, own places, the next
    /// date. Options are shuffled by the seed so the true answer isn't always first.
    static func eigeneFragen(ich: Person, seed: UInt64) -> [KennenFrage] {
        var z = Zufall(seed &+ 7)
        var ergebnis: [KennenFrage] = []
        func kurz(_ s: String) -> String { s.count > 60 ? String(s.prefix(59)) + "…" : s }

        let wir = WirModell.shared.zustand
        var texte: [String: String] = [:]
        for f in FrageDesTages.vorrat { texte[f.id] = f.text }
        for f in wir.eigeneFragen { texte[f.id] = f.text }
        let meine = wir.antworten.compactMap { id, a -> (frage: String, antwort: String)? in
            guard let frage = texte[id], let text = a[ich]?.text, !text.isEmpty else { return nil }
            return (frage, kurz(text))
        }.sorted { $0.frage < $1.frage }
        let alleAntworten = Array(Set(meine.map(\.antwort))).sorted()
        for m in z.gemischt(meine).prefix(2) {
            let andere = Array(z.gemischt(alleAntworten.filter { $0 != m.antwort }).prefix(3))
            guard andere.count >= 2 else { break }
            let optionen = z.gemischt([m.antwort] + andere)
            ergebnis.append(KennenFrage(text: "Was hat {name} auf „\(kurz(m.frage))“ geantwortet?", optionen: optionen))
        }

        let orte = Array(Set(OrteModell.shared.orte.filter { $0.person == ich }.map(\.name))).sorted()
        if orte.count >= 2 {
            ergebnis.append(KennenFrage(text: "Welcher eurer Orte ist {name} der liebste?", optionen: Array(z.gemischt(orte).prefix(4))))
        }

        if let treffen = KalenderModell.shared.naechstesTreffen {
            let teile = treffen.datum.split(separator: "-")
            let tag = teile.count == 3 ? "am \(teile[2]).\(teile[1])." : "beim nächsten Treffen"
            var optionen = ["Kuscheln", "Zusammen essen", "Rausgehen", "Einfach reden"]
            if let was = treffen.wasMachenWir, !was.isEmpty { optionen[3] = kurz(was) }
            ergebnis.append(KennenFrage(text: "Worauf freut sich {name} \(tag) am meisten?", optionen: optionen))
        }
        return ergebnis
    }
}
