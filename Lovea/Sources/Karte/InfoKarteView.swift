import CoreLocation
import MapKit
import SwiftUI

/// Sheet shown when tapping the partner's figure on the map (Z-8.3): battery, place/address,
/// age and accuracy of the fix, distance, a route button, and "unterwegs" info.
struct InfoKarteView: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    @State private var adresse: String?
    @State private var supermarkt: String?

    private var standort: StandortDaten? { Standort.shared.positionen[person] }

    var body: some View {
        NavigationStack {
            Group {
                if let d = standort {
                    List {
                        Section {
                            LabeledContent("Akku") {
                                Label("\(Int((d.akku ?? 0) * 100)) %", systemImage: d.laedt ? "bolt.fill" : "battery.75")
                                    .foregroundStyle(d.laedt ? Color.green : .primary)
                            }
                            LabeledContent("Ort", value: ortText(d))
                            if let unterwegs = unterwegsText(d) {
                                LabeledContent("Unterwegs", value: unterwegs)
                            }
                            LabeledContent("Entfernung", value: entfernungText(d))
                        }
                        Section {
                            Button {
                                route(zu: d)
                            } label: {
                                Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Kein Standort", systemImage: "location.slash")
                }
            }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
        .task(id: standort?.lat) { await ortDetailsLaden() }
    }

    // MARK: - Text

    private func ortText(_ d: StandortDaten) -> String {
        if let info = OrteModell.shared.aktuellerOrt(person, lat: d.lat, lon: d.lon) {
            guard let seit = info.seit else { return info.name }
            return "\(info.name) seit \(seit.formatted(date: .omitted, time: .shortened))"
        }
        if let supermarkt { return "bei \(supermarkt)" }
        let basis = adresse ?? "wird geladen …"
        return "\(basis) · \(alterText(d.zeit)), ± \(Int(d.genau)) m"
    }

    private func unterwegsText(_ d: StandortDaten) -> String? {
        guard let tempo = d.tempo, tempo > 0.3 else { return nil }
        let kmh = Int((tempo * 3.6).rounded())
        let verb: String
        switch d.bewegung {
        case "laeuft": verb = "Läuft"
        case "rennt": verb = "Rennt"
        case "rad": verb = "Fährt Rad"
        case "faehrt": verb = "Fährt"
        default: verb = "Unterwegs"
        }
        return "\(verb), \(kmh) km/h"
    }

    private func entfernungText(_ d: StandortDaten) -> String {
        guard let ich = Raum.shared.ich, let eigene = Standort.shared.positionen[ich] else { return "unbekannt" }
        let meter = CLLocation(latitude: eigene.lat, longitude: eigene.lon).distance(from: CLLocation(latitude: d.lat, longitude: d.lon))
        let text = String(format: "%.1f", meter / 1000).replacingOccurrences(of: ".", with: ",")
        return "\(text) km von dir"
    }

    private func alterText(_ zeitIso: String) -> String {
        guard let zeit = ISO8601DateFormatter().date(from: zeitIso) else { return "" }
        let sekunden = Date().timeIntervalSince(zeit)
        return sekunden < 90 ? "gerade eben" : "vor \(Int(sekunden / 60)) Min"
    }

    // MARK: - Address / POI (device-side, throttled by `.task(id:)`)

    private func ortDetailsLaden() async {
        guard let d = standort, OrteModell.shared.aktuellerOrt(person, lat: d.lat, lon: d.lon) == nil else { return }
        if let name = await OrtePOI.shared.supermarktName(lat: d.lat, lon: d.lon) {
            supermarkt = name
            return
        }
        guard let orte = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: d.lat, longitude: d.lon)), let p = orte.first else { return }
        let text = [p.thoroughfare, p.locality].compactMap { $0 }.joined(separator: ", ")
        guard !text.isEmpty else { return }
        adresse = d.genau > 50 ? "in der Nähe von \(text)" : text
    }

    // MARK: - Route

    private func route(zu d: StandortDaten) {
        // ponytail: `MKMapItem(placemark:)` is deprecated in iOS 26 but still compiles
        // (SWIFT_TREAT_WARNINGS_AS_ERRORS=NO) - the newer `MKMapItem(location:address:)` needs an
        // `MKAddress`, not worth the extra risk here without a local compiler to check it against.
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon)))
        item.name = person.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
