import SwiftUI

/// One bouquet, drawn into the frame it is given (3:5, `ZuhauseZeichnung.strauss` = 24 x 40 points
/// in the design space, scaled with the scene). The frame's bottom centre is the standing place:
/// on the dresser the bouquet stands there, in the vase its stems end inside the neck.
///
/// p59: the five real bouquets (`StraussArt`, vector, drawn after Ahmed's photos). The ID is the
/// `StraussArt.rawValue`; an unknown ID draws nothing. The scene keeps this `init(id:)`.
struct StraussView: View {
    /// The bouquet's ID as the flower feature (p59) names it.
    let id: String

    var body: some View {
        Canvas { g, groesse in
            guard let art = StraussArt(rawValue: id) else { return }
            zeichneStrauss(g, art: art, in: CGRect(origin: .zero, size: groesse))
        }
        .accessibilityHidden(true)
    }
}
