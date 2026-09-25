import SwiftUI

/// Inhalt des Blatts zu einer Muskelgruppe (Tipp auf einen Muskel oder ein Feld): Mini-Figur, Sätze gegen
/// Ziel, Teile mit Punkten, Übungen mit Verlauf und "Nächstes Mal". Der Aufrufer legt es in ein
/// `ScrollView` und ein `.sheet` mit `.presentationDetents([.medium, .large])`.
struct KoerperBlatt: View {
    let daten: KoerperDaten
    let gruppe: MuskelGruppe
    var teil: MuskelTeil?
    var animiert = true
    @State private var offen: Set<String>

    /// `offen`: welche Übungen aufgeklappt starten. Standard: die, deren Haupt-Teil angetippt wurde.
    init(daten: KoerperDaten, gruppe: MuskelGruppe, teil: MuskelTeil? = nil, animiert: Bool = true, offen: Set<String>? = nil) {
        self.daten = daten
        self.gruppe = gruppe
        self.teil = teil
        self.animiert = animiert
        let uebungen = daten.gruppen[gruppe]?.uebungen ?? []
        _offen = State(initialValue: offen ?? Set(uebungen.filter { $0.teil == teil }.map(\.id)))
    }

    private var stufe: ErholungsStufe { daten.stufe(gruppe) }
    private var farbe: Color { KoerperFarbe.stufe(stufe) }
    private var ziel: Int? { daten.ziele.saetze[gruppe] }
    private var teile: [MuskelTeil] { MuskelTeil.allCases.filter { $0.gruppe == gruppe } }
    private var uebungen: [KoerperLogik.UebungsZeile] { daten.gruppen[gruppe]?.uebungen ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            abschnitt("Teile diese Woche")
            ForEach(teile, id: \.self) { teilZeile($0) }
            abschnitt("Übungen")
            if uebungen.isEmpty {
                Text("Noch nichts für \(gruppe.name) gemacht. Plane im Tab Training eine Übung dafür ein.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            ForEach(uebungen) { uebungZeile($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Kopf

    /// Vorne und hinten nebeneinander, aber nur die Seiten, auf denen die Gruppe liegt.
    private var seiten: [Bool] {
        let flaechen = MuskelPfade.figur(daten.person).flaechen
        return [false, true].filter { hinten in
            let seite: MuskelPfade.Seite = hinten ? .hinten : .vorne
            return flaechen.contains { $0.seite == seite && $0.teil.gruppe == gruppe }
        }
    }

    private var kopf: some View {
        HStack(spacing: 14) {
            HStack(spacing: 2) {
                ForEach(seiten, id: \.self) { hinten in
                    MuskelSeite(person: daten.person, hinten: hinten, farbe: { daten.farbe($0) }, markiert: teil, fokus: gruppe, animiert: animiert)
                }
            }
            .frame(height: 132)
            VStack(alignment: .leading, spacing: 2) {
                Text(gruppe.name).font(.system(size: 28, weight: .bold))
                if let teil { Text(teil.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary) }
                Text(unterzeile).font(.footnote).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(KoerperLogik.komma(daten.saetze(gruppe))).font(.system(size: 36, weight: .bold)).monospacedDigit()
                    Text(ziel.map { "von \($0) Sätzen" } ?? "Sätze diese Woche").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                Text(zustand).font(.footnote).foregroundStyle(farbe)
            }
        }
    }

    private var unterzeile: String {
        let g = daten.gruppen[gruppe]
        var teile: [String] = []
        if let rang = daten.ziele.prio.firstIndex(of: gruppe) { teile.append("Priorität \(rang + 1)") }
        teile.append("\(g?.monat ?? 0)× diesen Monat")
        teile.append("\(g?.gesamt ?? 0)× insgesamt")
        return teile.joined(separator: " · ")
    }

    private var zustand: String {
        let p = daten.prozent(gruppe)
        switch stufe {
        case .muede: return "Müde, \(p) %"
        case .fast: return "Fast erholt, \(p) %"
        case .erholt: return "Erholt"
        }
    }

    private func abschnitt(_ titel: String) -> some View {
        Text(titel).font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).padding(.top, 22).padding(.bottom, 4)
    }

    // MARK: Teile

    private func teilZeile(_ t: MuskelTeil) -> some View {
        let satz = daten.woche[t] ?? 0
        let e = daten.prozent(t)
        return HStack(spacing: 12) {
            Text(t.name).font(.body).fontWeight(t == teil ? .bold : .regular)
            Spacer(minLength: 0)
            Punkte(saetze: satz, farbe: farbe)
            Text(e >= 90 ? "\(KoerperLogik.komma(satz)) Sätze" : "\(e) %")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }

    // MARK: Übungen

    private func uebungZeile(_ z: KoerperLogik.UebungsZeile) -> some View {
        let auf = offen.contains(z.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Feder.weich) { if offen.remove(z.id) == nil { offen.insert(z.id) } }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.name).font(.body.weight(.semibold))
                        Text(meta(z)).font(.caption).foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(auf ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(auf ? "aufgeklappt" : "zugeklappt")
            if auf { verlauf(z) }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func meta(_ z: KoerperLogik.UebungsZeile) -> String {
        let zuletzt = z.verlauf.first.map { "zuletzt \($0.tag)" } ?? "noch nie"
        return "\(KoerperLogik.teilName(z.teil)) · \(zuletzt) · \(z.monat)× diesen Monat"
    }

    private func verlauf(_ z: KoerperLogik.UebungsZeile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(z.verlauf.indices, id: \.self) { i in
                let zeile = z.verlauf[i]
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(zeile.tag).font(.footnote.weight(.semibold))
                    Spacer(minLength: 0)
                    Text(zeile.saetze).font(.footnote).foregroundStyle(.secondary).monospacedDigit().multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 5)
            }
            if let v = z.vorschlag { vorschlag(v) }
        }
        .transition(.opacity)
    }

    private func vorschlag(_ v: KoerperLogik.Vorschlag) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nächstes Mal").font(.caption.weight(.semibold)).foregroundStyle(Color(red: 1, green: 0x8F / 255, blue: 0xA3 / 255))
            Text(KoerperLogik.vorschlagText(v)).font(.subheadline)
        }
        .padding(.init(top: 10, leading: 12, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loveaRose.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}

/// Ein Punkt pro Satz, ein halber für einen halben Satz (Mitarbeit). 4 bis 8 Punkte, darüber ein Plus.
private struct Punkte: View {
    let saetze: Double
    let farbe: Color

    var body: some View {
        let n = max(4, min(8, Int(saetze.rounded(.up))))
        HStack(spacing: 3) {
            ForEach(0..<n, id: \.self) { i in punkt(min(1, max(0, saetze - Double(i)))) }
            if saetze > 8 { Text("+").font(.system(size: 11)).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(KoerperLogik.komma(saetze)) Sätze")
    }

    private func punkt(_ anteil: Double) -> some View {
        Circle()
            .fill(anteil >= 1 ? farbe : Color.white.opacity(0.14))
            .overlay(alignment: .leading) { if anteil > 0 && anteil < 1 { Rectangle().fill(farbe).frame(width: 3.5) } }
            .clipShape(Circle())
            .frame(width: 7, height: 7)
    }
}
