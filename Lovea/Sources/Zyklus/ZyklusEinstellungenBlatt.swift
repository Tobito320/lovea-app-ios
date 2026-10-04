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
                        ZyklusEinstellungenInhalt(
                            einst: $einst,
                            sperreAktiv: Binding(get: { sperre.aktiv }, set: { sperre.aktiv = $0 }),
                            erweitert: erweitert,
                            darfLoeschen: ZyklusEinstellungenLogik.darfLoeschen(speicher.quelle),
                            loeschen: { loeschenFrage = true })
                        exportKarte
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

    private var exportKarte: some View {
        ZyklusKarte {
            VStack(alignment: .leading, spacing: 10) {
                Text("Export").font(.system(.headline, design: .rounded).weight(.bold))
                Text("Alle Einträge als Text.").font(.footnote)
                ShareLink(item: ZyklusEinstellungenLogik.export(tage: speicher.tage, einstellung: speicher.einstellung)) {
                    Label("Als Text teilen", systemImage: "square.and.arrow.up")
                        .font(.system(.body, design: .rounded).weight(.bold))
                }
            }
        }
    }
}

/// Reines SwiftUI (keine UIKit-Steuerelemente), damit die Render-Tafel es zeichnet.
struct ZyklusEinstellungenInhalt: View {
    @Binding var einst: ZyklusEinstellung
    @Binding var sperreAktiv: Bool
    var erweitert: AnyView?
    var darfLoeschen: Bool
    var loeschen: () -> Void = {}
    @Environment(\.colorScheme) private var schema

    var body: some View {
        VStack(spacing: 14) {
            ZyklusKarte {
                VStack(alignment: .leading, spacing: 10) {
                    titel("Modus")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(Modus.allCases, id: \.self) { m in
                            Button { einst.modus = m } label: {
                                ZyklusChip(titel: ZyklusEinstellungenLogik.modusName(m), gewaehlt: einst.modus == m)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            ZyklusKarte {
                VStack(alignment: .leading, spacing: 12) {
                    titel("Längen")
                    schritt("Zyklus", wert: $einst.zyklusLaenge, grenzen: ZyklusEinstellungenLogik.zyklusGrenzen)
                    schritt("Periode", wert: $einst.periodenLaenge, grenzen: ZyklusEinstellungenLogik.periodenGrenzen)
                }
            }
            ZyklusKarte {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        titel("Sperre")
                        Text("Face ID oder Code beim Öffnen").font(.footnote).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    }
                    Spacer()
                    Button { sperreAktiv.toggle() } label: {
                        ZyklusChip(titel: sperreAktiv ? "An" : "Aus", symbol: sperreAktiv ? "lock.fill" : "lock.open", gewaehlt: sperreAktiv)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sperre")
                    .accessibilityValue(sperreAktiv ? "An" : "Aus")
                }
            }
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
            if darfLoeschen { ZyklusKnopf(titel: "Daten löschen", symbol: "trash", leise: true, aktion: loeschen) }
        }
        .foregroundStyle(ZyklusFarbe.tinte(schema))
    }

    private func titel(_ text: String) -> some View {
        Text(text).font(.system(.headline, design: .rounded).weight(.bold))
    }

    private func schritt(_ name: String, wert: Binding<Int>, grenzen: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            Text("\(name): \(wert.wrappedValue) Tage").font(.system(.body, design: .rounded))
            Spacer()
            Button { wert.wrappedValue = max(grenzen.lowerBound, wert.wrappedValue - 1) } label: {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            .accessibilityLabel("\(name) kürzer")
            Button { wert.wrappedValue = min(grenzen.upperBound, wert.wrappedValue + 1) } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .accessibilityLabel("\(name) länger")
        }
        .buttonStyle(.plain)
    }
}
