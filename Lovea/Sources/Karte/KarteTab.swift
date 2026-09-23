import CoreLocation
import MapKit
import SwiftUI

/// Local wrapper so `.sheet(item:)` works without adding `Identifiable` to `Person` itself -
/// other wave-2 blocks may add that conformance in their own files, and two would collide.
private struct PersonAuswahl: Identifiable {
    let person: Person
    var id: String { person.rawValue }
}

/// Z-41: full-screen map, opened from the partner profile. The figures stand on the pitched
/// realistic map; the controls float on glass - close and weather top left, the partner's town top
/// right, the quiet 3D/satellite switch bottom left, "Unsere Orte" bottom centre, framing and the
/// places list bottom right. Dark look at night and over satellite.
struct KarteTab: View {
    var schliessen: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kamera: MapCameraPosition = .automatic
    /// Z-41.3: the camera as it really is (after pans, pinches, rotation), read back through
    /// `onMapCameraChange`. Both toggles start from here, so nothing snaps back to an old target.
    @State private var aktuelleKamera: MapCamera?
    @State private var startGesetzt = false
    @State private var satellit = false
    @State private var dreiD = true
    /// Z-41.1: the first tap on a figure zooms to it and sets this; the second tap opens the info card.
    @State private var fokus: Person?
    @State private var info: PersonAuswahl?
    @State private var orteListe = false
    @State private var gebietPartner: String?
    @State private var unsereOrteAn = false
    @State private var gemeinsamAusgewaehlt: GemeinsamerOrt?

    private let standort = Standort.shared
    private let orte = OrteModell.shared

    private var partnerDaten: StandortDaten? { Raum.shared.ich.flatMap { standort.positionen[$0.partner] } }
    private var eigeneDaten: StandortDaten? { Raum.shared.ich.flatMap { standort.positionen[$0] } }

    var body: some View {
        inhalt
            .sheet(item: $info) { InfoKarteView(person: $0.person) }
            .sheet(isPresented: $orteListe) { OrteListeView() }
            .sheet(item: $gemeinsamAusgewaehlt) { GemeinsamerOrtDetail(ort: $0) }
            .task {
                Standort.shared.start()
                FigurenModell.shared.zustandSenden(.init(haupt: .karte))
                Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: true))
                SpotifyModell.shared.schauen() // Z-27.6: Spec 9 "nur wenn der Partner hinschaut"
            }
            .task(id: partnerDaten?.lat) {
                await gebietLaden()
                await WetterModell.shared.aktualisieren()
            }
            .onDisappear {
                Anwesenheit.shared.app(nil)
                Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: false))
                SpotifyModell.shared.wegschauen()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { Raum.shared.fluechtig("karte.offen", KarteOffenAn(an: false)) }
            }
    }

    /// Satellite imagery and the night (20-7 Uhr Berlin) both get the dark appearance: dark map,
    /// light status bar, labels and glass readable on dark ground.
    private var inhalt: some View {
        karte
            .safeAreaInset(edge: .top) { obereLeiste }
            .safeAreaInset(edge: .bottom) { untereLeiste }
            .preferredColorScheme(satellit || KarteLogik.istNacht(Date()) ? .dark : nil)
    }

    // MARK: - Map

    private var karte: some View {
        Map(position: $kamera) {
            ForEach(Person.allCases, id: \.self) { person in
                if let d = standort.positionen[person] {
                    // Z-19.3: `Annotation`s eigener Titel würde den Namen doppelt zeigen.
                    Annotation(person.name, coordinate: d.punkt, anchor: .bottom) {
                        FigurPin(person: person, daten: d, fokussiert: fokus == person) { figurTippen(person) }
                    }
                    .annotationTitles(.hidden)
                    if d.genau > 20 {
                        MapCircle(center: d.punkt, radius: d.genau)
                            .foregroundStyle(Color.person(person).opacity(0.12))
                            .stroke(Color.person(person).opacity(0.4), lineWidth: 1)
                    }
                }
            }
            unsereOrtePins
        }
        .mapStyle(kartenStil)
        .mapControls { MapCompass() }
        .onMapCameraChange(frequency: .onEnd) { kontext in kameraGeaendert(kontext.camera) }
        .onAppear { startKamera() }
        .onChange(of: standort.positionen.count) { _, _ in startKamera() }
    }

    /// Z-41.2: every place and shop, realistic elevation (3D buildings once pitched); satellite as
    /// hybrid so street names and places stay.
    private var kartenStil: MapStyle {
        satellit
            ? .hybrid(elevation: .realistic, pointsOfInterest: .all)
            : .standard(elevation: .realistic, pointsOfInterest: .all)
    }

    // Separate `MapContentBuilder`, so `karte`'s body stays small (common.md).
    @MapContentBuilder
    private var unsereOrtePins: some MapContent {
        if unsereOrteAn {
            ForEach(KarteLogik.unsereOrte(orte.gemeinsameOrte)) { ort in
                Annotation("Unser Ort", coordinate: CLLocationCoordinate2D(latitude: ort.lat, longitude: ort.lon), anchor: .bottom) {
                    OrtBlase(ort: ort) { gemeinsamAusgewaehlt = ort }
                }
                .annotationTitles(.hidden)
            }
        }
    }

    // MARK: - Camera

    private func bewegen(_ ziel: MapCameraPosition, animiert: Bool = true) {
        withAnimation(animiert && !reduceMotion ? Feder.weich : nil) { kamera = ziel }
    }

    private func kameraSetzen(_ mitte: CLLocationCoordinate2D, distanz: CLLocationDistance, animiert: Bool = true) {
        let heading = aktuelleKamera?.heading ?? 0
        bewegen(.camera(MapCamera(centerCoordinate: mitte, distance: distanz, heading: heading, pitch: dreiD ? 55 : 0)), animiert: animiert)
    }

    private func kameraGeaendert(_ neu: MapCamera) {
        aktuelleKamera = neu
        // Two-tap rule: the focus only lasts while the camera still looks at that figure.
        guard let f = fokus, let d = standort.positionen[f] else { return }
        let mitte = CLLocation(latitude: neu.centerCoordinate.latitude, longitude: neu.centerCoordinate.longitude)
        if mitte.distance(from: CLLocation(latitude: d.lat, longitude: d.lon)) > 150 { fokus = nil }
    }

    /// One-shot (Z-41.3): a later position update never moves a camera the user has taken over.
    /// Far apart, the partner's figure up close; together, both.
    private func startKamera() {
        guard !startGesetzt, !standort.positionen.isEmpty else { return }
        startGesetzt = true
        if let ich = eigeneDaten, let partner = partnerDaten, ich.meter(bis: partner) > 2000 {
            kameraSetzen(partner.punkt, distanz: 700, animiert: false)
        } else {
            beideZeigen(animiert: false)
        }
    }

    private func beideZeigen(animiert: Bool = true) {
        let punkte = Person.allCases.compactMap { standort.positionen[$0] }
        guard !punkte.isEmpty else { return }
        let lats = punkte.map(\.lat), lons = punkte.map(\.lon)
        let mitte = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        // ponytail: flat-earth meters per degree, plenty for framing at this scale.
        let hoehe = (lats.max()! - lats.min()!) * 111_000
        let breite = (lons.max()! - lons.min()!) * 111_000 * cos(mitte.latitude * .pi / 180)
        fokus = nil
        if max(hoehe, breite) < 1500 {
            kameraSetzen(mitte, distanz: max(max(hoehe, breite) * 2.2 + 350, 500), animiert: animiert)
        } else {
            // Far apart, MapKit fits the region itself: the old capped 3D distance put both figures
            // off-screen once they were ~10 km apart (the "empty" satellite map, Z-41.3).
            bewegen(.region(MKCoordinateRegion(center: mitte, latitudinalMeters: hoehe * 2 + 1000, longitudinalMeters: breite * 2 + 1000)), animiert: animiert)
        }
    }

    private func figurTippen(_ person: Person) {
        Haptik.leicht()
        if fokus == person {
            info = PersonAuswahl(person: person)
        } else if let d = standort.positionen[person] {
            fokus = person
            kameraSetzen(d.punkt, distanz: 350)
        }
    }

    /// Z-41.2: tapping the town name zooms out until the whole town is in view.
    private func stadtZeigen() {
        guard let p = partnerDaten else { return }
        Haptik.leicht()
        fokus = nil
        // ponytail: a fixed 8 km square around the partner covers a small town like Übach-Palenberg;
        // fit the locality's real bounds (MKLocalSearch `boundingRegion`) if big cities matter.
        bewegen(.region(MKCoordinateRegion(center: p.punkt, latitudinalMeters: 8000, longitudinalMeters: 8000)))
    }

    private func dreiDSchalten() {
        dreiD.toggle()
        Haptik.auswahl()
        guard let k = aktuelleKamera else { return }
        bewegen(.camera(MapCamera(centerCoordinate: k.centerCoordinate, distance: k.distance, heading: k.heading, pitch: dreiD ? 55 : 0)))
    }

    private func satellitSchalten() {
        // Re-pin the live camera before the style swap, so there is no stale target to jump back to.
        if let k = aktuelleKamera { kamera = .camera(k) }
        satellit.toggle()
        Haptik.auswahl()
    }

    // MARK: - Controls (glass only here, Liquid Glass rule)

    private var obereLeiste: some View {
        VStack(spacing: 8) {
            GlassEffectContainer(spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    if let schliessen {
                        rundKnopf("xmark", "Schließen", aktion: schliessen)
                    }
                    wetterAnzeige
                    Spacer(minLength: 8)
                    ortsname
                }
            }
            banner
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var untereLeiste: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                stilSchalter
                Spacer(minLength: 0)
                unsereOrteChip
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    rundKnopf("scope", "Beide zeigen") { beideZeigen() }
                    rundKnopf("list.bullet", "Orte verwalten") { orteListe = true }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    /// Top left (Z-41.2): the partner's weather, symbol and temperature.
    @ViewBuilder
    private var wetterAnzeige: some View {
        if let stand = WetterModell.shared.partner {
            let grad = Int(stand.temperatur.rounded())
            HStack(spacing: 5) {
                Image(systemName: stand.symbol).symbolRenderingMode(.multicolor)
                Text("\(grad)°").monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .kartenGlas(satellit, in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wetter: \(grad) Grad")
        }
    }

    /// Top right (Z-41.2): the partner's town; tapping it zooms out to the whole town.
    @ViewBuilder
    private var ortsname: some View {
        if let gebietPartner {
            Button(action: stadtZeigen) {
                Text(gebietPartner)
                    .font(.headline)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .kartenGlas(satellit, in: .capsule, interaktiv: true)
            .accessibilityHint("Zeigt die ganze Stadt")
        }
    }

    /// Bottom left, deliberately quiet (Ahmed: "leiser an den Rand"): 3D/2D and map/satellite.
    private var stilSchalter: some View {
        HStack(spacing: 0) {
            Button(action: dreiDSchalten) {
                Text(dreiD ? "3D" : "2D")
                    .font(.footnote.weight(.bold))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("3D-Ansicht")
            .accessibilityValue(dreiD ? "an" : "aus")
            .accessibilityAddTraits(.isToggle)
            Button(action: satellitSchalten) {
                Image(systemName: satellit ? "globe.europe.africa.fill" : "map")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Satellit")
            .accessibilityValue(satellit ? "an" : "aus")
            .accessibilityAddTraits(.isToggle)
        }
        .buttonStyle(.plain)
        .kartenGlas(satellit, in: .capsule, interaktiv: true)
    }

    /// Z-41.2: the old bare heart, now labeled - it shows our shared places as photo bubbles.
    private var unsereOrteChip: some View {
        Button {
            Haptik.auswahl()
            unsereOrteAn.toggle()
        } label: {
            Label {
                Text("Unsere Orte")
            } icon: {
                Image(systemName: unsereOrteAn ? "heart.fill" : "heart")
                    .foregroundStyle(unsereOrteAn ? Color.loveaRose : Color.primary)
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .kartenGlas(satellit, in: .capsule, interaktiv: true)
        .accessibilityValue(unsereOrteAn ? "an" : "aus")
        .accessibilityAddTraits(.isToggle)
    }

    private func rundKnopf(_ symbol: String, _ label: String, aktion: @escaping () -> Void) -> some View {
        Button {
            Haptik.leicht()
            aktion()
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .kartenGlas(satellit, in: .circle, interaktiv: true)
        .accessibilityLabel(label)
    }

    // MARK: - Ort-Vorschlag banner (Z-8.4)

    @ViewBuilder
    private var banner: some View {
        if let v = orte.vorschlag {
            OrtVorschlagBanner(vorschlag: v)
        }
    }

    // MARK: - Partner-Gebiet (reverse geocode, cached)

    private func gebietLaden() async {
        guard let d = partnerDaten else { return }
        gebietPartner = await OrtePOI.shared.gebietName(lat: d.lat, lon: d.lon)
    }
}

private extension View {
    /// Glass for the floating map controls only. Regular over the standard map; clear over satellite
    /// imagery with the HIG's 35 % dark dimming underneath, so labels stay legible on bright photos.
    func kartenGlas(_ satellit: Bool, in form: some Shape, interaktiv: Bool = false) -> some View {
        let glas: Glass = satellit ? .clear : .regular
        return background(Color.black.opacity(satellit ? 0.35 : 0), in: form)
            .glassEffect(interaktiv ? glas.interactive() : glas, in: form)
    }
}

struct KarteOffenAn: Encodable { let an: Bool }

/// One person on the map (Z-41.1): the figure standing on its spot, the Snap-style label
/// "Name · Akku · vor 5 min" underneath (content layer: material, not glass), and - for the partner -
/// what they are listening to above the head, outside the button so the two taps never collide.
private struct FigurPin: View {
    let person: Person
    let daten: StandortDaten
    let fokussiert: Bool
    let tippen: () -> Void

    private var alter: String? { KarteLogik.alterText(sekunden: daten.sekundenAlt ?? 0) }

    var body: some View {
        VStack(spacing: 2) {
            if person != Raum.shared.ich { SpotifyHoertGeradeChip() }
            Button(action: tippen) {
                VStack(spacing: 2) {
                    KartenFigur(person: person, daten: daten)
                    etikett
                }
            }
            .buttonStyle(.federnd)
            .accessibilityLabel(vorlesen)
            .accessibilityHint(fokussiert ? "Öffnet die Info-Karte" : "Zoomt heran")
        }
    }

    private var etikett: some View {
        HStack(spacing: 4) {
            Text(person.name).fontWeight(.semibold)
            if let akku = daten.akku {
                Text("·").foregroundStyle(.secondary)
                Image(systemName: KarteLogik.akkuSymbol(akku, laedt: daten.laedt))
                    .foregroundStyle(akkuFarbe(akku))
                Text(KarteLogik.akkuText(akku)).monospacedDigit()
            }
            if let alter {
                Text("·").foregroundStyle(.secondary)
                Text(alter)
            }
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: .capsule)
    }

    private func akkuFarbe(_ akku: Double) -> Color {
        if daten.laedt { return .green }
        return akku < 0.2 ? .red : .primary
    }

    private var vorlesen: String {
        var teile = ["Figur von \(person.name)"]
        if let akku = daten.akku { teile.append("Akku \(KarteLogik.akkuText(akku))\(daten.laedt ? ", lädt" : "")") }
        if let alter { teile.append(alter) }
        return teile.joined(separator: ", ")
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
