import CoreLocation
import MapKit

/// One-off POI lookups: naming a proposed place (Z-8.4) and spotting an unsaved shop like
/// "bei Lidl" for a live position that isn't inside any saved place. An actor because it caches
/// results in mutable state across calls from both `OrteModell` and `InfoKarteView`.
actor OrtePOI {
    static let shared = OrtePOI()

    private var cache: [String: String?] = [:]

    /// Best-guess name and Lovea-Kategorie for a proposed place. Falls back to "Ort"/"sonstiges"
    /// when nothing nearby is known to Apple Maps.
    func vorschlag(lat: Double, lon: Double) async -> (name: String, kategorie: String) {
        guard let item = await naechstesPOI(lat: lat, lon: lon, radius: 150, kategorien: nil) else {
            return ("Ort", "sonstiges")
        }
        return (item.name ?? "Ort", Self.kategorie(fuer: item.pointOfInterestCategory))
    }

    /// Live "bei <Name>" for a market/store near a coordinate - never persisted, so results are
    /// cached per ~110 m coordinate cell to avoid repeat lookups while someone lingers nearby.
    func supermarktName(lat: Double, lon: Double) async -> String? {
        let schluessel = zelle(lat, lon)
        if let cached = cache[schluessel] { return cached }
        // ponytail: only `.foodMarket` is used here - unsure whether a generic `.store` case
        // exists on this SDK's `MKPointOfInterestCategory` without a local compiler to check.
        let ergebnis = await naechstesPOI(lat: lat, lon: lon, radius: 60, kategorien: [.foodMarket])?.name
        cache[schluessel] = ergebnis
        return ergebnis
    }

    /// Cached locality name for the map's top overlay (Snap-Map-style "Huenshoven"), keyed by
    /// the same ~110 m coordinate cell as `supermarktName` to avoid repeat reverse-geocodes.
    func gebietName(lat: Double, lon: Double) async -> String? {
        let schluessel = "gebiet:" + zelle(lat, lon)
        if let cached = cache[schluessel] { return cached }
        guard let orte = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)), let p = orte.first else { return nil }
        let name = p.locality ?? p.subLocality ?? p.name
        cache[schluessel] = name
        return name
    }

    private func naechstesPOI(lat: Double, lon: Double, radius: CLLocationDistance, kategorien: [MKPointOfInterestCategory]?) async -> MKMapItem? {
        let mitte = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let anfrage = MKLocalPointsOfInterestRequest(center: mitte, radius: radius)
        if let kategorien { anfrage.pointOfInterestFilter = MKPointOfInterestFilter(including: kategorien) }
        guard let antwort = try? await MKLocalSearch(request: anfrage).start() else { return nil }
        return antwort.mapItems.min {
            distanz($0, mitte) < distanz($1, mitte)
        }
    }

    private func distanz(_ item: MKMapItem, _ zu: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
            .distance(from: CLLocation(latitude: zu.latitude, longitude: zu.longitude))
    }

    private func zelle(_ lat: Double, _ lon: Double) -> String {
        "\(Int((lat * 1000).rounded())),\(Int((lon * 1000).rounded()))"
    }

    private static func kategorie(fuer poi: MKPointOfInterestCategory?) -> String {
        switch poi {
        case .fitnessCenter: "gym"
        case .school, .university: "schule"
        case .foodMarket: "supermarkt"
        default: "sonstiges"
        }
    }
}
