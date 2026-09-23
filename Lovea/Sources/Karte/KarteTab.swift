import CoreLocation
import MapKit
import SwiftUI

/// Local wrapper so `.sheet(item:)` works without adding `Identifiable` to `Person` itself -
/// other wave-2 blocks may add that conformance in their own files, and two would collide.
private struct PersonAuswahl: Identifiable {
    let person: Person
    var id: String { person.rawValue }
}

struct KarteTab: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var kamera: MapCameraPosition = .automatic
    @State private var satellit = false
    @State private var ausgewaehlt: PersonAuswahl?
    @State private var orteListe = false

    private let standort = Standort.shared
    private let orte = OrteModell.shared
    private let figuren = FigurenModell.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                karte
                banner
                knoepfe
            }
            .navigationTitle("Karte")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $ausgewaehlt) { auswahl in
                InfoKarteView(person: auswahl.person)
            }
            .sheet(isPresented: $orteListe) {
                OrteListeView()
            }
        }
        .task {
            Standort.shared.start()
            figuren.zustandSenden(.init(haupt: .karte))
            Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: true))
        }
        .onDisappear {
            Anwesenheit.shared.app(nil)
            Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: false))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: false)) }
        }
    }

    // MARK: - Map

    private var karte: some View {
        Map(position: $kamera) {
            ForEach(Person.allCases, id: \.self) { person in
                if let d = standort.positionen[person] {
                    let punkt = CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon)
                    Annotation(person.name, coordinate: punkt) {
                        FigurView(figuren.aussehen(person), zustand: zustand(person), groesse: 64)
                            .onTapGesture { if person != Raum.shared.ich { ausgewaehlt = PersonAuswahl(person: person) } }
                            .accessibilityLabel("Figur von \(person.name)")
                            .accessibilityHint(person == Raum.shared.ich ? "" : "Öffnet Standort-Details")
                    }
                    if d.genau > 20 {
                        MapCircle(center: punkt, radius: d.genau)
                            .foregroundStyle(Color.person(person).opacity(0.12))
                            .stroke(Color.person(person).opacity(0.4), lineWidth: 1)
                    }
                }
            }
        }
        .mapStyle(satellit ? MapStyle.imagery : MapStyle.standard)
        .mapControls { MapCompass() }
        .onAppear { kameraZentrieren() }
        .onChange(of: standort.positionen.count) { _, _ in kameraZentrieren() }
    }

    private func zustand(_ person: Person) -> FigurZustand {
        if let bis = orte.nahBis, bis > Date() { return .anstossen }
        return figuren.anzeige(person).haupt
    }

    private func kameraZentrieren() {
        let punkte = Person.allCases.compactMap { standort.positionen[$0] }
        guard !punkte.isEmpty else { return }
        let lats = punkte.map(\.lat)
        let lons = punkte.map(\.lon)
        let mitte = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let spanne = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.8, 0.01),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.8, 0.01)
        )
        withAnimation { kamera = .region(MKCoordinateRegion(center: mitte, span: spanne)) }
    }

    // MARK: - Glass controls (Liquid Glass auf der Steuerebene, siehe apple-design/masterplan §10)

    private var knoepfe: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        glasKnopf(satellit ? "map" : "globe.europe.africa", "Kartenstil wechseln") { satellit.toggle() }
                        glasKnopf("scope", "Beide zeigen") { kameraZentrieren() }
                        glasKnopf("list.bullet", "Orte verwalten") { orteListe = true }
                    }
                }
                .padding()
            }
        }
    }

    private func glasKnopf(_ symbol: String, _ label: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }

    // MARK: - Ort-Vorschlag banner (Z-8.4)

    @ViewBuilder
    private var banner: some View {
        if let v = orte.vorschlag {
            VStack {
                OrtVorschlagBanner(vorschlag: v)
                Spacer()
            }
            .padding()
        }
    }
}

struct KarteOffenAn: Encodable { let an: Bool }

/// "Als Ort speichern?" - name and category start from the POI guess, both editable.
private struct OrtVorschlagBanner: View {
    let vorschlag: OrtVorschlagAnzeige
    @State private var name = ""
    @State private var kategorie = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Als Ort speichern?")
                .font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            Picker("Kategorie", selection: $kategorie) {
                ForEach(OrteKategorien.alle, id: \.self) { Text(OrteKategorien.titel($0)).tag($0) }
            }
            .pickerStyle(.menu)
            HStack {
                Button("Verwerfen") { OrteModell.shared.vorschlagVerwerfen() }
                Spacer()
                Button("Speichern") { OrteModell.shared.vorschlagSpeichern(name: name, kategorie: kategorie) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onAppear {
            name = vorschlag.name
            kategorie = vorschlag.kategorie
        }
    }
}

enum OrteKategorien {
    static let alle = ["zuhause", "gym", "schule", "arbeit", "fahrschule", "supermarkt", "sonstiges"]

    static func titel(_ k: String) -> String {
        switch k {
        case "zuhause": "Zuhause"
        case "gym": "Gym"
        case "schule": "Schule"
        case "arbeit": "Arbeit"
        case "fahrschule": "Fahrschule"
        case "supermarkt": "Supermarkt"
        default: "Sonstiges"
        }
    }
}
