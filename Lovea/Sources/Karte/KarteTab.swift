import CoreLocation
import MapKit
import SwiftUI
import UIKit

/// Local wrapper so `.sheet(item:)` works without adding `Identifiable` to `Person` itself -
/// other wave-2 blocks may add that conformance in their own files, and two would collide.
private struct PersonAuswahl: Identifiable {
    let person: Person
    var id: String { person.rawValue }
}

struct KarteTab: View {
    /// Z-19.1: kein Tab mehr, öffnet sich vollflächig über das Partner-Profil, Schließen-Knopf statt Tab-Wechsel.
    var schliessen: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @State private var kamera: MapCameraPosition = .automatic
    @State private var satellit = false
    @State private var dreiD = true
    @State private var ausgewaehlt: PersonAuswahl?
    @State private var orteListe = false
    @State private var gebietPartner: String?
    // Z-27.4
    @State private var unsereOrteAn = false
    @State private var gemeinsamAusgewaehlt: GemeinsamerOrt?
    // Tracks the last programmatic camera target so the 3D/2D toggle can re-apply it with the new
    // pitch. ponytail: `MapCameraPosition` doesn't expose its current values for read-back, so a
    // manual pan/pinch between calls isn't reflected here - toggling 3D then snaps back to the
    // last tap/center target instead of wherever the user free-panned to.
    @State private var kameraMitte: CLLocationCoordinate2D?
    @State private var kameraDistanz: CLLocationDistance = 1200

    private let standort = Standort.shared
    private let orte = OrteModell.shared
    private let figuren = FigurenModell.shared

    private var partner: Person? { Raum.shared.ich?.partner }
    private var partnerLat: Double? { partner.flatMap { standort.positionen[$0]?.lat } }

    private static let poiKategorien: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .school, .university, .fitnessCenter, .foodMarket,
        .park, .publicTransport, .hospital, .pharmacy,
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                karte
                VStack(spacing: 8) {
                    topLeiste
                    banner
                    Spacer()
                }
                knoepfe
            }
            .navigationTitle("Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let schliessen {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { schliessen() } label: { Image(systemName: "xmark") }
                            .accessibilityLabel("Schließen")
                    }
                }
            }
            .sheet(item: $ausgewaehlt) { auswahl in
                InfoKarteView(person: auswahl.person)
            }
            .sheet(isPresented: $orteListe) {
                OrteListeView()
            }
            .sheet(item: $gemeinsamAusgewaehlt) { ort in
                GemeinsamerOrtDetail(ort: ort)
            }
        }
        .task {
            Standort.shared.start()
            figuren.zustandSenden(.init(haupt: .karte))
            Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: true))
            SpotifyModell.shared.schauen() // Z-27.6: Spec 9 "nur wenn der Partner hinschaut"
        }
        .task(id: partnerLat) { await gebietLaden() }
        .onDisappear {
            Anwesenheit.shared.app(nil)
            Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: false))
            SpotifyModell.shared.wegschauen()
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
                    // Z-19.3: `Annotation`s eigener Titel würde den Namen zusätzlich zu `namensSchild` zeigen.
                    Annotation(person.name, coordinate: punkt) {
                        FigurPin(person: person, daten: d, zustand: zustand(person), aussehen: figuren.aussehen(person), istIch: person == Raum.shared.ich) {
                            figurTippen(person)
                        }
                    }
                    .annotationTitles(.hidden)
                    if d.genau > 20 {
                        MapCircle(center: punkt, radius: d.genau)
                            .foregroundStyle(Color.person(person).opacity(0.12))
                            .stroke(Color.person(person).opacity(0.4), lineWidth: 1)
                    }
                }
            }
            gemeinsameOrtePins
        }
        .mapStyle(satellit ? .imagery(elevation: .realistic) : .standard(elevation: .realistic, pointsOfInterest: .including(Self.poiKategorien)))
        .mapControls { MapCompass() }
        .onAppear { kameraZentrieren() }
        .onChange(of: standort.positionen.count) { _, _ in kameraZentrieren() }
        .onTapGesture(count: 2) { doppeltGetippt() }
    }

    // Z-27.4: separate `MapContentBuilder`, so `karte`'s body stays small (common.md).
    @MapContentBuilder
    private var gemeinsameOrtePins: some MapContent {
        if unsereOrteAn {
            ForEach(orte.gemeinsameOrte) { ort in
                Annotation("Zusammen unterwegs", coordinate: CLLocationCoordinate2D(latitude: ort.lat, longitude: ort.lon)) {
                    GemeinsamerOrtPin().onTapGesture { gemeinsamAusgewaehlt = ort }
                }
                .annotationTitles(.hidden)
            }
        }
    }

    private func zustand(_ person: Person) -> FigurZustand {
        if let bis = orte.nahBis, bis > Date() { return .anstossen }
        return figuren.anzeige(person).haupt
    }

    // MARK: - Camera (Snap-Map-style pitched 3D)

    private func kameraSetzen(mitte: CLLocationCoordinate2D, distanz: CLLocationDistance) {
        kameraMitte = mitte
        kameraDistanz = distanz
        withAnimation { kamera = .camera(MapCamera(centerCoordinate: mitte, distance: distanz, heading: 0, pitch: dreiD ? 55 : 0)) }
    }

    private func kameraZentrieren() {
        let punkte = Person.allCases.compactMap { standort.positionen[$0] }
        guard !punkte.isEmpty else { return }
        let lats = punkte.map(\.lat)
        let lons = punkte.map(\.lon)
        let mitte = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        // ponytail: flat-earth meters-per-degree approximation (111_000 m/lat°, cos(lat) for
        // longitude) - accurate enough for a camera distance at this zoom, exact geodesy isn't.
        let latSpanM = (lats.max()! - lats.min()!) * 111_000
        let lonSpanM = (lons.max()! - lons.min()!) * 111_000 * cos(mitte.latitude * .pi / 180)
        let distanz = min(max(max(latSpanM, lonSpanM) * 2.2 + 350, 500), 6000)
        kameraSetzen(mitte: mitte, distanz: distanz)
    }

    private func figurTippen(_ person: Person) {
        guard let d = standort.positionen[person] else { return }
        kameraSetzen(mitte: CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon), distanz: 400)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if person != Raum.shared.ich { ausgewaehlt = PersonAuswahl(person: person) }
    }

    private func doppeltGetippt() {
        kameraZentrieren()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func dreiDSchalten() {
        dreiD.toggle()
        if let mitte = kameraMitte {
            kameraSetzen(mitte: mitte, distanz: kameraDistanz)
        } else {
            kameraZentrieren()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Top overlay (Snap-Map-style style capsule + partner's area name)

    private var topLeiste: some View {
        HStack(alignment: .top) {
            stilCapsule
            Spacer()
            if let gebietPartner {
                Text(gebietPartner)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var stilCapsule: some View {
        HStack(spacing: 2) {
            Button {
                satellit.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: satellit ? "map" : "globe.europe.africa")
                    .font(.subheadline)
                    .frame(width: 40, height: 32)
            }
            .accessibilityLabel("Kartenstil wechseln")

            Button(action: dreiDSchalten) {
                Text(dreiD ? "3D" : "2D")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 40, height: 32)
                    .foregroundStyle(dreiD ? Color.white : Color.primary)
                    .background(dreiD ? Color.accentColor : .clear, in: .capsule)
            }
            .accessibilityLabel(dreiD ? "Zu 2D wechseln" : "Zu 3D wechseln")
        }
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Bottom-right glass controls

    private var knoepfe: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        glasKnopf("scope", "Beide zeigen") { kameraZentrieren() }
                        glasKnopf(unsereOrteAn ? "heart.fill" : "heart", "Unsere Orte") { unsereOrteAn.toggle() }
                            .tint(unsereOrteAn ? Color.loveaRose : nil)
                        glasKnopf("list.bullet", "Orte verwalten") { orteListe = true }
                    }
                }
                .padding()
            }
        }
    }

    private func glasKnopf(_ symbol: String, _ label: String, _ aktion: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            aktion()
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.clear.interactive(), in: .circle)
        .accessibilityLabel(label)
    }

    // MARK: - Ort-Vorschlag banner (Z-8.4)

    @ViewBuilder
    private var banner: some View {
        if let v = orte.vorschlag {
            OrtVorschlagBanner(vorschlag: v)
                .padding(.horizontal)
        }
    }

    // MARK: - Partner-Gebiet (reverse geocode, cached)

    private func gebietLaden() async {
        guard let partner, let d = standort.positionen[partner] else { return }
        gebietPartner = await OrtePOI.shared.gebietName(lat: d.lat, lon: d.lon)
    }
}

struct KarteOffenAn: Encodable { let an: Bool }

/// One figure on the map: a place bubble when the person is at a known place, the full-body
/// figure pin, and a Snap-Map-style glass name label with battery, age and (partner-only) distance.
private struct FigurPin: View {
    let person: Person
    let daten: StandortDaten
    let zustand: FigurZustand
    let aussehen: FigurAussehen
    let istIch: Bool
    let tippen: () -> Void

    private var ortName: String? {
        OrteModell.shared.aktuellerOrt(person, lat: daten.lat, lon: daten.lon)?.name
    }

    var body: some View {
        VStack(spacing: 4) {
            if let ortName {
                Text(ortName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassEffect(.regular, in: .capsule)
            }

            FigurView(aussehen, zustand: zustand, groesse: 120, bildrate: 15, ganzkoerper: true, poseImmer: true)
            namensSchild
            if !istIch { SpotifyHoertGeradeChip() }
        }
        .onTapGesture(perform: tippen)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Figur von \(person.name)")
        .accessibilityHint(istIch ? "Zoomt heran" : "Zoomt heran, öffnet Standort-Details")
        .accessibilityAddTraits(.isButton)
    }

    private var namensSchild: some View {
        HStack(spacing: 5) {
            Text(person.name)
                .font(.caption.weight(.semibold))
                .italic()
            akkuChip
            if let alter = alterFallsNichtLive {
                Text(alter).font(.caption2).foregroundStyle(.secondary)
            }
            if !istIch, let entfernung = entfernungZuMir {
                Text(entfernung).font(.caption2).foregroundStyle(.secondary)
            }
            // Z-27.5: Wetter neben der Partner-Figur, nicht bei der eigenen.
            if !istIch, let stand = WetterModell.shared.partner {
                Image(systemName: stand.symbol)
                Text("\(Int(stand.temperatur.rounded()))°").monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private var akkuChip: some View {
        if let akku = daten.akku {
            let prozent = Int((akku * 100).rounded())
            HStack(spacing: 2) {
                Image(systemName: daten.laedt ? "bolt.fill" : "battery.100")
                // Z-19.3: nie abgeschnitten, auch bei "100 %".
                Text("\(prozent) %")
                    .monospacedDigit()
                    .fixedSize()
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(akkuFarbe(prozent), in: .capsule)
        }
    }

    private func akkuFarbe(_ prozent: Int) -> Color {
        if prozent >= 50 { return .green }
        if prozent >= 20 { return .yellow }
        return .red
    }

    private var alterFallsNichtLive: String? {
        let text = daten.alterText
        return text == "gerade eben" ? nil : text
    }

    private var entfernungZuMir: String? {
        guard let ich = Raum.shared.ich, let eigene = Standort.shared.positionen[ich] else { return nil }
        let meter = CLLocation(latitude: eigene.lat, longitude: eigene.lon).distance(from: CLLocation(latitude: daten.lat, longitude: daten.lon))
        let text = String(format: "%.1f", meter / 1000).replacingOccurrences(of: ".", with: ",")
        return "\(text) km"
    }
}

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
