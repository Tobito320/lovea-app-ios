import SwiftUI

/// "Gerät defekt gemeldet am ...": Hinweis oben in der Übungsansicht. Reines SwiftUI (Knöpfe, keine
/// TextFields), damit `ImageRenderer` es zeichnen kann.
struct DefektKarte: View {
    let notiz: DefektNotiz
    let heute: String
    /// Die Ausweich-Übung, nil = kein Vorschlag (Cardio, eigene Übung, schon Sätze gemacht).
    var vorschlag: Uebung? = nil
    var wiederInOrdnung: () -> Void = {}
    var ausweichen: (Uebung) -> Void = { _ in }
    var nochDefekt: () -> Void = {}

    private var veraltet: Bool { DefektLogik.veraltet(notiz, heute: heute) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gerät defekt gemeldet", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.orange)
            Text("\(Datum.anzeige(notiz.gemeldetAm)) (\(DefektLogik.alterText(notiz, heute: heute)))")
                .font(.subheadline.weight(.medium))
            if let text = notiz.text {
                Text(text).font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
            if veraltet {
                Text("Die Meldung ist älter als \(DefektLogik.veraltetNachTagen) Tage. Noch defekt?")
                    .font(.footnote.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    knopf("Noch defekt", systemImage: "wrench.fill", nochDefekt)
                    knopf("Wieder in Ordnung", systemImage: "checkmark.circle", wiederInOrdnung)
                }
            } else {
                knopf("Wieder in Ordnung", systemImage: "checkmark.circle", wiederInOrdnung)
            }
            if let vorschlag {
                Button { ausweichen(vorschlag) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ausweichen: \(vorschlag.name)").font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                            Text(vorschlag.geraet).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text("Tauschen").font(.subheadline.weight(.medium)).foregroundStyle(HabitFarbe.himmel.farbe)
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ausweichen und tauschen gegen \(vorschlag.name), \(vorschlag.geraet)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(.orange)
    }

    private func knopf(_ titel: String, systemImage: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: systemImage).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.bordered)
    }
}

/// Der Knopf "Defekt melden", wenn noch nichts gemeldet ist. Reine Ansicht.
struct DefektMeldenKnopf: View {
    var aktion: () -> Void = {}

    var body: some View {
        Button(action: aktion) {
            Label("Defekt melden", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .accessibilityHint("Gerät kaputt oder wackelig, mit kurzer Notiz")
    }
}

/// Kurze Notiz zur Meldung. Hier liegt das TextField, nicht in der Karte.
struct DefektMeldenBlatt: View {
    let titel: String
    let studio: GymStudio
    let melden: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(studio.name) {
                    TextField("Notiz, z. B. wackelt, Seil gerissen", text: $text, axis: .vertical)
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Melden") { melden(text); dismiss() } }
            }
        }
    }
}

/// Die eine Einhänge-Stelle für `WorkoutUebungView`: die Karte, wenn für dieses Studio und diese
/// Übung ein Defekt offen ist, sonst der Knopf "Defekt melden". Die Notiz ist nur lokal (kein Sync).
struct DefektAbschnitt: View {
    let sessionId: String
    let uebung: WorkoutUebung
    @Binding var saetze: [PlanSatz]
    var nachtrag = false
    @State private var blatt = false

    private var modell: TrainingModell { TrainingModell.shared }
    private var notizen: DefektNotizen { .shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }
    private var studio: GymStudio { StudioGedaechtnis.shared.studio(ich) }
    private var schluessel: String { EinstellGedaechtnis.uebungsSchluessel(uebung.planUebung) }
    private var heute: String { Datum.text(Date()) }

    var body: some View {
        if !nachtrag {
            Section {
                if let n = notizen.offen(ich, studio, uebung: schluessel) {
                    DefektKarte(notiz: n, heute: heute,
                                vorschlag: AusweichLogik.tauschbar(uebung, saetze: saetze) ? DefektLogik.vorschlag(fuer: uebung) : nil,
                                wiederInOrdnung: { notizen.erledigen(ich, studio, uebung: schluessel, am: heute) },
                                ausweichen: tauschen,
                                nochDefekt: { notizen.bestaetigen(ich, studio, uebung: schluessel, am: heute) })
                } else {
                    DefektMeldenKnopf { blatt = true }
                        .sheet(isPresented: $blatt) {
                            DefektMeldenBlatt(titel: uebung.planUebung.anzeigeName, studio: studio) {
                                notizen.melden(text: $0, ich, studio, uebung: schluessel, am: heute)
                            }
                            .presentationDetents([.medium])
                        }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
    }

    /// Wie `AusweichAbschnitt.tauschen`: Sätze aus der letzten Einheit der neuen Übung, Zuordnung zum Plan
    /// über `ersatzFuer`.
    private func tauschen(_ neu: Uebung) {
        let ursprung = uebung.ersatzFuer.flatMap { UebungsKatalog.nachId[$0] } ?? uebung.planUebung.katalog
        let alle = modell.sessions(ich)
        let frueher = alle.first { $0.id == sessionId }.map { jetzt in alle.filter { $0.start < jetzt.start } } ?? []
        var plan = uebung.planUebung
        plan.uebung = neu.id
        plan.name = nil
        let vorher = WorkoutLogik.vorherige(plan, in: frueher)
        let neueSaetze = AusweichLogik.saetzeNachTausch(saetze, vorher: vorher)
        modell.tauschen(sessionId, uebung.planUebung, zu: neu.id, ersatzFuer: neu.id == ursprung?.id ? nil : ursprung?.id, saetze: neueSaetze)
        saetze = neueSaetze
        Haptik.mittel()
    }
}
