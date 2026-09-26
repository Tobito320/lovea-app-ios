import SwiftUI
import UIKit
import XCTest
@testable import Lovea

/// Z-34.1/Z-34.2 render boards: every backdrop (its picture if the asset is in the catalog, else
/// the mesh) with sample bubbles in its colors, once in light and once in dark mode.
final class RenderGalerieBackdropTests: XCTestCase {
    @MainActor
    func testBackdropTafeln() {
        let alle = Backdrops.alle + [Backdrops.neutral]
        for (name, schema) in [("backdrops-hell", ColorScheme.light), ("backdrops-dunkel", ColorScheme.dark)] {
            let zellen: [(titel: String, ansicht: AnyView)] = alle.map { backdrop in
                let probe = BackdropProbe(backdrop: backdrop, bild: UIImage(named: backdrop.bildName), animiert: false)
                    .frame(width: 300, height: 620)
                    .environment(\.colorScheme, schema)
                return (titel: backdrop.name, ansicht: AnyView(probe))
            }
            RenderTafel.speichern(name, spalten: 4, zellen: zellen)
        }
    }
}
