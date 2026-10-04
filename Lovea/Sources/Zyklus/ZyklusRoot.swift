import SwiftUI

enum ZyklusReiter: String, CaseIterable, Identifiable {
    case heute, modus, kalender, insights
    var id: String { rawValue }
    var titel: String {
        switch self {
        case .heute, .modus: return "Heute"
        case .kalender: return "Kalender"
        case .insights: return "Insights"
        }
    }
}

enum ZyklusRootLogik {
    static let demoBanner = "Testdaten, nur zum Ausprobieren"
    static func zeigtBanner(_ quelle: ZyklusQuelle) -> Bool { quelle == .demo }

    /// Zyklus: wie bisher. Die anderen Modi ersetzen "Heute" durch ihre eigene Ansicht.
    static func reiter(_ modus: Modus) -> [ZyklusReiter] {
        modus == .zyklus ? [.heute, .kalender, .insights] : [.modus, .kalender, .insights]
    }

    static func titel(_ reiter: ZyklusReiter, modus: Modus) -> String {
        reiter == .modus ? ZyklusEinstellungenLogik.modusName(modus) : reiter.titel
    }

    /// Ein gemerkter Reiter, den der Modus nicht hat, fällt auf den ersten des Modus zurück.
    static func gueltig(_ reiter: ZyklusReiter, modus: Modus) -> ZyklusReiter {
        let r = Self.reiter(modus)
        return r.contains(reiter) ? reiter : r[0]
    }
}

/// Einstieg in den Zyklus: Segmente Heute / Kalender / Insights, Sperre, Einstellungen, Demo-Banner.
struct ZyklusRoot: View {
    let person: Person
    @State private var speicher: any ZyklusSpeicher
    @State private var sperre: ZyklusSperre
    @State private var reiter: ZyklusReiter = .heute
    @State private var einstellungenOffen = false
    @State private var modus: Modus
    @State private var erinnerung = ErinnerungsEinstellung.laden()
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
        _modus = State(initialValue: s.einstellung.modus)
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
        .sheet(isPresented: $einstellungenOffen, onDismiss: {
            modus = speicher.einstellung.modus
            erinnerung = ErinnerungsEinstellung.laden()
        }) { ZyklusEinstellungenBlatt(speicher: speicher, sperre: sperre) }
        .onChange(of: phase) { _, neu in if neu == .background { sperre.sperren() } }
    }

    private var inhalt: some View {
        VStack(spacing: 0) {
            if ZyklusRootLogik.zeigtBanner(speicher.quelle) { banner }
            Picker("Ansicht", selection: Binding(
                get: { ZyklusRootLogik.gueltig(reiter, modus: modus) },
                set: { reiter = $0 })
            ) {
                ForEach(ZyklusRootLogik.reiter(modus)) { Text(ZyklusRootLogik.titel($0, modus: modus)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            switch ZyklusRootLogik.gueltig(reiter, modus: modus) {
            case .heute: ZyklusHeuteView(speicher: speicher, eintragBlatt: blatt)
            case .modus: modusAnsicht
            case .kalender: ZyklusKalenderView(speicher: speicher, eintragBlatt: blatt)
            case .insights: ZyklusInsightsView(speicher: speicher)
            }
        }
        .background(ZyklusHintergrund(deko: false).ignoresSafeArea())
    }

    @ViewBuilder private var modusAnsicht: some View {
        switch modus {
        case .zyklus: ZyklusHeuteView(speicher: speicher, eintragBlatt: blatt)
        case .schwanger: ZyklusSchwangerView(speicher: speicher)
        case .kinderwunsch: ZyklusKinderwunschView(speicher: speicher)
        case .pille:
            ZyklusPilleView(speicher: speicher, erinnerungAn: erinnerung.aktiv.contains(.pille)) { an in
                if an { erinnerung.aktiv.insert(.pille) } else { erinnerung.aktiv.remove(.pille) }
                let neu = erinnerung
                let s = speicher
                Task { await ZyklusErinnerungsDienst.anwenden(neu, speicher: s, erfragen: an) }
            }
        }
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

    var body: some View {
        NavigationLink { ZyklusRoot(person: person) } label: { ZyklusProfilZeileInhalt() }
            .buttonStyle(.plain)
    }
}

struct ZyklusProfilZeileInhalt: View {
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ZyklusKarte {
            HStack(spacing: 12) {
                ZyklusHerzForm().fill(ZyklusFarbe.himbeere.farbe(schema)).frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zyklus").font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(ZyklusFarbe.tinte(schema))
                    Text("Dein Tagebuch, nur für dich").font(.footnote).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(ZyklusFarbe.tinteLeise(schema))
            }
        }
    }
}
