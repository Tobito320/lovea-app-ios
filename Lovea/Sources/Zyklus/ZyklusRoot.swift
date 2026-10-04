import SwiftUI

enum ZyklusReiter: String, CaseIterable, Identifiable {
    case heute, kalender, insights
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .heute: return "Heute"
        case .kalender: return "Kalender"
        case .insights: return "Insights"
        }
    }
}

enum ZyklusRootLogik {
    static let demoBanner = "Testdaten, nur zum Ausprobieren"
    static func zeigtBanner(_ quelle: ZyklusQuelle) -> Bool { quelle == .demo }
}

/// Einstieg in den Zyklus: Segmente Heute / Kalender / Insights, Sperre, Einstellungen, Demo-Banner.
struct ZyklusRoot: View {
    let person: Person
    @State private var speicher: any ZyklusSpeicher
    @State private var sperre: ZyklusSperre
    @State private var reiter: ZyklusReiter = .heute
    @State private var einstellungenOffen = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.colorScheme) private var schema

    @MainActor private static var beobachtet = false

    init(person: Person) {
        self.person = person
        let s = ZyklusSpeicherWahl.fuer(person: person)
        if let echt = s as? EchterZyklusSpeicher, !Self.beobachtet {
            Self.beobachtet = true
            echt.beobachten()
        }
        _speicher = State(initialValue: s)
        _sperre = State(initialValue: ZyklusSperre(person: person))
    }

    var body: some View {
        ZStack {
            if sperre.gesperrt {
                ZyklusSperreAnsicht(sperre: sperre)
            } else {
                inhalt
            }
        }
        .navigationTitle("Zyklus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !sperre.gesperrt {
                ToolbarItem(placement: .primaryAction) {
                    Button { einstellungenOffen = true } label: { Label("Einstellungen", systemImage: "gearshape.fill") }
                }
            }
        }
        .sheet(isPresented: $einstellungenOffen) { ZyklusEinstellungenBlatt(speicher: speicher, sperre: sperre) }
        .onChange(of: phase) { _, neu in if neu == .background { sperre.sperren() } }
    }

    private var inhalt: some View {
        VStack(spacing: 0) {
            if ZyklusRootLogik.zeigtBanner(speicher.quelle) { banner }
            Picker("Ansicht", selection: $reiter) {
                ForEach(ZyklusReiter.allCases) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            switch reiter {
            case .heute: ZyklusHeuteView(speicher: speicher, eintragBlatt: blatt)
            case .kalender: ZyklusKalenderView(speicher: speicher, eintragBlatt: blatt)
            case .insights: ZyklusInsightsView(speicher: speicher)
            }
        }
        .background(ZyklusHintergrund(deko: false).ignoresSafeArea())
    }

    private var banner: some View {
        Text(ZyklusRootLogik.demoBanner)
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(ZyklusFarbe.aufHimbeere(schema))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(ZyklusFarbe.himbeere.farbe(schema))
    }

    private func blatt(_ datum: String) -> AnyView {
        AnyView(ZyklusEintragBlatt(speicher: speicher, datum: datum))
    }
}

/// Zeile im Profil.
struct ZyklusProfilZeile: View {
    let person: Person
    @Environment(\.colorScheme) private var schema

    var body: some View {
        NavigationLink { ZyklusRoot(person: person) } label: {
            ZyklusKarte {
                HStack(spacing: 12) {
                    ZyklusHerzForm().fill(ZyklusFarbe.himbeere.farbe(schema)).frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zyklus").font(.system(.headline, design: .rounded).weight(.bold))
                        Text("Dein Tagebuch, nur für dich").font(.footnote).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                }
                .foregroundStyle(ZyklusFarbe.tinte(schema))
            }
        }
        .buttonStyle(.plain)
    }
}
