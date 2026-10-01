import SwiftUI

/// Z-R9: three purely visual overlays for the camera screen — rule-of-thirds grid, a timer
/// countdown, and the front-camera ring light frame. No AVFoundation, no state of their own.

/// Rule-of-thirds grid (Ahmed's "Raster" toggle). Two lines each way, thin and half-transparent so
/// it reads as a guide, not a UI element competing with the shot.
struct KameraRasterOverlay: View {
    var body: some View {
        Canvas { context, groesse in
            var pfad = Path()
            for i in 1...2 {
                let x = groesse.width * CGFloat(i) / 3
                pfad.move(to: CGPoint(x: x, y: 0))
                pfad.addLine(to: CGPoint(x: x, y: groesse.height))
                let y = groesse.height * CGFloat(i) / 3
                pfad.move(to: CGPoint(x: 0, y: y))
                pfad.addLine(to: CGPoint(x: groesse.width, y: y))
            }
            context.stroke(pfad, with: .color(.white.opacity(0.5)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Big countdown number for "Timer" (3 s/10 s). `sekunden` is the number still to show.
struct KameraCountdownOverlay: View {
    let sekunden: Int

    var body: some View {
        Text("\(sekunden)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.4), radius: 12)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Auslöser in \(sekunden) Sekunden")
    }
}

/// Front-camera "ring light" (Ahmed's spec 2, `snap-02`): a bright white frame around the preview,
/// on exactly while `aktiv` (screen brightness is handled separately in `SnapKameraSteuerung`,
/// since that's a side effect, not a view).
struct KameraRinglichtRahmen: View {
    let aktiv: Bool

    var body: some View {
        Rectangle()
            .stroke(.white, lineWidth: 40)
            .opacity(aktiv ? 1 : 0)
            .blur(radius: 20)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(Feder.schnell, value: aktiv)
    }
}
