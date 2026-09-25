import SwiftUI

/// Teil 5: builds `EnergieEingabe` from the live models — HealthKit sleep or hand-entered bed times,
/// the Wasser habit, steps and the training plan.
@MainActor
enum EnergieQuelle {
    static func eingabe(_ p: Person, jetzt: Date = Date()) -> EnergieEingabe {
        let heute = Datum.text(jetzt)
        let health = HealthModell.shared
        let plan = TrainingModell.shared.plan(p)
        return EnergieEingabe(
            naechte: (0..<3).map { health.schlafMinuten(p, Datum.addTage(heute, -$0)) },
            wasser: health.wasserAnzahl(p, heute),
            wasserZiel: health.zielWasser(p),
            stunde: Datum.kalender.component(.hour, from: jetzt),
            schritteGestern: health.schritteAm(p, Datum.addTage(heute, -1)),
            trainingstag: TrainingLogik.tag(plan, datum: heute) != nil,
            ruhetag: plan.ruhetage?.contains(Datum.wochentag(heute)) ?? false,
            planLeer: plan.tage.isEmpty,
            gymInFolge: EnergieLogik.inFolge(heute: heute) { health.gymAbgehakt(p, $0) },
            heuteSchonGym: TrainingModell.shared.sessions(p).contains { Datum.text($0.start) == heute && $0.ende != nil }
        )
    }
}

/// Health tab card (Teil 5): each person's own advice in full, the partner's in one line.
struct EnergieKarte: View {
    @State private var eintragen = false

    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var health: HealthModell { HealthModell.shared }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        let wasser = health.wasserAnzahl(ich, heute)
        EnergieAnsicht(
            ich: ich,
            rat: EnergieLogik.rat(EnergieQuelle.eingabe(ich)),
            partner: ich.partner,
            partnerRat: EnergieLogik.rat(EnergieQuelle.eingabe(ich.partner)),
            wasser: wasser,
            wasserZiel: health.zielWasser(ich),
            wasserZeiten: health.wasserZeiten(ich, heute),
            schlafEintragen: { eintragen = true },
            wasserPlus: { health.setzeWasser(datum: heute, anzahl: wasser + 1) }
        )
        .sheet(isPresented: $eintragen) {
            SchlafEintragenView().presentationDetents([.medium])
        }
    }
}

/// Pure view, no singletons — so the render board can draw it with fixed data.
struct EnergieAnsicht: View {
    var ich: Person
    var rat: EnergieRat
    var partner: Person
    var partnerRat: EnergieRat
    var wasser: Int
    var wasserZiel: Int
    var wasserZeiten: [Date]
    var schlafEintragen: () -> Void
    var wasserPlus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                kopf
                chips
            }
            .accessibilityElement(children: .combine)
            if !rat.gruende.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rat.gruende, id: \.self) { grund in
                        Text(grund).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            wasserZeile
            Button(action: schlafEintragen) {
                Label("Schlaf eintragen", systemImage: "bed.double.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.federnd)
            Divider()
            partnerZeile
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.amber.farbe)
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Energie", systemImage: "bolt.heart.fill")
                .font(.headline)
                .foregroundStyle(HabitFarbe.amber.farbe)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 10) {
                Text(rat.titel).font(.title3.bold())
                stufeBalken
            }
        }
    }

    private var stufeFarbe: Color {
        switch rat.stufe {
        case .hoch: .green
        case .mittel: .yellow
        case .niedrig: .orange
        }
    }

    private var stufeBalken: some View {
        let anzahl = rat.stufe == .hoch ? 3 : (rat.stufe == .mittel ? 2 : 1)
        return HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i < anzahl ? stufeFarbe : stufeFarbe.opacity(0.2)).frame(width: 16, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var chips: some View {
        HStack(spacing: 8) {
            chip(rat.gym, symbol: "dumbbell.fill")
            chip(rat.cardioText, symbol: "figure.run")
        }
    }

    private func chip(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(HabitFarbe.amber.farbe)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(HabitFarbe.amber.farbe.opacity(0.15), in: .capsule)
    }

    private var wasserZeile: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("\(wasser) von \(wasserZiel)", systemImage: "drop.fill").font(.subheadline)
                if let letzte = wasserZeiten.last {
                    Text("zuletzt \(Datum.uhrzeit(letzte))").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                wasserPlus()
                Haptik.leicht()
            } label: {
                Label("Wasser", systemImage: "plus").frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.federnd)
        }
    }

    private var partnerZeile: some View {
        HStack(spacing: 4) {
            Text("\(partner.name):").foregroundStyle(Color.person(partner))
            Text("\(partnerRat.titel.lowercased()), \(partnerRat.gym.lowercased())").foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// Hand-entered bed and wake-up times (Teil 5): Apple Health counts only real sleep.
struct SchlafEintragenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bett: Date
    @State private var auf: Date

    init() {
        let ich = Raum.shared.ich ?? .ahmed
        let heute = Datum.text(Date())
        let health = HealthModell.shared
        if let vorhanden = health.schlafZeitenAm(ich, heute) {
            _bett = State(initialValue: vorhanden.bett)
            _auf = State(initialValue: vorhanden.auf)
        } else if let nacht = health.schlafNacht(ich, heute) {
            _bett = State(initialValue: nacht.von)
            _auf = State(initialValue: nacht.bis)
        } else {
            let heuteDatum = Datum.datum(heute)
            _bett = State(initialValue: Datum.kalender.date(byAdding: .hour, value: -1, to: heuteDatum) ?? heuteDatum)
            _auf = State(initialValue: Datum.kalender.date(byAdding: .hour, value: 7, to: heuteDatum) ?? heuteDatum)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Ins Bett", selection: $bett, displayedComponents: .hourAndMinute)
                    DatePicker("Aufgestanden", selection: $auf, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Apple Health zählt nur den echten Schlaf. Hier trägst du ein, wann du wirklich im Bett warst.")
                }
            }
            .navigationTitle("Schlaf eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
        }
    }

    private func sichern() {
        HealthModell.shared.schlafEintragen(SchlafZeitenD(datum: Datum.text(Date()), bett: bett, auf: auf))
        Haptik.erfolg()
        dismiss()
    }
}
