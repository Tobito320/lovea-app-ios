import SwiftUI
import UIKit

/// Eintrag in den Einstellungen, nur für Ahmed (hängt in `EinstellungenView` an `person == .ahmed`).
/// Öffnet die Tracker-Seite; die Bluetooth-Abfrage kommt erst dort.
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
            Text("iSo Tech H59MAX. Nur auf deinem Gerät, nichts geht an Annika oder in Health.")
        }
    }
}

struct TrackerSeite: View {
    private var modell: TrackerModell { .shared }

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
                if let puls = modell.pulsEinstellung {
                    LabeledContent("Puls-Dauermessung", value: puls.an ? "an, alle \(puls.intervallMinuten) Min." : "aus")
                }
                if let stand = modell.aktualisiert {
                    LabeledContent("Zuletzt abgefragt") { Text(stand, style: .relative) }
                }
            }

            if let schritte = modell.testSchritte {
                Section {
                    LabeledContent("Schritte heute", value: "\(schritte)")
                } header: {
                    Text("Test")
                } footer: {
                    Text("Noch nicht belegt. Vergleiche die Zahl mit der Anzeige in QWatch Pro. Sie wird nirgends gespeichert.")
                }
            }

            Section { aktionen } footer: { hinweis }
        }
        .navigationTitle("Fitness-Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .task { modell.beimOeffnen() }
    }

    @ViewBuilder private var aktionen: some View {
        switch modell.zustand {
        case .verbunden:
            Button("Jetzt abfragen") { modell.abfragen() }
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
            Text("Der Tracker nimmt nur eine Verbindung an. In QWatch Pro muss er unter Device, Device Binding gelöst sein. Die Verbindung läuft nur, solange Lovea offen ist.")
        }
    }
}
