import SwiftUI
import UIKit

/// Z-34.1: the conversation background — the shared backdrop (`chat.backdrop`), the same for both.
struct ChatHintergrundAnsicht: View {
    /// ponytail: unused since the backdrop is shared; kept so the chat's `ChatHintergrundAnsicht(ich:)` call stays.
    let ich: Person

    var body: some View {
        BackdropFlaeche(wahl: Backdrops.wahl)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// A backdrop choice, full-bleed: a template's picture (its mesh while the image is missing or
/// loading) with particles, or an own photo or drawing dimmed 35 % under neutral bubbles.
struct BackdropFlaeche: View {
    let wahl: BackdropWahl?

    var body: some View {
        switch wahl {
        case .foto(let medienId)?, .zeichnung(let medienId)?:
            EigenesBackdropBild(medienId: medienId)
        default:
            BackdropVorlagenBild(backdrop: Backdrops.backdrop(fuer: wahl))
        }
    }
}

/// Pure: mesh gradient, optional picture on top, dimming, particles. `bild` comes from the caller,
/// so the render board can pass it synchronously.
struct BackdropHintergrund: View {
    let backdrop: Backdrop
    let bild: UIImage?
    /// Own photo or drawing: always 35 % darker (Spec 2.8). Templates only in dark mode, a little,
    /// so a bright picture doesn't glow at night (HIG Dark Mode).
    var eigenesBild = false
    var animiert = true
    @Environment(\.colorScheme) private var schema

    private static let punkte: [SIMD2<Float>] = [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.5, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]

    private var abdunkelung: Double { eigenesBild ? 0.35 : schema == .dark ? 0.2 : 0 }

    var body: some View {
        MeshGradient(width: 3, height: 3, points: Self.punkte, colors: backdrop.ersatz)
            .overlay {
                if let bild {
                    Image(uiImage: bild).resizable().scaledToFill()
                }
            }
            .clipped()
            .overlay { Color.black.opacity(abdunkelung) }
            .overlay { BackdropPartikel(art: backdrop.animation, animiert: animiert) }
    }
}

extension Backdrop {
    /// The template picture from the asset catalog, decoded off the main thread (a 1290 × 2796 JPEG
    /// would otherwise decode on it at first draw). nil while the asset isn't there (mesh shows).
    func bildLaden() async -> UIImage? {
        let name = bildName
        return await Task.detached(priority: .userInitiated) { UIImage(named: name)?.preparingForDisplay() }.value
    }
}

private struct BackdropVorlagenBild: View {
    let backdrop: Backdrop
    @State private var bild: UIImage?

    var body: some View {
        BackdropHintergrund(backdrop: backdrop, bild: bild)
            .task(id: backdrop.id) {
                let geladen = await backdrop.bildLaden()
                withAnimation(Feder.weich) { bild = geladen }
            }
    }
}

/// Own photo or drawing. Neutral mesh until the picture is there.
private struct EigenesBackdropBild: View {
    let medienId: String
    @State private var bild: UIImage?

    var body: some View {
        BackdropHintergrund(backdrop: Backdrops.neutral, bild: bild, eigenesBild: true)
            .task(id: medienId) {
                let geladen = await Backdrops.eigenesBildLaden(medienId)
                withAnimation(Feder.weich) { bild = geladen }
            }
    }
}

extension Backdrops {
    /// Own photo or drawing by medium id. Both are uploaded media (a drawing as a snapshot, it
    /// only exists on one phone), so the partner's phone loads them the same way.
    static func eigenesBildLaden(_ medienId: String) async -> UIImage? {
        // Not one `??` chain with `try? await` inside: that doesn't type-check.
        var url = ChatMedien.eigeneQuellen[medienId] ?? Medien.lokal(medienId)
        if url == nil { url = try? await Medien.holen(medienId) }
        guard let url else { return nil }
        return await Bilddatei.laden(url, maxPixel: 2800) // screen-sized, decoded off the main actor
    }
}

// MARK: - Particles

/// Z-34.1: light particles over a backdrop, 30 fps. Still under Reduce Motion, off screen and in
/// the background; `animiert: false` draws one fixed frame (render board).
struct BackdropPartikel: View {
    let art: BackdropAnimation
    var animiert = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sichtbar = false

    var body: some View {
        Group {
            if art == .keine {
                Color.clear
            } else if animiert && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !sichtbar || scenePhase != .active)) { kontext in
                    leinwand(kontext.date.timeIntervalSinceReferenceDate)
                }
            } else {
                leinwand(7.5) // a moment when every particle is well inside the picture
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { sichtbar = true }
        .onDisappear { sichtbar = false }
    }

    private func leinwand(_ t: Double) -> some View {
        let zeichner = BackdropPartikelZeichner(art: art, t: t)
        return Canvas { g, size in zeichner.zeichne(g, size) }
    }
}

/// One frame at time `t` (seconds). Deterministic: each particle's traits come from a hash of its
/// index, so nothing jumps between frames or rebuilds.
private struct BackdropPartikelZeichner {
    let art: BackdropAnimation
    let t: Double

    func zeichne(_ g: GraphicsContext, _ size: CGSize) {
        switch art {
        case .keine:
            break
        case .herzen:
            ziehen(g, size, anzahl: 14, form: Self.herz, farben: [.white, Color(red: 1, green: 0.8, blue: 0.87)], groesse: 12...24, tempo: 0.035, steigt: true)
        case .blueten:
            ziehen(g, size, anzahl: 18, form: Path(ellipseIn: CGRect(x: -0.5, y: -0.32, width: 1, height: 0.64)),
                   farben: [Color(red: 0.97, green: 0.71, blue: 0.8), Color(red: 1, green: 0.86, blue: 0.9), Color(red: 0.95, green: 0.6, blue: 0.72)],
                   groesse: 8...14, tempo: 0.05, steigt: false, dreh: 1.4)
        case .schnee:
            ziehen(g, size, anzahl: 48, form: Path(ellipseIn: CGRect(x: -0.5, y: -0.5, width: 1, height: 1)), farben: [.white], groesse: 2...6, tempo: 0.07, steigt: false)
        case .blaetter:
            ziehen(g, size, anzahl: 12, form: Self.blatt,
                   farben: [Color(red: 0.78, green: 0.33, blue: 0.12), Color(red: 0.88, green: 0.54, blue: 0.18), Color(red: 0.85, green: 0.63, blue: 0.23)],
                   groesse: 14...24, tempo: 0.04, steigt: false, dreh: 1.1)
        case .funkeln:
            funkeln(g, size, anzahl: 36, farben: [.white, Color(red: 1, green: 0.95, blue: 0.8)], groesse: 3...9)
        case .glitzer:
            funkeln(g, size, anzahl: 26, farben: [.white, Color(red: 1, green: 0.62, blue: 0.87), Color(red: 0.6, green: 0.9, blue: 1)], groesse: 6...13)
        }
    }

    /// Falling (or, for hearts, rising) particles that sway sideways; a hash spreads start, speed,
    /// lane and size.
    private func ziehen(_ g: GraphicsContext, _ size: CGSize, anzahl: Int, form: Path, farben: [Color],
                        groesse: ClosedRange<Double>, tempo: Double, steigt: Bool, dreh: Double = 0) {
        let breite = Double(size.width), hoehe = Double(size.height)
        let rand = 30.0
        let strecke = hoehe + 2 * rand
        for i in 0..<anzahl {
            let (a, b, c, d) = (Self.zufall(i, 0), Self.zufall(i, 1), Self.zufall(i, 2), Self.zufall(i, 3))
            let weg = (t * tempo * (0.6 + 0.8 * a) + b).truncatingRemainder(dividingBy: 1)
            let y: Double = steigt ? hoehe + rand - weg * strecke : weg * strecke - rand
            let x: Double = c * breite + sin(t * (0.4 + 0.6 * d) + d * 6.28) * 16
            var k = g
            k.opacity = steigt ? 0.75 * sin(.pi * weg) : 0.85
            k.translateBy(x: x, y: y)
            k.rotate(by: .radians(steigt ? 0.25 * sin(t + a * 6.28) : a * 6.28 + t * dreh * (d - 0.5)))
            let s = groesse.lowerBound + c * (groesse.upperBound - groesse.lowerBound)
            k.scaleBy(x: s, y: s)
            k.fill(form, with: .color(farben[i % farben.count]))
        }
    }

    /// Fixed sparkles that pulse in size and brightness.
    private func funkeln(_ g: GraphicsContext, _ size: CGSize, anzahl: Int, farben: [Color], groesse: ClosedRange<Double>) {
        let form = Self.stern
        let breite = Double(size.width), hoehe = Double(size.height)
        for i in 0..<anzahl {
            let (a, b, c, d) = (Self.zufall(i, 0), Self.zufall(i, 1), Self.zufall(i, 2), Self.zufall(i, 3))
            let puls = 0.5 + 0.5 * sin(t * (0.8 + 1.6 * a) + b * 6.28)
            var k = g
            k.opacity = 0.2 + 0.75 * puls * puls
            k.translateBy(x: c * breite, y: d * hoehe)
            let s = (groesse.lowerBound + b * (groesse.upperBound - groesse.lowerBound)) * (0.6 + 0.4 * puls)
            k.scaleBy(x: s, y: s)
            k.fill(form, with: .color(farben[i % farben.count]))
        }
    }

    /// Stable pseudo-random 0..<1 per particle and trait (the classic shader hash).
    private static func zufall(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    // Unit shapes around the origin, scaled per particle.

    private static var herz: Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.38))
        p.addCurve(to: CGPoint(x: -0.5, y: -0.08), control1: CGPoint(x: -0.12, y: 0.26), control2: CGPoint(x: -0.5, y: 0.12))
        p.addCurve(to: CGPoint(x: 0, y: -0.24), control1: CGPoint(x: -0.5, y: -0.42), control2: CGPoint(x: -0.06, y: -0.46))
        p.addCurve(to: CGPoint(x: 0.5, y: -0.08), control1: CGPoint(x: 0.06, y: -0.46), control2: CGPoint(x: 0.5, y: -0.42))
        p.addCurve(to: CGPoint(x: 0, y: 0.38), control1: CGPoint(x: 0.5, y: 0.12), control2: CGPoint(x: 0.12, y: 0.26))
        p.closeSubpath()
        return p
    }

    private static var blatt: Path {
        var p = Path()
        p.move(to: CGPoint(x: -0.5, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0.5, y: 0), control: CGPoint(x: 0, y: -0.42))
        p.addQuadCurve(to: CGPoint(x: -0.5, y: 0), control: CGPoint(x: 0, y: 0.42))
        p.closeSubpath()
        return p
    }

    private static var stern: Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -0.5))
        p.addQuadCurve(to: CGPoint(x: 0.5, y: 0), control: CGPoint(x: 0.07, y: -0.07))
        p.addQuadCurve(to: CGPoint(x: 0, y: 0.5), control: CGPoint(x: 0.07, y: 0.07))
        p.addQuadCurve(to: CGPoint(x: -0.5, y: 0), control: CGPoint(x: -0.07, y: 0.07))
        p.addQuadCurve(to: CGPoint(x: 0, y: -0.5), control: CGPoint(x: -0.07, y: -0.07))
        p.closeSubpath()
        return p
    }
}
