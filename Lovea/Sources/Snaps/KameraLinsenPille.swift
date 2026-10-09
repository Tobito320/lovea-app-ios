import SwiftUI

/// Z-R9: pure math behind the lens pill (".5 | 1x | 2.7x") — which chips to show for a given back
/// camera device, and how a raw `videoZoomFactor` becomes the text on a chip. No `AVCaptureDevice`
/// here, so this is testable without a device/simulator.
enum KameraLinse {
    /// Chips the pill offers: the ultra-wide (if the device goes below 1x), always 1x, then every
    /// tele switch-over factor within reach.
    ///
    /// ponytail: `virtualDeviceSwitchOverVideoZoomFactors` is the zoom factor where AVFoundation
    /// itself switches constituent lenses — used here as the tele chip's displayed value too.
    /// Apple doesn't expose the tele lens's exact marketing factor (e.g. "5x") for a virtual
    /// device; this is the closest documented number. Swap in a per-device table if a real
    /// triple-camera iPhone shows an off label.
    static func werte(minZoom: CGFloat, switchOverFaktoren: [CGFloat], maxZoom: CGFloat) -> [CGFloat] {
        guard maxZoom >= 1 else { return [] }
        var werte: [CGFloat] = []
        if minZoom < 1 { werte.append(minZoom) }
        werte.append(1)
        for faktor in switchOverFaktoren.sorted() where faktor > 1 && faktor <= maxZoom {
            werte.append(faktor)
        }
        return werte
    }

    /// Which chip is "live" right now — the last one not above `zoomFaktor` (the active lens range).
    static func aktiverIndex(werte: [CGFloat], zoomFaktor: CGFloat) -> Int {
        var index = 0
        for (i, wert) in werte.enumerated() where wert <= zoomFaktor { index = i }
        return index
    }

    /// "1x" at exactly 1, "2.7x" otherwise, ".5" below 1 (Snapchat drops the leading 0 only there —
    /// see `snap-05-zoom-1x-linsenwahl.png`).
    static func anzeige(_ zoomFaktor: CGFloat) -> String {
        if zoomFaktor == 1 { return "1x" }
        var zahl = String(format: "%.1f", (zoomFaktor * 10).rounded() / 10)
        if zahl.hasSuffix(".0") { zahl = String(zahl.dropLast(2)) }
        guard zoomFaktor < 1 else { return zahl + "x" }
        if zahl.hasPrefix("0") { zahl.removeFirst() }
        return zahl
    }
}

/// Lens pill above the shutter (Z-R9, `snap-04`/`snap-05`): one chip per lens, the active one shows
/// the live zoom value and is highlighted. Hidden entirely when there's nothing to switch between
/// (front camera, or back hardware without a virtual multi-camera device — Ahmed's spec).
struct KameraLinsenPille: View {
    let werte: [CGFloat]
    let aktuellerZoom: CGFloat
    let onWahl: (CGFloat) -> Void

    var body: some View {
        if werte.count > 1 {
            let aktiv = KameraLinse.aktiverIndex(werte: werte, zoomFaktor: aktuellerZoom)
            HStack(spacing: 2) {
                ForEach(Array(werte.enumerated()), id: \.offset) { index, wert in
                    let istAktiv = index == aktiv
                    Button {
                        Haptik.auswahl()
                        onWahl(wert)
                    } label: {
                        Text(istAktiv ? KameraLinse.anzeige(aktuellerZoom) : KameraLinse.anzeige(wert))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(istAktiv ? .yellow : .white)
                            .frame(minWidth: 30, minHeight: 30)
                    }
                }
            }
            .padding(.horizontal, 6)
            .background(.black.opacity(0.35), in: .capsule)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Zoom, \(KameraLinse.anzeige(aktuellerZoom))")
        }
    }
}
