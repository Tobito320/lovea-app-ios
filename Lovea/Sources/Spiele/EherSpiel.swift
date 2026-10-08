import SwiftUI

// MARK: - Wer von uns ist eher? (beide tippen geheim, dann Auflösung)

struct EherSpiel: View {
    let k: SpielKontext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Fragen, deren Auflösung schon gezeigt wurde. Die aktuelle Frage ist `weiter`.
    @State private var weiter = 0

    private var aussagen: [String] { Eher.aussagen(pool: Eher.pool, spiel: k.spiel.id, partie: k.partie) }
    private var beide: Int { min(k.mein.count, k.partnerZuege.count) }

    var ende: PartieEnde? {
        guard aussagen.count == Eher.anzahl else { return nil }
        let s = Eher.stand(zuege: k.zuege)
        return s.fertig >= Eher.anzahl ? Eher.ende(s) : nil
    }

    var body: some View {
        let liste = aussagen
        let aufgedeckt = beide > weiter
        return Group {
            if liste.count < Eher.anzahl {
                Text("Die Aussagen konnten nicht geladen werden.")
                    .foregroundStyle(.secondary)
            } else if weiter >= Eher.anzahl {
                abschluss
            } else {
                frage(liste[weiter], weiter, aufgedeckt: aufgedeckt)
            }
        }
        .padding()
        .onAppear { weiter = min(beide, Eher.anzahl) }
        // Kein Timer im Hintergrund: die Aufgaben-Zeit gilt nur, solange die Auflösung zu sehen ist.
        .task(id: aufgedeckt ? weiter : -1) {
            guard aufgedeckt else { return }
            try? await Task.sleep(for: .seconds(reduceMotion ? 2.0 : 2.8))
            guard !Task.isCancelled else { return }
            naechste()
        }
        .sensoryFeedback(trigger: beide) { alt, neu in
            guard neu > alt, neu >= 1 else { return nil }
            let gleich = Eher.gleich(k.mein, k.partnerZuege, frage: neu - 1)
            let wert: SensoryFeedback = gleich ? .success : .impact(weight: .light)
            return wert
        }
        .sensoryFeedback(.impact(weight: .light), trigger: k.mein.count)
    }

    private func naechste() {
        guard weiter < Eher.anzahl, beide > weiter else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { weiter += 1 }
    }

    // MARK: - Frage

    private func frage(_ text: String, _ q: Int, aufgedeckt: Bool) -> some View {
        let meine = k.mein.indices.contains(q) ? Eher.person(wahl: k.mein[q]) : nil
        let seine = k.partnerZuege.indices.contains(q) ? Eher.person(wahl: k.partnerZuege[q]) : nil
        let partnerFertig = k.partnerZuege.count > q
        return VStack(spacing: 20) {
            punkte
            Text("Aussage \(q + 1) von \(Eher.anzahl)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 110)
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(.secondarySystemBackground)))
                .id(q)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            if aufgedeckt, let m = meine, let s = seine {
                aufloesung(meine: m, seine: s)
            } else {
                auswahl(meine: meine, q: q)
                Text(meine == nil ? "Tippe geheim auf eine Person." : (partnerFertig ? "\(k.partner.name) hat geantwortet. Gleich geht es los …" : "Warte auf \(k.partner.name) …"))
                    .font(.subheadline)
                    .foregroundStyle(meine == nil ? Color.loveaRose : .secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
    }

    private func auswahl(meine: Person?, q: Int) -> some View {
        HStack(spacing: 16) {
            ForEach([k.ich, k.partner], id: \.self) { p in
                Button {
                    guard k.mein.count == q else { return }
                    k.setzen(Eher.wahl(p))
                } label: {
                    VStack(spacing: 8) {
                        FigurKopf(person: p, groesse: 88, zustand: meine == p ? .lacht : .ruhig)
                        Text(p == k.ich ? "Ich" : p.name).font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(meine == p ? Color.loveaRose.opacity(0.2) : Color(.tertiarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(meine == p ? Color.loveaRose : .clear, lineWidth: 2)
                    )
                    .scaleEffect(meine == p ? 1.04 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: meine)
                }
                .buttonStyle(.plain)
                .disabled(meine != nil)
                .accessibilityLabel(p == k.ich ? "Ich" : p.name)
            }
        }
    }

    private func aufloesung(meine: Person, seine: Person) -> some View {
        let gleich = meine == seine
        return VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                stimme(titel: "Du tippst auf", person: meine, gleich: gleich)
                stimme(titel: "\(k.partner.name) tippt auf", person: seine, gleich: gleich)
            }
            Label(gleich ? "Gleich!" : "Verschieden", systemImage: gleich ? "heart.fill" : "arrow.left.arrow.right")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(gleich ? Color.loveaRose : .secondary)
                .symbolEffect(.bounce, options: .nonRepeating, value: weiter)
            Text("Tippen für die nächste Aussage")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { naechste() }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Du tippst auf \(meine.name), \(k.partner.name) tippt auf \(seine.name). \(gleich ? "Gleich" : "Verschieden")")
    }

    private func stimme(titel: String, person: Person, gleich: Bool) -> some View {
        VStack(spacing: 6) {
            Text(titel).font(.caption).foregroundStyle(.secondary)
            FigurKopf(person: person, groesse: 84, zustand: gleich ? .lacht : .ruhig)
                .overlay(Circle().strokeBorder(gleich ? Color.loveaRose : .clear, lineWidth: 3))
            Text(person.name).font(.headline)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fortschritt

    /// Eine Zeile mit zehn Punkten: Herz = gleich, grau = verschieden. Nur aufgedeckte Fragen
    /// verraten etwas.
    private var punkte: some View {
        let gezeigt = min(weiter, Eher.anzahl)
        let treffer = (0..<gezeigt).filter { Eher.gleich(k.mein, k.partnerZuege, frage: $0) }.count
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<Eher.anzahl, id: \.self) { i in
                    if i < gezeigt {
                        Image(systemName: Eher.gleich(k.mein, k.partnerZuege, frage: i) ? "heart.fill" : "circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Eher.gleich(k.mein, k.partnerZuege, frage: i) ? Color.loveaRose : Color(.tertiaryLabel))
                    } else {
                        Image(systemName: i == gezeigt ? "circle.dotted" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(i == gezeigt ? Color.loveaRose : Color(.quaternaryLabel))
                    }
                }
            }
            Text("\(treffer) von \(max(gezeigt, 0)) gleich")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private var abschluss: some View {
        let s = Eher.stand(zuege: k.zuege)
        return VStack(spacing: 16) {
            punkte
            HStack(spacing: -10) {
                FigurKopf(person: k.ich, groesse: 80, zustand: .lacht)
                FigurKopf(person: k.partner, groesse: 80, zustand: .lacht)
            }
            Text("\(s.gleich) von \(Eher.anzahl) gleich")
                .font(.system(.title, design: .rounded).weight(.bold))
            Spacer(minLength: 0)
        }
    }
}
