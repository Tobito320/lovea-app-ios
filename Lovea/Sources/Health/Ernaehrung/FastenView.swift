import Charts
import SwiftUI

// Intervallfasten-Seite wie YAZIO Pro (Ahmed, 27.09.): großer Status mit Ring und live laufender
// Zeit, Start/Ende zum Bearbeiten, Statistik der letzten 7 beendeten Fasten und ein Verlauf zum
// Wischen-Löschen. Wird von außen in einen bestehenden NavigationStack gepusht.

struct FastenView: View {
    @State private var planOffen = false
    @State private var bearbeiten: FastenEintrag?

    private var modell: FastenModell { FastenModell.shared }
    private var ich: Person { modell.ich }
    private var laufend: FastenEintrag? { modell.laufend(ich) }
    private var eintraege: [FastenEintrag] { modell.eintraege(ich) }
    private var beendete: [FastenEintrag] { FastenLogik.beendete(eintraege) }
    /// Plan der aktuellen Auswahl (fürs Plan-Blatt und den Ziel-Strich in der Statistik).
    private var aktuellerPlan: FastenPlan { modell.plan(ich) }
    /// Plan, nach dem der Ring gerade rechnet: beim laufenden Fasten der zum Start gewählte, sonst der aktuelle.
    private var ringPlan: FastenPlan { laufend.map(FastenLogik.planVon) ?? aktuellerPlan }
    /// Eintrag, dessen Start/Ende oben angezeigt werden: der laufende, sonst der zuletzt beendete.
    private var anzeigeEintrag: FastenEintrag? { laufend ?? eintraege.first }

    var body: some View {
        List {
            Section {
                statusKarte
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            Section {
                statistikKarte
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            if !beendete.isEmpty {
                Section("Verlauf") {
                    ForEach(beendete) { e in
                        verlaufZeile(e)
                            .swipeActions(allowsFullSwipe: false) {
                                Button("Löschen", systemImage: "trash", role: .destructive) { modell.loeschen(e) }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .fontDesign(.rounded)
        .navigationTitle("Intervallfasten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(aktuellerPlan.name) { planOffen = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityLabel("Plan: \(aktuellerPlan.name), ändern")
            }
        }
        .sheet(isPresented: $planOffen) { planBlatt }
        .sheet(item: $bearbeiten) { e in FastenBearbeitenBlatt(eintrag: e) { modell.aendern($0) } }
    }

    // MARK: - Status

    private var statusKarte: some View {
        VStack(spacing: 20) {
            if let laufend {
                TimelineView(.periodic(from: .now, by: 1)) { kontext in
                    ring(laufend: laufend, jetzt: kontext.date)
                }
            } else {
                ring(laufend: nil, jetzt: Date())
            }
            startEndeZeile
            aktionsKnopf
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .healthKarte(ErnaehrungStil.akzent)
    }

    private func ring(laufend: FastenEintrag?, jetzt: Date) -> some View {
        let anteil = laufend.map { FastenLogik.fortschritt(start: $0.start, plan: ringPlan, jetzt: jetzt) } ?? 0
        let vergangen = laufend.map { FastenLogik.vergangen(start: $0.start, jetzt: jetzt) } ?? 0
        return VStack(spacing: 14) {
            Text(laufend != nil ? "Du fastest!" : "Essenszeit").font(.title2.weight(.heavy))
            ZStack {
                Circle().stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                Circle()
                    .trim(from: 0, to: CGFloat(anteil))
                    .stroke(ErnaehrungStil.akzent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(FastenLogik.zeitText(vergangen))
                        .font(.title.weight(.heavy)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    Text(laufend != nil ? "von \(ringPlan.stunden) h" : "Bereit?")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
            .frame(width: 180, height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(laufend != nil
                ? "\(FastenLogik.zeitText(vergangen)) von \(ringPlan.stunden) Stunden gefastet"
                : "Kein Fasten läuft")
        }
    }

    private var startEndeZeile: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                zeitFeld("Fasten Start", anzeigeEintrag.map { FastenLogik.zeitpunktText($0.start) } ?? "–")
                zeitFeld("Fasten Ende", endeText)
            }
            Spacer(minLength: 8)
            if let anzeigeEintrag {
                Button("Bearbeiten") { bearbeiten = anzeigeEintrag }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func zeitFeld(_ titel: String, _ wert: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote).foregroundStyle(.secondary)
            Text(wert).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }

    /// Beim laufenden Fasten das geplante Ende (Start + Stunden), sonst das tatsächliche.
    private var endeText: String {
        guard let anzeigeEintrag else { return "–" }
        if let ende = anzeigeEintrag.ende { return FastenLogik.zeitpunktText(ende) }
        let geplant = FastenLogik.geplantesEnde(start: anzeigeEintrag.start, plan: ringPlan)
        return "\(FastenLogik.zeitpunktText(geplant)) (geplant)"
    }

    private var aktionsKnopf: some View {
        Button {
            if let laufend { modell.beenden(laufend) } else { modell.starten() }
            Haptik.erfolg()
        } label: {
            Text(laufend != nil ? "Fasten beenden" : "Fasten starten")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(laufend != nil ? .orange : ErnaehrungStil.akzent)
        .buttonBorderShape(.capsule)
    }

    // MARK: - Statistik

    /// Die letzten 7 beendeten, ältestes zuerst (Balken links nach rechts wie in der Analyse).
    private var letzte7: [FastenEintrag] { Array(beendete.prefix(7).reversed()) }

    private var statistikKarte: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deine Statistik").font(.title2.weight(.heavy))
            if letzte7.isEmpty {
                Text("Noch kein beendetes Fasten.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                statistikChart
                kennzahlen
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(ErnaehrungStil.akzent)
    }

    private var statistikChart: some View {
        Chart {
            ForEach(letzte7) { e in
                BarMark(x: .value("Tag", e.start, unit: .day), y: .value("Stunden", FastenLogik.dauerStunden(e) ?? 0))
                    .foregroundStyle(FastenLogik.geschafft(e) ? ErnaehrungStil.akzent : Color.orange)
                    .cornerRadius(4)
            }
            RuleMark(y: .value("Ziel", aktuellerPlan.stunden))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary)
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 160)
    }

    private var kennzahlen: some View {
        HStack(spacing: 0) {
            kennzahl("\(ErnaehrungLogik.zahl(FastenLogik.durchschnittStunden(beendete))) h", "Schnitt")
            kennzahl("\(ErnaehrungLogik.zahl(FastenLogik.laengstesStunden(beendete))) h", "Längstes")
            kennzahl("\(FastenLogik.serie(eintraege))", "Serie")
        }
    }

    private func kennzahl(_ wert: String, _ titel: String) -> some View {
        VStack(spacing: 2) {
            Text(wert).font(.title3.weight(.bold)).monospacedDigit()
            Text(titel).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Verlauf

    private func verlaufZeile(_ e: FastenEintrag) -> some View {
        let geschafft = FastenLogik.geschafft(e)
        return HStack(spacing: 12) {
            Image(systemName: geschafft ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(geschafft ? ErnaehrungStil.akzent : Color.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(FastenLogik.planVon(e).name).font(.subheadline.weight(.semibold))
                Text("\(FastenLogik.zeitpunktText(e.start)) – \(e.ende.map(FastenLogik.zeitpunktText) ?? "–")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let dauer = FastenLogik.dauerStunden(e) {
                Text("\(ErnaehrungLogik.zahl(dauer)) h").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plan-Blatt

    private var planBlatt: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(FastenPlan.allCases) { p in planZeile(p) }
                }
                .padding(16)
            }
            .fontDesign(.rounded)
            .navigationTitle("Plan wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { planOffen = false } }
            }
        }
        .presentationDetents([.large])
    }

    private func planZeile(_ p: FastenPlan) -> some View {
        let ausgewaehlt = p == aktuellerPlan
        return Button {
            modell.planSetzen(p)
            Haptik.auswahl()
            planOffen = false
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.headline.weight(.bold))
                    Text(p.beschreibung).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if ausgewaehlt {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(ErnaehrungStil.akzent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityAddTraits(ausgewaehlt ? [.isSelected] : [])
    }
}

// MARK: - Bearbeiten-Blatt

/// Start ändern (laufendes Fasten) oder Start und Ende (beendetes).
private struct FastenBearbeitenBlatt: View {
    let eintrag: FastenEintrag
    let sichern: (FastenEintrag) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var ende: Date

    private var laeuftNoch: Bool { eintrag.ende == nil }

    init(eintrag: FastenEintrag, sichern: @escaping (FastenEintrag) -> Void) {
        self.eintrag = eintrag
        self.sichern = sichern
        _start = State(initialValue: eintrag.start)
        _ende = State(initialValue: eintrag.ende ?? eintrag.start)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $start)
                if !laeuftNoch {
                    DatePicker("Ende", selection: $ende, in: start...)
                }
            }
            .fontDesign(.rounded)
            .navigationTitle("Fasten bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var neu = eintrag
                        neu.start = start
                        if !laeuftNoch { neu.ende = ende }
                        sichern(neu)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
