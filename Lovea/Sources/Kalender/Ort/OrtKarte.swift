import MapKit
import SwiftUI
import UIKit

/// Ein Schnappschuss je Ort und Hell/Dunkel, im Speicher gemerkt. Kein Live-Map in der Liste.
@MainActor
enum OrtSchnappschuss {
    static let groesse = CGSize(width: 400, height: 225)
    private static let cache = NSCache<NSString, UIImage>()

    static func bild(fuer ort: PunktOrt, dunkel: Bool) async -> UIImage? {
        let schluessel = (OrtLinks.cacheSchluessel(ort) + (dunkel ? "d" : "h")) as NSString
        if let gemerkt = cache.object(forKey: schluessel) { return gemerkt }
        let optionen = MKMapSnapshotter.Options()
        optionen.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: ort.lat, longitude: ort.lon),
            latitudinalMeters: 600, longitudinalMeters: 340)
        optionen.size = groesse
        optionen.traitCollection = UITraitCollection(userInterfaceStyle: dunkel ? .dark : .light)
        guard let snap = try? await MKMapSnapshotter(options: optionen).start() else { return nil }
        cache.setObject(snap.image, forKey: schluessel)
        return snap.image
    }
}

@MainActor
enum OrtOeffnen {
    static func googleDa(_ ort: PunktOrt) -> Bool {
        UIApplication.shared.canOpenURL(OrtLinks.googleMapsURL(ort))
    }

    // ponytail: `MKMapItem(placemark:)` ist in iOS 26 veraltet, baut aber (Warnungen sind keine Fehler) -
    // wie in InfoKarteView.
    static func apple(_ ort: PunktOrt) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: ort.lat, longitude: ort.lon)))
        item.name = ort.name
        item.openInMaps(launchOptions: nil)
    }
}

/// "Karte zeigen": Blatt mit einer Map und einer Nadel.
struct OrtKartenBlatt: View {
    let ort: PunktOrt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let mitte = CLLocationCoordinate2D(latitude: ort.lat, longitude: ort.lon)
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(center: mitte, latitudinalMeters: 800, longitudinalMeters: 800))) {
                Marker(ort.name, coordinate: mitte)
            }
            .navigationTitle(ort.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
