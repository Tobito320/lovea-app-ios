import SwiftUI
import UIKit

/// Eintrag in den Einstellungen, nur für Ahmed (hängt in `EinstellungenView` an `person == .ahmed`).
/// Öffnet die Tracker-Seite; die Bluetooth-Abfrage kommt erst dort oder nach dem Koppeln von selbst.
struct TrackerEinstellungen: View {
    private var modell: TrackerModell { .shared }

    var body: some View {
        Section {
            NavigationLink {
                TrackerSeite()
            } label: {
                LabeledContent("Fitness-Tracker", value: modell.statusText)
            }
        } header: {
            Text("Fitness-Tracker")
        } footer: {
            Text("iSo Tech H59MAX. Seine Schritte zählen in Lovea, wenn sie höher sind als die von Apple Health. Annika sieht deine Schritte, den Tracker nicht.")
        }
    }
}

struct TrackerSeite: View {
    private var modell: TrackerModell { .shared }
    @AppStorage(CoachGesundheit.schalter) private var coachLiest = true

    var body: some View {
        List {
            Section("Status") {
                LabeledContent("Verbindung", value: modell.statusText)
                if let name = modell.name {
                    LabeledContent("Gerät", value: name)
                }
                if let akku = modell.akku {
                    LabeledContent("Akku", value: akku.laedt ? "\(akku.prozent) % (lädt)" : "\(akku.prozent) %")
                }
            }

            if modell.pulsEinstellung != nil || !modell.messungen.isEmpty {
                messungenAbschnitt
            }

            Section {
                schritte
            } header: {
                Text("Schritte")
            } footer: {
                Text("Lovea nimmt pro Tag den höheren Wert von Tracker und Apple Health, sie werden nie addiert. Der Tracker schreibt nichts in Apple Health, sonst zählt Health dieselben Schritte doppelt.")
            }

            Section {
                Toggle("Coach liest Health und Tracker", isOn: $coachLiest)
            } footer: {
                Text("Der Coach bekommt mit jeder Frage deine Health-Werte der letzten Tage (Puls, Schlaf, Gewicht, Trainings und mehr) und die Zahlen des Trackers. Nur für dich, Annikas Coach bekommt nichts davon.")
            }

            Section { aktionen } footer: { hinweis }
        }
        .navigationTitle("Fitness-Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .task { modell.fortsetzen() }
    }

    /// Dauermessung am Tracker. Die Schalter zeigen immer, was der Tracker meldet; eine Änderung wird
    /// geschickt und danach zurückgelesen, daher springt ein Schalter zurück, wenn der Tracker sie ablehnt.
    private var messungenAbschnitt: some View {
        Section {
            Toggle("Puls-Dauermessung", isOn: Binding(
                get: { modell.pulsEinstellung?.an ?? false },
                set: { modell.aendern(.puls(an: $0, minuten: pulsAbstand)) }))
            if modell.pulsEinstellung?.an == true {
                Picker("Abstand", selection: Binding(get: { pulsAbstand }, set: { modell.aendern(.puls(an: true, minuten: $0)) })) {
                    ForEach(abstaende, id: \.self) { Text("\($0) Min.").tag($0) }
                }
            }
            ForEach(TrackerProtokoll.Dauermessung.allCases, id: \.self) { art in
                Toggle(art.name, isOn: Binding(
                    get: { modell.messungen[art] ?? false },
                    set: { modell.aendern(.messung(art, an: $0)) }))
            }
        } header: {
            HStack {
                Text("Messungen am Tracker")
                if modell.abfrageLaeuft { ProgressView().controlSize(.mini) }
            }
        } footer: {
            if let hinweis = modell.aenderungsHinweis {
                Text(hinweis).foregroundStyle(.red)
            } else {
                Text("Nur bei Verbindung änderbar. Lovea schickt die Änderung und liest sie vom Tracker zurück. Schreiben am Tracker ist noch nicht am Gerät getestet.")
            }
        }
        .disabled(!modell.einstellbar)
    }

    private var pulsAbstand: Int { modell.pulsEinstellung?.intervallMinuten ?? 10 }

    /// Die üblichen Abstände plus der, den der Tracker gerade hat.
    private var abstaende: [Int] { Set([5, 10, 15, 30, 45, 60, pulsAbstand]).sorted() }

    @ViewBuilder private var schritte: some View {
        if let heute = modell.heute {
            LabeledContent("Schritte heute", value: heute.schritte.formatted())
            LabeledContent("Strecke", value: "\((Double(heute.meter) / 1000).formatted(.number.precision(.fractionLength(2)))) km")
            if let minute = heute.letzteMinute {
                LabeledContent("Letzte Bewegung", value: String(format: "ab %02d:%02d Uhr", minute / 60, minute % 60))
            }
        } else {
            Text("Für heute hat der Tracker noch nichts geliefert.")
                .foregroundStyle(.secondary)
        }
        if let stand = modell.bandTage.stand {
            LabeledContent("Zuletzt gelesen") { Text(stand, style: .relative) }
        }
    }

    @ViewBuilder private var aktionen: some View {
        switch modell.zustand {
        case .verbunden:
            Button("Jetzt abfragen") { modell.abfragen() }
            Button("Tracker vibrieren lassen") { modell.finden() }
            Button("Trennen") { modell.trennen() }
        case .sucht, .wartet:
            Button("Abbrechen") { modell.trennen() }
        case .nichtErlaubt:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Bluetooth in den iOS-Einstellungen erlauben", destination: url)
            }
        case .bluetoothAus, .nichtVerfuegbar:
            EmptyView()
        case .getrennt, .nichtGefunden, .fehler:
            Button(modell.gekoppelt ? "Verbinden" : "Tracker suchen") { modell.verbinden() }
        }
        if modell.gekoppelt {
            Button("Tracker vergessen", role: .destructive) { modell.vergessen() }
        }
    }

    @ViewBuilder private var hinweis: some View {
        switch modell.zustand {
        case .wartet, .nichtGefunden:
            Text("Den Tracker einmal antippen oder bewegen. Er sendet nach dem Trennen nicht mehr, bis er geweckt wird.")
        case .bluetoothAus:
            Text("Bluetooth ist am iPhone aus. Im Kontrollzentrum einschalten.")
        default:
            Text("Der Tracker nimmt nur eine Verbindung an. In QWatch Pro muss er unter Device, Device Binding gelöst sein. Lovea verbindet sich von selbst wieder, auch im Hintergrund, sobald der Tracker sendet. Nach dem Trennen sendet er erst wieder, wenn du ihn antippst.")
        }
    }
}
