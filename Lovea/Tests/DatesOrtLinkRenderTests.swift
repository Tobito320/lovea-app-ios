import SwiftUI
import XCTest
@testable import Lovea

/// Render-Tafel "dates-blatt-ort-link": Blatt "Idee" mit Ort-Karte (graue Fläche) und Link-Chips, hell und dunkel.
@MainActor
final class DatesOrtLinkRenderTests: XCTestCase {
    func testBlattTafel() {
        let idee = DateIdee(
            id: "r", titel: "Reisen", kategorie: .reisen,
            ort: PunktOrt(name: "Eiffelturm bei Nacht", lat: 48.8584, lon: 2.2945, adresse: "Paris"),
            links: [
                DateLink(id: "1", url: "https://maps.google.com/?q=eiffelturm", titel: nil),
                DateLink(id: "2", url: "https://www.tiktok.com/@a/video/1", titel: nil),
                DateLink(id: "3", url: "https://www.instagram.com/p/x", titel: nil),
            ],
            geaendert: Date(timeIntervalSince1970: 1_791_100_000), von: .ahmed
        )
        let zellen: [(titel: String, ansicht: AnyView)] = [ColorScheme.light, .dark].map { schema in
            let ansicht = DateIdeeBlattRenderInhalt(idee: idee)
                .background(schema == .dark ? Color.black : Color.white)
                .environment(\.colorScheme, schema)
            return (titel: schema == .dark ? "Blatt mit Ort und Links, dunkel" : "Blatt mit Ort und Links, hell", ansicht: AnyView(ansicht))
        }
        RenderTafel.speichern("dates-blatt-ort-link", spalten: 2, zellen: zellen)
    }
}
