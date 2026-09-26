import SwiftUI

/// Numbers of the Verlauf tab: finished strength runs to counts per muscle group and per exercise.
/// Pure, no state. Sets per group are the sum over its parts (`MuskelLogik.teile`), like the Körper tab.
enum VerlaufLogik {
    /// One finished strength run with its sets. `tag` is `yyyy-MM-dd` of the session start.
    struct Lauf: Equatable {
        let session: String
        let tag: String
        let uebung: Uebung
        let saetze: [PlanSatz]
    }

    struct Zaehler: Equatable {
        var sessions: Set<String> = []
        var saetze = 0.0
        var einheiten: Int { sessions.count }

        mutating func zaehlen(_ session: String, _ n: Double) {
            sessions.insert(session)
            saetze += n
        }
    }

    struct Zeitraeume: Equatable {
        var woche = Zaehler()
        var monat = Zaehler()
        var gesamt = Zaehler()

        mutating func zaehlen(_ l: Lauf, saetze n: Double, heute: String, montag: String) {
            gesamt.zaehlen(l.session, n)
            if l.tag.prefix(7) == heute.prefix(7) { monat.zaehlen(l.session, n) }
            if Datum.montagDerWoche(l.tag) == montag { woche.zaehlen(l.session, n) }
        }
    }

    struct Tageseintrag: Equatable, Identifiable {
        let tag: String
        /// "60 × 8 · 65 × 8"
        let text: String
        var id: String { tag }
    }

    struct UebungsVerlauf: Equatable, Identifiable {
        let uebung: Uebung
        var monat = 0
        var gesamt = 0
        /// Newest first, one entry per day.
        var tage: [Tageseintrag] = []
        var e1rm: Double?
        var id: String { uebung.id }
    }

    private static let deutsch = Locale(identifier: "de_DE")

    /// Finished runs with sets, oldest first. Cardio, own exercises (not in the catalog) and runs
    /// ticked without sets give nothing.
    static func laeufe(_ sessions: [GymSession], katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [Lauf] {
        sessions.sorted { $0.start < $1.start }.flatMap { s in
            s.laeufe.compactMap { l in
                guard l.fertig, let n = l.saetze, !n.isEmpty, let u = katalog(l.uebung), !u.istCardio else { return nil }
                return Lauf(session: s.id, tag: Datum.text(s.start), uebung: u, saetze: n)
            }
        }
    }

    /// Week (Mo to So), month and total per group. Groups without a run are missing.
    static func gruppen(_ laeufe: [Lauf], heute: String) -> [MuskelGruppe: Zeitraeume] {
        let montag = Datum.montagDerWoche(heute)
        var ergebnis: [MuskelGruppe: Zeitraeume] = [:]
        for l in laeufe {
            var proGruppe: [MuskelGruppe: Double] = [:]
            for (teil, faktor) in MuskelLogik.teile(l.uebung) { proGruppe[teil.gruppe, default: 0] += faktor * Double(l.saetze.count) }
            for (g, n) in proGruppe { ergebnis[g, default: Zeitraeume()].zaehlen(l, saetze: n, heute: heute, montag: montag) }
        }
        return ergebnis
    }

    static func uebung(_ u: Uebung, _ laeufe: [Lauf], heute: String) -> UebungsVerlauf {
        var v = UebungsVerlauf(uebung: u)
        var sessions = Set<String>(), imMonat = Set<String>()
        var proTag: [(tag: String, saetze: [PlanSatz])] = []
        for l in laeufe where l.uebung.id == u.id {
            sessions.insert(l.session)
            if l.tag.prefix(7) == heute.prefix(7) { imMonat.insert(l.session) }
            if let i = proTag.firstIndex(where: { $0.tag == l.tag }) {
                proTag[i].saetze += l.saetze
            } else {
                proTag.append((tag: l.tag, saetze: l.saetze))
            }
            if let best = l.saetze.compactMap(e1rm).max() { v.e1rm = max(v.e1rm ?? 0, best) }
        }
        v.gesamt = sessions.count
        v.monat = imMonat.count
        v.tage = proTag.sorted { $0.tag > $1.tag }.map { Tageseintrag(tag: $0.tag, text: $0.saetze.map(satzText).joined(separator: " · ")) }
        return v
    }

    /// Exercises that load the group (direct or helping), most done first.
    static func uebungen(_ gruppe: MuskelGruppe, _ laeufe: [Lauf], heute: String) -> [UebungsVerlauf] {
        var gesehen = Set<String>()
        var liste: [Uebung] = []
        for l in laeufe where MuskelLogik.teile(l.uebung).contains(where: { $0.teil.gruppe == gruppe }) {
            if gesehen.insert(l.uebung.id).inserted { liste.append(l.uebung) }
        }
        return liste.map { uebung($0, laeufe, heute: heute) }.sorted {
            $0.gesamt != $1.gesamt ? $0.gesamt > $1.gesamt : $0.uebung.name < $1.uebung.name
        }
    }

    /// Epley: kg × (1 + Wdh / 30); one rep is the weight itself. Sets without weight give nil.
    static func e1rm(_ s: PlanSatz) -> Double? {
        guard let kg = s.kg, kg > 0, s.wdh > 0 else { return nil }
        return s.wdh == 1 ? kg : kg * (1 + Double(s.wdh) / 30)
    }

    /// "62,5 × 8", or "8 Wdh" without weight.
    static func satzText(_ s: PlanSatz) -> String {
        guard let kg = s.kg, kg > 0 else { return "\(s.wdh) Wdh" }
        return "\(zahl(kg)) × \(s.wdh)"
    }

    /// "12", "4,5".
    static func zahl(_ d: Double) -> String {
        d.formatted(.number.precision(.fractionLength(0...1)).locale(deutsch))
    }

    static func saetzeText(_ d: Double) -> String { "\(zahl(d)) \(d == 1 ? "Satz" : "Sätze")" }

    /// "3× · 9 Sätze"
    static func kurz(_ z: Zaehler) -> String { "\(z.einheiten)× · \(saetzeText(z.saetze))" }
}

/// Where the Verlauf stack can go.
enum VerlaufZiel: Hashable {
    case gruppe(MuskelGruppe)
    case uebung(String)
}

// MARK: - Screens

/// Health tab "Verlauf": muscle groups as tiles, tap opens the group, tap on an exercise its history.
struct VerlaufView: View {
    @State private var pfad: [VerlaufZiel] = []
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let sessions = TrainingModell.shared.sessions(ich)
        let laeufe = VerlaufLogik.laeufe(sessions)
        let heute = Datum.text(Date())
        NavigationStack(path: $pfad) {
            ScrollView {
                VerlaufInhalt(laeufe: laeufe, heute: heute) { g in
                    Haptik.auswahl()
                    pfad.append(.gruppe(g))
                }
            }
            .navigationTitle("Verlauf")
            .navigationDestination(for: VerlaufZiel.self) { ziel in seite(ziel, sessions, laeufe, heute) }
        }
    }

    @ViewBuilder
    private func seite(_ ziel: VerlaufZiel, _ sessions: [GymSession], _ laeufe: [VerlaufLogik.Lauf], _ heute: String) -> some View {
        switch ziel {
        case .gruppe(let g):
            ScrollView {
                VerlaufGruppe(
                    gruppe: g, laeufe: laeufe, heute: heute,
                    wochenSaetze: MuskelLogik.wochenSaetze(sessions, woche: heute),
                    erholung: MuskelLogik.erholung(sessions, jetzt: Date())
                ) { id in
                    Haptik.auswahl()
                    pfad.append(.uebung(id))
                }
            }
            .navigationTitle(g.name)
            .navigationBarTitleDisplayMode(.inline)
        case .uebung(let id):
            if let u = UebungsKatalog.nachId[id] {
                ScrollView { VerlaufUebung(verlauf: VerlaufLogik.uebung(u, laeufe, heute: heute)) }
                    .navigationTitle(u.name)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

/// The tile page (render board): two columns, nine groups in fixed order.
struct VerlaufInhalt: View {
    let laeufe: [VerlaufLogik.Lauf]
    let heute: String
    var oeffnen: (MuskelGruppe) -> Void = { _ in }

    var body: some View {
        if laeufe.isEmpty { VerlaufLeer() } else { raster }
    }

    private var raster: some View {
        let stand = VerlaufLogik.gruppen(laeufe, heute: heute)
        let gruppen = MuskelGruppe.allCases
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(Array(stride(from: 0, to: gruppen.count, by: 2)), id: \.self) { i in
                GridRow {
                    ForEach(gruppen[i..<min(i + 2, gruppen.count)], id: \.self) { g in
                        VerlaufKachel(gruppe: g, z: stand[g] ?? VerlaufLogik.Zeitraeume()) { oeffnen(g) }
                    }
                }
            }
        }
        .padding(16)
    }
}

private struct VerlaufLeer: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Noch kein Training eingetragen. Im Tab Training startest du dein erstes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 64)
    }
}

private struct VerlaufKachel: View {
    let gruppe: MuskelGruppe
    let z: VerlaufLogik.Zeitraeume
    let oeffnen: () -> Void

    var body: some View {
        Button(action: oeffnen) {
            VStack(alignment: .leading, spacing: 2) {
                Text(gruppe.name).font(.subheadline.weight(.semibold))
                Text(VerlaufLogik.zahl(z.woche.saetze))
                    .font(.title.bold())
                    .monospacedDigit()
                    .foregroundStyle(z.woche.saetze > 0 ? Color.primary : Color.secondary)
                Text(woche).font(.footnote).foregroundStyle(.secondary)
                Text(rest).font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 20, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .foregroundStyle(.primary)
        .accessibilityHint("Öffnet die Muskelgruppe")
    }

    private var woche: String {
        z.woche.einheiten == 0 ? "Sätze diese Woche" : "Sätze · \(z.woche.einheiten)× diese Woche"
    }

    private var rest: String {
        z.gesamt.einheiten == 0 ? "noch nie trainiert" : "Monat \(z.monat.einheiten)× · gesamt \(z.gesamt.einheiten)×"
    }
}

/// One group: sets this week, week / month / total, parts with recovery, exercises.
struct VerlaufGruppe: View {
    let gruppe: MuskelGruppe
    let laeufe: [VerlaufLogik.Lauf]
    let heute: String
    var wochenSaetze: [MuskelTeil: Double] = [:]
    var erholung: [MuskelTeil: Int] = [:]
    var oeffnen: (String) -> Void = { _ in }

    var body: some View {
        let z = VerlaufLogik.gruppen(laeufe, heute: heute)[gruppe] ?? VerlaufLogik.Zeitraeume()
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(VerlaufLogik.zahl(z.woche.saetze)).font(.largeTitle.weight(.bold)).monospacedDigit()
                Text("Sätze diese Woche").font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .padding(.bottom, 8)
            VerlaufZeile(links: "Diese Woche", rechts: VerlaufLogik.kurz(z.woche))
            VerlaufZeile(links: "Dieser Monat", rechts: VerlaufLogik.kurz(z.monat))
            VerlaufZeile(links: "Insgesamt", rechts: VerlaufLogik.kurz(z.gesamt))
            VerlaufAbschnitt(text: "Teile diese Woche")
            teile
            VerlaufAbschnitt(text: "Übungen")
            uebungen
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var teile: some View {
        VStack(spacing: 0) {
            ForEach(MuskelTeil.allCases.filter { $0.gruppe == gruppe }, id: \.self) { t in
                let e = erholung[t] ?? 100
                VerlaufZeile(links: t.name, rechts: teilText(wochenSaetze[t] ?? 0, e), punkt: farbe(MuskelLogik.stufe(e)))
            }
        }
    }

    private func teilText(_ saetze: Double, _ e: Int) -> String {
        e >= 90 ? VerlaufLogik.saetzeText(saetze) : "\(VerlaufLogik.saetzeText(saetze)) · \(e) %"
    }

    /// Recovery colours of the Körper tab: green, coral, rose.
    private func farbe(_ s: ErholungsStufe) -> Color {
        switch s {
        case .erholt: Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
        case .fast: Color(red: 0xFF / 255, green: 0x7A / 255, blue: 0x59 / 255)
        case .muede: Color.loveaRose
        }
    }

    @ViewBuilder
    private var uebungen: some View {
        let liste = VerlaufLogik.uebungen(gruppe, laeufe, heute: heute)
        if liste.isEmpty {
            Text("Noch keine Übung für \(gruppe.name) eingetragen. Sobald du eine trainierst, steht sie hier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
        } else {
            VStack(spacing: 0) {
                ForEach(liste) { u in
                    Button { oeffnen(u.id) } label: { zeile(u) }
                        .buttonStyle(.federnd)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private func zeile(_ u: VerlaufLogik.UebungsVerlauf) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.uebung.name).font(.subheadline.weight(.semibold))
                    Text("\(u.monat)× diesen Monat · \(u.gesamt)× insgesamt").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .padding(.vertical, 6)
            Divider()
        }
        .contentShape(.rect)
    }
}

/// One exercise: best e1RM, month and total, the days with their sets.
struct VerlaufUebung: View {
    let verlauf: VerlaufLogik.UebungsVerlauf

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let e = verlauf.e1rm {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(VerlaufLogik.zahl(e)) kg").font(.largeTitle.weight(.bold)).monospacedDigit()
                    Text("e1RM, geschätztes Maximum für eine Wiederholung").font(.subheadline).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.bottom, 8)
            }
            VerlaufZeile(links: "Diesen Monat", rechts: "\(verlauf.monat)×")
            VerlaufZeile(links: "Insgesamt", rechts: "\(verlauf.gesamt)×")
            VerlaufAbschnitt(text: "Tage")
            ForEach(verlauf.tage) { t in
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Datum.anzeige(t.tag)).font(.subheadline.weight(.semibold))
                        Text(t.text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    Divider()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VerlaufZeile: View {
    let links: String
    let rechts: String
    var punkt: Color? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let punkt { Circle().fill(punkt).frame(width: 8, height: 8).accessibilityHidden(true) }
                Text(links)
                Spacer(minLength: 12)
                Text(rechts).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            Divider()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct VerlaufAbschnitt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 22)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
