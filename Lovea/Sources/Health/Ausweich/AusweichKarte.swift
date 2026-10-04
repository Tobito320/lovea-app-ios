import SwiftUI

/// "Gerät besetzt?": die Alternativen mit gleicher Muskelgruppe. Ein Tipp tauscht die Übung. Reines
/// SwiftUI (Knöpfe, keine TextFields), damit `ImageRenderer` es zeichnen kann.
struct AusweichKarte: View {
    let muskel: String
    let alternativen: [Uebung]
    /// Die ursprüngliche Übung, wenn schon getauscht wurde.
    var ursprung: Uebung? = nil
    var tauschen: (Uebung) -> Void = { _ in }
    var zurueck: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gerät besetzt?", systemImage: "arrow.triangle.swap").font(.headline)
            if let ursprung {
                Button(action: zurueck) {
                    HStack {
                        Text("Zurück zu \(ursprung.name)").font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.uturn.backward").font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(HabitFarbe.himmel.farbe)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tausch rückgängig, zurück zu \(ursprung.name)")
            }
            Text("Gleiche Muskelgruppe: \(muskel). Der Fortschritt bleibt beim Plan.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(alternativen) { a in
                Button { tauschen(a) } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                            Text(a.geraet).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text("Tauschen").font(.subheadline.weight(.medium)).foregroundStyle(HabitFarbe.himmel.farbe)
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tauschen gegen \(a.name), \(a.geraet)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthKarte(HabitFarbe.amber.farbe)
    }
}

/// Die eine Einhänge-Stelle für `WorkoutUebungView`: zeigt die Karte, solange noch kein Satz
/// abgehakt ist, und tauscht die Übung der laufenden Einheit.
struct AusweichAbschnitt: View {
    let sessionId: String
    let uebung: WorkoutUebung
    @Binding var saetze: [PlanSatz]
    var nachtrag = false

    private var modell: TrainingModell { TrainingModell.shared }
    private var ich: Person { Raum.shared.ich ?? .ahmed }

    var body: some View {
        if !nachtrag, AusweichLogik.tauschbar(uebung, saetze: saetze),
           let aktuell = uebung.planUebung.katalog {
            let ursprung = uebung.ersatzFuer.flatMap { UebungsKatalog.nachId[$0] }
            let vorlage = ursprung ?? aktuell
            let liste = AusweichLogik.alternativen(fuer: vorlage).filter { $0.id != aktuell.id }
            if !liste.isEmpty || ursprung != nil {
                Section {
                    AusweichKarte(muskel: vorlage.muskel, alternativen: liste, ursprung: ursprung,
                                  tauschen: { tauschen(zu: $0, ursprung: vorlage) },
                                  zurueck: { tauschen(zu: vorlage, ursprung: vorlage) })
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
    }

    private func tauschen(zu neu: Uebung, ursprung: Uebung) {
        let alle = modell.sessions(ich)
        let frueher = alle.first { $0.id == sessionId }.map { jetzt in alle.filter { $0.start < jetzt.start } } ?? []
        var plan = uebung.planUebung
        plan.uebung = neu.id
        plan.name = nil
        let vorher = WorkoutLogik.vorherige(plan, in: frueher)
        let neueSaetze = AusweichLogik.saetzeNachTausch(saetze, vorher: vorher)
        modell.tauschen(sessionId, uebung.planUebung, zu: neu.id, ersatzFuer: neu.id == ursprung.id ? nil : ursprung.id, saetze: neueSaetze)
        saetze = neueSaetze
        Haptik.mittel()
    }
}
