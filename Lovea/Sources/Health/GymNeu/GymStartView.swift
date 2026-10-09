import SwiftUI
import TipKit

// Neue Gym-Seite (Ahmed, 02.10., Entwurf `Lovea-bilder/gym-entwurf.html`): Woche ohne Zahlen, darunter
// der gewählte Tag, Einchecken als kleine Kapsel, alles Weitere im Drei-Punkte-Menü.

enum GymStartKnopf: Equatable {
    case starten, weiter, fortsetzen

    var titel: String {
        switch self {
        case .starten: "Starten"
        case .weiter: "Weiter"
        case .fortsetzen: "Fortsetzen"
        }
    }

    var symbol: String { self == .fortsetzen ? "arrow.uturn.backward" : "play.fill" }
}

/// Alles, was die Seite zeigt, als Werte (Render-Tafel). `laden` liest die Modelle.
struct GymStartStand {
    var ich: Person
    var woche: KoerperWoche
    var gewaehlt: String
    var heute: String
    var tag: TrainingsTag?
    var statusIch: String
    var statusPartner: String
    var splitName: String?
    var planTage: Int
    /// Nur am heutigen Tag.
    var knopf: GymStartKnopf?
    var vergessen: Bool
    /// Zeitfenster des Studios (`ZeitSchaetzung.slot`), nil = keine feste Uhrzeit.
    var slotMinuten: Int? = nil

    static func bauen(ich: Person, sessions: [Person: [GymSession]], plaene: [Person: TrainingsPlan], gewaehlt: String, jetzt: Date, slotMinuten: Int? = nil) -> GymStartStand {
        let heute = Datum.text(jetzt)
        let plan = plaene[ich] ?? .leer, eigene = sessions[ich] ?? []
        let woche = KoerperWoche.bauen(ich: ich, sessions: sessions, plan: plan, heute: heute, katalog: { UebungsKatalog.nachId[$0] })
        func status(_ p: Person) -> String {
            let name = TrainingLogik.tag(plaene[p] ?? .leer, datum: gewaehlt).map { $0.name.isEmpty ? "Training" : $0.name }
            return GymStartLogik.status(sessions[p] ?? [], datum: gewaehlt, heute: heute, geplant: name, jetzt: jetzt)
        }
        var knopf: GymStartKnopf?
        if gewaehlt == heute {
            if eigene.contains(where: { TrainingLogik.laufend($0, jetzt: jetzt) }) { knopf = .weiter }
            else if TrainingLogik.fortsetzbar(eigene, jetzt: jetzt) != nil { knopf = .fortsetzen }
            else { knopf = .starten }
        }
        return GymStartStand(
            ich: ich, woche: woche, gewaehlt: gewaehlt, heute: heute, tag: TrainingLogik.tag(plan, datum: gewaehlt),
            statusIch: status(ich), statusPartner: status(ich.partner), splitName: plan.splitName,
            planTage: Set(plan.tage.flatMap(\.wochentage)).count, knopf: knopf,
            vergessen: TrainingLogik.vergessen(eigene, jetzt: jetzt) != nil, slotMinuten: slotMinuten
        )
    }
}

struct GymStartAktionen {
    var waehlen: (String) -> Void = { _ in }
    var knopf: () -> Void = {}
    var tag: () -> Void = {}
    var split: () -> Void = {}
    var auschecken: () -> Void = {}
}

/// Reiner Inhalt der Seite (Render-Tafel).
struct GymStartInhalt: View {
    let stand: GymStartStand
    var aktionen = GymStartAktionen()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GymWochenLeiste(woche: stand.woche, gewaehlt: stand.gewaehlt, waehlen: aktionen.waehlen)
            wer.padding(.top, 10)
            if stand.vergessen { vergessen.padding(.top, 14) }
            kopf.padding(.top, 22)
            if let tag = stand.tag, !tag.uebungen.isEmpty {
                ZeitKarte(urteil: ZeitSchaetzung.urteil(tag, slotMinuten: stand.slotMinuten)).padding(.top, 10)
            }
            uebungen.padding(.top, 8)
            Text("SPLIT").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 22)
            split
        }
    }

    private var wer: some View {
        HStack(spacing: 14) {
            person(stand.ich.partner, stand.ich.partner.name, stand.statusPartner)
            person(stand.ich, "Du", stand.statusIch)
        }
        .font(.footnote)
    }

    private func person(_ p: Person, _ name: String, _ status: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Color.person(p)).frame(width: 6, height: 6)
            Text(name).fontWeight(.semibold)
            Text(status).foregroundStyle(.secondary).monospacedDigit()
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var vergessen: some View {
        Button(action: aktionen.auschecken) {
            Label("Auschecken vergessen? Jetzt auschecken", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var kopf: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(GymStartLogik.titel(datum: stand.gewaehlt, heute: stand.heute, tag: stand.tag))
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                if let tag = stand.tag, !tag.uebungen.isEmpty {
                    Text(GymStartLogik.umfang(tag)).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let knopf = stand.knopf {
                Button(action: aktionen.knopf) {
                    Label(knopf.titel, systemImage: knopf.symbol)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .background(Color.primary, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.federnd)
            }
        }
    }

    @ViewBuilder
    private var uebungen: some View {
        if let tag = stand.tag, !tag.uebungen.isEmpty {
            Button(action: aktionen.tag) {
                VStack(spacing: 0) {
                    ForEach(Array(tag.uebungen.enumerated()), id: \.element.id) { i, u in
                        if i > 0 { Divider() }
                        GymUebungZeile(name: u.anzeigeName, unter: TrainingLogik.saetzeText(u))
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet den Tag zum Anpassen")
        } else {
            Text(stand.tag == nil ? (stand.planTage == 0 ? "Noch kein Plan. Such dir unten einen Split aus." : "Kein Training geplant. Erhol dich.") : "Noch keine Übungen. Tipp unten auf den Split.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 14)
        }
    }

    private var split: some View {
        Button(action: aktionen.split) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stand.planTage == 0 ? "Split aussuchen" : (stand.splitName ?? "Eigener Plan")).font(.body.weight(.semibold))
                    Text(stand.planTage == 0 ? "Fertig, geführt oder leer" : "\(stand.planTage) \(stand.planTage == 1 ? "Tag" : "Tage") · tippen zum Ändern")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Eine Übung als Zeile: Name, darunter Sätze. Ohne Karte, Trennlinien setzt die Liste.
struct GymUebungZeile: View {
    let name: String
    let unter: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.body.weight(.semibold)).foregroundStyle(Color.primary).lineLimit(2)
            Text(unter).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

/// Mo bis So ohne Datumszahl. Grün = selbst im Gym gewesen, Ring = heute, gefüllt = gewählt,
/// darunter ein Punkt pro Person, die an dem Tag trainiert hat.
struct GymWochenLeiste: View {
    let woche: KoerperWoche
    let gewaehlt: String
    var waehlen: ((String) -> Void)? = nil

    private static let aufGruen = Color(red: 0x04 / 255, green: 0x24 / 255, blue: 0x0E / 255)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(woche.tage, id: \.datum) { tag in
                Button { waehlen?(tag.datum) } label: { spalte(tag) }
                    .buttonStyle(.plain)
                    .disabled(waehlen == nil)
                    .accessibilityLabel(label(tag))
                    .accessibilityAddTraits(tag.datum == gewaehlt ? .isSelected : [])
            }
        }
    }

    private func spalte(_ tag: KoerperWoche.Tag) -> some View {
        VStack(spacing: 6) {
            kreis(tag)
            HStack(spacing: 3) {
                ForEach(tag.personen, id: \.self) { Circle().fill(Color.person($0)).frame(width: 6, height: 6) }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .contentShape(.rect)
    }

    private func kreis(_ tag: KoerperWoche.Tag) -> some View {
        let an = tag.datum == gewaehlt
        return ZStack {
            if tag.fertig {
                Circle().fill(KoerperFarbe.erholt)
                if an { Circle().strokeBorder(Color.primary, lineWidth: 2).padding(-4) }
            } else if an {
                Circle().fill(Color.primary)
            } else if tag.heute {
                Circle().strokeBorder(Color.primary, lineWidth: 2)
            }
            Text(tag.kuerzel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tag.fertig ? Self.aufGruen : an ? Color(uiColor: .systemBackground) : tag.heute ? Color.primary : Color.secondary)
        }
        .frame(width: 36, height: 36)
    }

    private func label(_ tag: KoerperWoche.Tag) -> String {
        var teile = [TrainingLogik.wochentagName[Datum.wochentag(tag.datum) - 1]]
        if tag.heute { teile.append("heute") }
        if tag.fertig { teile.append("im Gym gewesen") }
        return teile.joined(separator: ", ")
    }
}

private enum GymMenuZiel: Hashable {
    case partner, verlauf, messungen, uebungen, splits, editor
}

/// Die Seite selbst: liest die Modelle, öffnet Einheit, Splits und das Menü im Stapel von Health.
struct GymStartView: View {
    @State private var gewaehlt = Datum.text(Date())
    @State private var ziel: GymMenuZiel?
    @State private var session: String?

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        let stand = GymStartStand.bauen(
            ich: ich, sessions: [ich: modell.sessions(ich), ich.partner: modell.sessions(ich.partner)],
            plaene: [ich: modell.plan(ich), ich.partner: modell.plan(ich.partner)], gewaehlt: gewaehlt, jetzt: Date(),
            slotMinuten: ZeitSchaetzung.slot(StudioGedaechtnis.shared.profil(ich))
        )
        ScrollView {
            GymStartInhalt(stand: stand, aktionen: aktionen(stand))
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
        }
        .navigationTitle("Gym")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .primaryAction) { menue } }
        .navigationDestination(item: $ziel) { seite($0) }
        .navigationDestination(item: $session) { GymSessionView(sessionId: $0) }
        // Die GIFs des eigenen Plans vorab, damit sie im Gym offline laufen (wie im alten Plan).
        .task(id: modell.plan(ich)) { await UebungsMedien.vorladen(modell.plan(ich).tage.flatMap(\.uebungen).map(\.uebung)) }
    }

    private var menue: some View {
        Menu {
            Button("Plan von \(ich.partner.name)", systemImage: "person.2") { ziel = .partner }
            Button("Verlauf", systemImage: "clock.arrow.circlepath") { ziel = .verlauf }
            Button("Messungen", systemImage: "ruler") { ziel = .messungen }
            Button("Übungen", systemImage: "list.bullet") { ziel = .uebungen }
            Button("Split wechseln", systemImage: "square.grid.2x2") { ziel = .splits }
            // Eigenes Ding ohne Plan: leer starten, Übungen und Cardio im Training dazu.
            if modell.laufende(ich) == nil {
                Button("Freies Training", systemImage: "figure.strengthtraining.traditional") {
                    session = modell.einchecken(tag: nil)
                    Haptik.erfolg()
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("Mehr")
        .popoverTip(GymStartMehrTip())
    }

    @ViewBuilder
    private func seite(_ z: GymMenuZiel) -> some View {
        switch z {
        case .partner: TrainingsPlanView(person: ich.partner)
        case .verlauf: GymVerlaufView()
        case .messungen: MessungenView()
        case .uebungen: UebungsSuche()
        case .splits: SplitBibliothekView(person: ich) { ziel = nil }
        case .editor: SplitEditorView(start: TrainingLogik.tag(modell.plan(ich), datum: gewaehlt)?.id)
        }
    }

    private func aktionen(_ stand: GymStartStand) -> GymStartAktionen {
        GymStartAktionen(
            waehlen: { tag in
                Haptik.auswahl()
                withAnimation(Feder.weich) { gewaehlt = tag }
            },
            knopf: { knopf(stand.knopf) },
            tag: { ziel = .editor },
            split: { ziel = .splits },
            auschecken: {
                if let v = modell.vergessene(ich) { modell.auschecken(v.id) }
                Haptik.erfolg()
            }
        )
    }

    private func knopf(_ k: GymStartKnopf?) {
        switch k {
        case .weiter:
            session = modell.laufende(ich)?.id
        case .fortsetzen:
            guard let s = modell.fortsetzbare(ich) else { return }
            modell.auscheckenRueckgaengig(s.id)
            session = s.id
        case .starten:
            session = modell.einchecken(tag: modell.heutigerTag(ich)?.id)
        case nil:
            return
        }
        Haptik.erfolg()
    }
}

/// Health öffnet den Trainingsbereich hierüber: neues Gym für die eigene Person (Schalter an),
/// sonst der alte Plan.
struct GymStartZiel: View {
    let person: Person
    var oeffnen: (HealthZiel) -> Void = { _ in }
    @AppStorage(GymNeu.schluessel) private var neu = true

    var body: some View {
        if neu && person == (Raum.shared.ich ?? .ahmed) {
            GymStartView()
        } else {
            TrainingsPlanView(person: person, oeffnen: oeffnen)
        }
    }
}
