import CoreLocation
import MapKit
import SwiftUI

/// Z-41.1 info card, opened by the second tap on a figure: line 1 the name, line 2 place and
/// battery ("Zuhause · 62 %"), line 3 the distance ("3,2 km entfernt"), then a route button.
/// Weather and battery never sit next to the name (Spec 7).
struct InfoKarteView: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    @State private var adresse: String?
    @State private var supermarkt: String?

    private var standort: StandortDaten? { Standort.shared.positionen[person] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            kopf
            if let d = standort {
                ortUndAkku(d)
                if let abstand = entfernung(d) {
                    Text(abstand).foregroundStyle(.secondary)
                }
                if person != Raum.shared.ich { routeKnopf(d) }
            } else {
                Label("Noch kein Standort", systemImage: "location.slash").foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.fraction(0.34), .medium])
        .presentationDragIndicator(.visible)
        .task(id: standort?.lat) { await ortDetailsLaden() }
    }

    private var kopf: some View {
        HStack {
            Text(person.name).font(.title2.bold())
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schließen")
        }
    }

    private func ortUndAkku(_ d: StandortDaten) -> some View {
        HStack(spacing: 6) {
            Text(ortText(d)).lineLimit(2)
            if let akku = d.akku {
                Text("·").foregroundStyle(.secondary)
                Label(KarteLogik.akkuText(akku), systemImage: KarteLogik.akkuSymbol(akku, laedt: d.laedt))
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
                    .foregroundStyle(d.laedt ? Color.green : Color.primary)
                    .fixedSize()
            }
        }
    }

    private func routeKnopf(_ d: StandortDaten) -> some View {
        Button { route(zu: d) } label: {
            Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.loveaRose)
        .padding(.top, 12)
    }

    // MARK: - Text

    private func ortText(_ d: StandortDaten) -> String {
        if let info = OrteModell.shared.aktuellerOrt(person, lat: d.lat, lon: d.lon) {
            guard let seit = info.seit else { return info.name }
            return "\(info.name) seit \(seit.formatted(date: .omitted, time: .shortened))"
        }
        if let supermarkt { return "bei \(supermarkt)" }
        return adresse ?? "Ort wird geladen …"
    }

    /// Line 3 only for the partner - the distance to yourself says nothing.
    private func entfernung(_ d: StandortDaten) -> String? {
        guard let ich = Raum.shared.ich, ich != person, let eigene = Standort.shared.positionen[ich] else { return nil }
        return KarteLogik.entfernungText(eigene.meter(bis: d))
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
        let item = MKMapItem(placemark: MKPlacemark(coordinate: d.punkt))
        item.name = person.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
