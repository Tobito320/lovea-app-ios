import CoreLocation
import MapKit
import SwiftUI

/// Z-41.3: "Die Karte" in the partner profile, no longer empty - a pitched 3D map with the partner's
/// figure standing on it (same state and extras as on the map), the weather, the place and the
/// distance. Tapping opens the full map. Content layer: material chips, no glass.
struct ProfilKarte: View {
    let person: Person
    let oeffnen: () -> Void
    @State private var ortName: String?

    private var standort: StandortDaten? { Standort.shared.positionen[person] }

    var body: some View {
        Button(action: oeffnen) {
            VStack(alignment: .leading, spacing: 0) {
                kartenBild
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
                zeilen
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .accessibilityHint("Öffnet die Karte")
        .task(id: standort.map { "\($0.lat),\($0.lon)" }) {
            await ortLaden()
            await WetterModell.shared.aktualisieren()
        }
    }

    @ViewBuilder
    private var kartenBild: some View {
        if let d = standort {
            karte(d).overlay(alignment: .topLeading) { wetter.padding(10) }
        } else {
            Rectangle()
                .fill(Color(uiColor: .tertiarySystemFill))
                .overlay {
                    Label("Noch kein Standort", systemImage: "location.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func karte(_ d: StandortDaten) -> some View {
        let kamera = MapCamera(centerCoordinate: d.punkt, distance: 450, heading: 0, pitch: 55)
        return Map(initialPosition: .camera(kamera), interactionModes: []) {
            Annotation(person.name, coordinate: d.punkt, anchor: .center) {
                // Static: the profile header already animates two figures, a third loop isn't worth the frames.
                KartenFigur(person: person, daten: d, groesse: 86, animiert: false)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .all))
        .id("\(d.lat),\(d.lon)")
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var wetter: some View {
        if let stand = WetterModell.shared.staende[person] {
            let grad = Int(stand.temperatur.rounded())
            Label("\(grad)°", systemImage: stand.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: .capsule)
                .accessibilityLabel("Wetter: \(grad) Grad")
        }
    }

    private var zeilen: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(person.name) ist hier: \(Text(ortName ?? "…").bold())")
                    .font(.subheadline)
                if let unterzeile {
                    Text(unterzeile).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
    }

    /// "3,2 km entfernt · vor 5 min"
    private var unterzeile: String? {
        guard let d = standort else { return nil }
        var teile: [String] = []
        if let ich = Raum.shared.ich, ich != person, let eigene = Standort.shared.positionen[ich] {
            teile.append(KarteLogik.entfernungText(eigene.meter(bis: d)))
        }
        if let alter = KarteLogik.alterText(sekunden: d.sekundenAlt ?? 0) { teile.append(alter) }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    private func ortLaden() async {
        guard let d = standort else { ortName = nil; return }
        if let info = OrteModell.shared.aktuellerOrt(person, lat: d.lat, lon: d.lon) {
            ortName = info.name
            return
        }
        // ponytail: `CLGeocoder` is deprecated on iOS 26 but still works (InfoKarteView and OrtePOI use
        // it too); move all three to `MKReverseGeocodingRequest` once someone can compile against it.
        guard let orte = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: d.lat, longitude: d.lon)), let p = orte.first else { return }
        let text = [p.subLocality ?? p.thoroughfare, p.locality].compactMap { $0 }.joined(separator: ", ")
        ortName = text.isEmpty ? nil : text
    }
}
