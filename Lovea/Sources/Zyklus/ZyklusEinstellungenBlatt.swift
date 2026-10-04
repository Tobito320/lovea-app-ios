import SwiftUI

enum ZyklusEinstellungenLogik {
    static let zyklusGrenzen = 20...45
    static let periodenGrenzen = 2...10

    static func begrenzt(_ e: ZyklusEinstellung) -> ZyklusEinstellung {
        var r = e
        r.zyklusLaenge = min(max(e.zyklusLaenge, zyklusGrenzen.lowerBound), zyklusGrenzen.upperBound)
        r.periodenLaenge = min(max(e.periodenLaenge, periodenGrenzen.lowerBound), periodenGrenzen.upperBound)
        return r
    }

    /// Löschen gibt es nur für echte Daten. Die Testdaten bleiben.
    static func darfLoeschen(_ quelle: ZyklusQuelle) -> Bool { quelle == .echt }

    static func modusName(_ m: Modus) -> String {
        switch m {
        case .zyklus: return "Zyklus"
        case .schwanger: return "Schwanger"
        case .kinderwunsch: return "Kinderwunsch"
        case .pille: return "Pille"
        }
    }

    /// Alle Tage als Text, ältester zuerst.
    static func export(tage: [String: ZyklusTag], einstellung: ZyklusEinstellung) -> String {
        var z = ["Lovea Zyklus", "Modus: \(modusName(einstellung.modus))",
                 "Zykluslänge: \(einstellung.zyklusLaenge) Tage", "Periodenlänge: \(einstellung.periodenLaenge) Tage", ""]
        for id in tage.keys.sorted() {
            guard let t = tage[id] else { continue }
            var teile = ZyklusHeuteLogik.eintraege(t).map(\.titel)
            if let n = t.notiz, !n.isEmpty, !teile.contains(where: { $0.contains(n) }) { teile.append("Notiz: \(n)") }
            z.append("\(id): " + (teile.isEmpty ? "-" : teile.joined(separator: ", ")))
        }
        return z.joined(separator: "\n")
    }

    @MainActor
    static func alleLoeschen(_ speicher: any ZyklusSpeicher) {
        guard darfLoeschen(speicher.quelle) else { return }
        for id in Array(speicher.tage.keys) { speicher.setze(ZyklusTag(id: id)) }
    }
}

struct ZyklusEinstellungenBlatt: View {
    let speicher: any ZyklusSpeicher
    let sperre: ZyklusSperre
    /// Leerer Platz für Modi und Erinnerungen. Wird später verdrahtet.
    var erweitert: AnyView?
    @State private var einst: ZyklusEinstellung
    @State private var loeschenFrage = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var schema

    init(speicher: any ZyklusSpeicher, sperre: ZyklusSperre, erweitert: AnyView? = nil) {
        self.speicher = speicher
        self.sperre = sperre
        self.erweitert = erweitert
        _einst = State(initialValue: speicher.einstellung)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZyklusHintergrund(deko: false)
                ScrollView {
                    VStack(spacing: 14) {
                        modusKarte
                        laengenKarte
                        sperreKarte
                        erweitertKarte
                        exportKarte
                        if ZyklusEinstellungenLogik.darfLoeschen(speicher.quelle) { loeschenKarte }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .onChange(of: einst) { _, neu in
                let b = ZyklusEinstellungenLogik.begrenzt(neu)
                speicher.einstellung = b
                if b != neu { einst = b }
            }
            .confirmationDialog("Alle Zyklus-Daten löschen?", isPresented: $loeschenFrage, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) { ZyklusEinstellungenLogik.alleLoeschen(speicher) }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das geht nicht rückgängig.")
            }
        }
    }

    private func titel(_ text: String) -> some View {
        Text(text).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(ZyklusFarbe.tinte(schema))
    }

    private var modusKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                titel("Modus")
                Picker("Modus", selection: $einst.modus) {
                    ForEach(Modus.allCases, id: \.self) { Text(ZyklusEinstellungenLogik.modusName($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var laengenKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                titel("Längen")
                Stepper("Zyklus: \(einst.zyklusLaenge) Tage", value: $einst.zyklusLaenge, in: ZyklusEinstellungenLogik.zyklusGrenzen)
                Stepper("Periode: \(einst.periodenLaenge) Tage", value: $einst.periodenLaenge, in: ZyklusEinstellungenLogik.periodenGrenzen)
            }
            .font(.system(.body, design: .rounded))
        }
    }

    private var sperreKarte: some View {
        ZyklusKarte {
            Toggle(isOn: Binding(get: { sperre.aktiv }, set: { sperre.aktiv = $0 })) {
                VStack(alignment: .leading, spacing: 2) {
                    titel("Sperre")
                    Text("Face ID oder Code beim Öffnen").font(.footnote).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                }
            }
            .tint(ZyklusFarbe.himbeere.farbe(schema))
        }
    }

    @ViewBuilder private var erweitertKarte: some View {
        if let erweitert {
            ZyklusKarte { erweitert }
        } else {
            ZyklusKarte {
                HStack {
                    titel("Erinnerungen")
                    Spacer()
                    Text("Bald").font(.footnote).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                }
            }
        }
    }

    private var exportKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                titel("Export")
                Text("Alle Einträge als Text.").font(.footnote).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                ShareLink(item: ZyklusEinstellungenLogik.export(tage: speicher.tage, einstellung: speicher.einstellung)) {
                    Label("Als Text teilen", systemImage: "square.and.arrow.up")
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
            }
        }
    }

    private var loeschenKarte: some View {
        ZyklusKnopf(titel: "Daten löschen", symbol: "trash", leise: true) { loeschenFrage = true }
    }
}
