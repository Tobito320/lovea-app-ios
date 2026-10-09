import MapKit
import Observation

enum OrtSuche {
    static let entprellen: Duration = .milliseconds(400)
    static let hoechstensTreffer = 8

    static func anfrage(_ eingabe: String) -> String {
        eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Suche erst ab zwei Zeichen.
    static func lohnt(_ eingabe: String) -> Bool { anfrage(eingabe).count >= 2 }

    static func ort(aus item: MKMapItem) -> PunktOrt? {
        let p = item.placemark
        let c = p.coordinate
        guard CLLocationCoordinate2DIsValid(c) else { return nil }
        let name = OrtName.sauber(item.name, strasse: p.thoroughfare)
        guard !name.isEmpty else { return nil }
        let adresse = OrtKurz.adresse(strasse: p.thoroughfare, nr: p.subThoroughfare, plz: p.postalCode, ort: p.locality)
        return PunktOrt(name: name, lat: c.latitude, lon: c.longitude, adresse: adresse)
    }

    /// Läuft ganz ohne Isolation: Anfrage und Suche bleiben lokal. Wird die Aufgabe abgebrochen,
    /// bricht auch die Suche ab.
    static func holen(_ text: String, region: MKCoordinateRegion?) async -> [PunktOrt] {
        let anfrage = MKLocalSearch.Request()
        anfrage.naturalLanguageQuery = text
        anfrage.resultTypes = [.pointOfInterest, .address]
        if let region { anfrage.region = region }
        let lauf = SucheLauf(MKLocalSearch(request: anfrage))
        return await withTaskCancellationHandler {
            guard let antwort = try? await lauf.suche.start() else { return [] }
            return antwort.mapItems.prefix(Self.hoechstensTreffer).compactMap(Self.ort(aus:))
        } onCancel: {
            lauf.suche.cancel()
        }
    }

    /// Nur wenn die App den eigenen Standort schon hat. Fragt nie nach.
    @MainActor static func region() -> MKCoordinateRegion? {
        guard let ich = Raum.shared.ich, let d = Standort.shared.positionen[ich] else { return nil }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon),
            latitudinalMeters: 50_000, longitudinalMeters: 50_000)
    }
}

private final class SucheLauf: @unchecked Sendable {
    let suche: MKLocalSearch
    init(_ suche: MKLocalSearch) { self.suche = suche }
}

/// Entprellt und erst ab zwei Zeichen. Jede neue Eingabe bricht die Aufgabe davor ab (`.task(id:)`).
@MainActor
@Observable
final class OrtSucheModell {
    private(set) var treffer: [PunktOrt] = []

    func leeren() { treffer = [] }

    func suchen(_ eingabe: String) async {
        guard OrtSuche.lohnt(eingabe) else { treffer = []; return }
        try? await Task.sleep(for: OrtSuche.entprellen)
        guard !Task.isCancelled else { return }
        let gefunden = await OrtSuche.holen(OrtSuche.anfrage(eingabe), region: OrtSuche.region())
        guard !Task.isCancelled else { return }
        treffer = gefunden
    }
}
