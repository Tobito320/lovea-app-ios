import SwiftUI

/// One bouquet, drawn into the frame it is given (3:5, `ZuhauseZeichnung.strauss` = 24 x 40 points
/// in the design space, scaled with the scene). The frame's bottom centre is the standing place:
/// on the dresser the bouquet stands there, in the vase its stems end inside the neck.
///
/// Placeholder from p58: three blooms in a paper cone, the colour picked from the ID. p59 replaces
/// the body of this view with the real bouquets and keeps `init(id:)`; the scene does not change.
struct StraussView: View {
    /// The bouquet's ID as the flower feature (p59) names it.
    let id: String

    private static let farben: [UInt32] = [0xFF8FA8, 0xFFD34E, 0xB9A7E0, 0xFFA77A, 0x8CC8F2, 0xF4F4F4]

    /// Stable across launches (`String.hashValue` is not): a sum over the unicode scalars.
    private var nummer: Int {
        id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    var body: some View {
        let blueten = FigurFarbe(Self.farben[nummer % Self.farben.count])
        Canvas { g, groesse in
            var u = g
            u.scaleBy(x: groesse.width / 30, y: groesse.height / 50)
            for x in [CGFloat(9), 15, 21] {
                linie(u, strich(P(15, 46), P(x, 20)), Pal.gruen.kontur, 3.5)
                linie(u, strich(P(15, 46), P(x, 20)), Pal.gruen.farbe, 1.8)
            }
            let papier = Path { p in
                p.move(to: P(5, 28))
                p.addLine(to: P(25, 28))
                p.addLine(to: P(17, 49))
                p.addLine(to: P(13, 49))
                p.closeSubpath()
            }
            teil(u, papier, Pal.popcorn, 2.5)
            for (x, y) in [(CGFloat(9), CGFloat(18)), (15, 11), (21, 18)] {
                teil(u, kreis(P(x, y), 5.6), blueten, 2)
                u.fill(kreis(P(x, y), 1.8), with: .color(Pal.gelb.farbe))
            }
        }
        .accessibilityHidden(true)
    }
}
