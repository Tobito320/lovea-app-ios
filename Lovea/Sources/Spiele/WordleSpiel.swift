import SwiftUI

// MARK: - Wordle-Duell (dasselbe Tageswort für beide, 6 Versuche)

struct WordleSpiel: View {
    let k: SpielKontext
    @State private var eingabe = ""
    @State private var meldung: String?
    @State private var fehlversuche = 0
    /// Reihen, die schon beim Öffnen da waren, drehen sich nicht noch einmal.
    @State private var anfang: Int
    /// Start des eigenen Bretts, für die Zeit beim Gleichstand.
    @State private var start = Date()

    init(k: SpielKontext) {
        self.k = k
        _anfang = State(initialValue: k.meinZug?.texte?.count ?? 0)
    }

    // MARK: Daten

    private var ziel: String { Wordle.ziel(woerter: Wordle.woerter, tag: Wordle.tag(k.spiel.zeit), partie: k.partie) }
    private var meine: [String] { k.meinZug?.texte ?? [] }
    private var seine: [String] { k.partnerZug?.texte ?? [] }

    private func lauf(_ p: Person) -> Wordle.Lauf {
        let z = p == k.ich ? k.meinZug : k.partnerZug
        return Wordle.lauf(tipps: z?.texte ?? [], zeiten: z?.zuege ?? [], ziel: ziel)
    }

    var ende: PartieEnde? {
        guard !ziel.isEmpty else { return nil }
        return Wordle.ende(ahmed: lauf(.ahmed), annika: lauf(.annika), ziel: ziel)
    }

    private var kannTippen: Bool {
        !ziel.isEmpty && !lauf(k.ich).fertig && ende == nil
    }

    // MARK: Ansicht

    var body: some View {
        GeometryReader { geo in
            let kachel = Self.kachelGroesse(breite: geo.size.width, hoehe: geo.size.height)
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    brett(kachel)
                    gegner
                }
                Text(status)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(meldung == nil ? Color.secondary : Color.loveaRose)
                    .frame(height: 20)
                Spacer(minLength: 0)
                tastaturLeiste(breite: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .sensoryFeedback(.error, trigger: fehlversuche)
        .sensoryFeedback(.selection, trigger: eingabe)
        .sensoryFeedback(.impact(weight: .medium), trigger: meine.count)
        .overlay {
            if ziel.isEmpty { Text("Die Wortliste konnte nicht geladen werden.").foregroundStyle(.secondary) }
        }
    }

    private static func kachelGroesse(breite: CGFloat, hoehe: CGFloat) -> CGFloat {
        let nachBreite = (breite - 24 - 62 - 5 * 6) / 5
        let nachHoehe = (hoehe - 265) / 6 - 6
        return max(28, min(54, nachBreite, nachHoehe))
    }

    private var status: String {
        if let meldung { return meldung }
        let ich = lauf(k.ich)
        if ende != nil { return "Das Wort war \(Wordle.norm(ziel))" }
        if ich.gewonnen { return "Gelöst in \(ich.versuche)! Warte auf \(k.partner.name) …" }
        if ich.fertig { return "Leider nicht. Warte auf \(k.partner.name) …" }
        return "Versuch \(meine.count + 1) von \(Wordle.versuche)"
    }

    // MARK: Brett

    private func brett(_ kachel: CGFloat) -> some View {
        VStack(spacing: 6) {
            ForEach(0..<Wordle.versuche, id: \.self) { i in
                if i < meine.count {
                    WordleReihe(
                        buchstaben: Array(meine[i]),
                        farben: Wordle.bewerten(meine[i], ziel: ziel),
                        animiert: i >= anfang,
                        kachel: kachel
                    )
                } else if i == meine.count && kannTippen {
                    WordleReihe(buchstaben: Array(eingabe), farben: nil, animiert: false, kachel: kachel)
                        .modifier(WordleWackeln(animatableData: CGFloat(fehlversuche)))
                } else {
                    WordleReihe(buchstaben: [], farben: nil, animiert: false, kachel: kachel)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Fortschritt des Gegners: nur Farben, keine Buchstaben.
    private var gegner: some View {
        VStack(spacing: 4) {
            Text(k.partner.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 48)
            VStack(spacing: 2) {
                ForEach(0..<Wordle.versuche, id: \.self) { i in
                    HStack(spacing: 2) {
                        let farben = i < seine.count ? Wordle.bewerten(seine[i], ziel: ziel) : []
                        ForEach(0..<Wordle.laenge, id: \.self) { j in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(farben.indices.contains(j) ? farben[j].farbe : Color(.tertiarySystemFill))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: seine.count)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(k.partner.name): \(seine.count) von \(Wordle.versuche) Versuchen\(lauf(k.partner).gewonnen ? ", gelöst" : "")")
    }

    // MARK: Tastatur

    private func tastaturLeiste(breite: CGFloat) -> some View {
        let farben = Wordle.tastaturFarben(tipps: meine, ziel: ziel)
        let taste = max(26, min(36, (breite - 24 - 10 * 5) / 11))
        return VStack(spacing: 6) {
            ForEach(Array(Wordle.tastatur.enumerated()), id: \.offset) { zeile, buchstaben in
                HStack(spacing: 5) {
                    if zeile == 2 {
                        sondertaste("Enter", symbol: "return", breite: taste * 1.5, hoehe: taste * 1.45) { abschicken() }
                    }
                    ForEach(Array(buchstaben), id: \.self) { b in
                        Button { tippen(b) } label: {
                            Text(String(b))
                                .font(.system(size: taste * 0.55, weight: .semibold, design: .rounded))
                                .foregroundStyle(farben[b] == nil ? Color.primary : Color.white)
                                .frame(width: taste, height: taste * 1.45)
                                .background(RoundedRectangle(cornerRadius: 6).fill(farben[b]?.farbe ?? Color(.tertiarySystemFill)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(b))
                        .accessibilityValue(farben[b].map(\.beschreibung) ?? "")
                    }
                    if zeile == 2 {
                        sondertaste("Löschen", symbol: "delete.left", breite: taste * 1.5, hoehe: taste * 1.45) { loeschen() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(!kannTippen)
        .opacity(kannTippen ? 1 : 0.5)
    }

    private func sondertaste(_ name: String, symbol: String, breite: CGFloat, hoehe: CGFloat, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: breite, height: hoehe)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.quaternarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    // MARK: Eingabe

    private func tippen(_ b: Character) {
        guard kannTippen, eingabe.count < Wordle.laenge else { return }
        meldung = nil
        eingabe.append(b)
    }

    private func loeschen() {
        guard kannTippen, !eingabe.isEmpty else { return }
        meldung = nil
        eingabe.removeLast()
    }

    private func abschicken() {
        guard kannTippen else { return }
        guard eingabe.count == Wordle.laenge else {
            fehler("Zu kurz")
            return
        }
        guard Wordle.gueltig(eingabe, in: Wordle.woerter) else {
            fehler("Nicht in der Wortliste")
            return
        }
        let n = meine.count
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let tipp = Wordle.norm(eingabe)
        // Atomar: nur anhängen, wenn seit diesem Render nichts dazukam (Doppeltipp).
        k.ziehen { z in
            var t = z.texte ?? []
            guard t.count == n, z.zuege.count == n else { return }
            t.append(tipp)
            z.texte = t
            z.zuege.append(ms)
        }
        eingabe = ""
        meldung = nil
    }

    private func fehler(_ text: String) {
        meldung = text
        withAnimation(.linear(duration: 0.4)) { fehlversuche += 1 }
    }
}

// MARK: - Bausteine

private extension Wordle.Farbe {
    var farbe: Color {
        switch self {
        case .richtig: Color(red: 0.33, green: 0.65, blue: 0.38)
        case .vorhanden: Color(red: 0.85, green: 0.66, blue: 0.2)
        case .fehlt: Color(red: 0.36, green: 0.37, blue: 0.4)
        }
    }

    var beschreibung: String {
        switch self {
        case .richtig: "an der richtigen Stelle"
        case .vorhanden: "im Wort, aber woanders"
        case .fehlt: "nicht im Wort"
        }
    }
}

/// Eine Reihe aus fünf Kacheln. Mit `farben` ist sie ausgewertet und dreht sich (gestaffelt) auf.
private struct WordleReihe: View {
    let buchstaben: [Character]
    let farben: [Wordle.Farbe]?
    let animiert: Bool
    let kachel: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gedreht = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<Wordle.laenge, id: \.self) { i in
                let b: Character? = buchstaben.indices.contains(i) ? buchstaben[i] : nil
                ZStack {
                    vorne(b)
                        .rotation3DEffect(.degrees(farben != nil && gedreht ? 90 : 0), axis: (x: 1, y: 0, z: 0))
                        .opacity(farben != nil && gedreht ? 0 : 1)
                    if let farben, farben.indices.contains(i) {
                        hinten(b, farben[i])
                            .rotation3DEffect(.degrees(gedreht ? 0 : -90), axis: (x: 1, y: 0, z: 0))
                            .opacity(gedreht ? 1 : 0)
                    }
                }
                .frame(width: kachel, height: kachel)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45).delay(Double(i) * 0.18), value: gedreht)
            }
        }
        .onAppear {
            if animiert && !reduceMotion {
                gedreht = true
            } else {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { gedreht = true }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschriftung)
    }

    private func vorne(_ b: Character?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(b == nil ? Color(.quaternaryLabel) : Color(.secondaryLabel), lineWidth: 2)
            if let b {
                Text(String(b))
                    .font(.system(size: kachel * 0.55, weight: .bold, design: .rounded))
                    .scaleEffect(1)
            }
        }
    }

    private func hinten(_ b: Character?, _ f: Wordle.Farbe) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(f.farbe)
            if let b {
                Text(String(b))
                    .font(.system(size: kachel * 0.55, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var beschriftung: String {
        guard !buchstaben.isEmpty else { return "leere Reihe" }
        guard let farben else { return String(buchstaben) }
        return zip(buchstaben, farben).map { "\($0) \($1.beschreibung)" }.joined(separator: ", ")
    }
}

/// Seitliches Wackeln bei ungültigem Wort.
private struct WordleWackeln: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
