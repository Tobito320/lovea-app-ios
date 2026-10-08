import SwiftUI

/// Z-R9: aus / 3 s / 10 s, cycled by tapping the menu row.
enum KameraTimer: CaseIterable {
    case aus, drei, zehn

    var sekunden: Int {
        switch self {
        case .aus: 0
        case .drei: 3
        case .zehn: 10
        }
    }

    var naechster: KameraTimer {
        switch self {
        case .aus: .drei
        case .drei: .zehn
        case .zehn: .aus
        }
    }

    var label: String {
        switch self {
        case .aus: "Timer: Aus"
        case .drei: "Timer: 3 s"
        case .zehn: "Timer: 10 s"
        }
    }
}

/// Right-hand vertical menu (Z-R9, `snap-01`/`snap-03`): Wechseln + Blitz always visible; a chevron
/// expands Timer/Raster/Freihand/Multi-Snap/Stabilisierung/Schönheit, each with its text label to
/// the left of its icon. `steuerung` is `@Observable`, so passing it as a plain reference (not a
/// `Binding`) still redraws this view on every toggle — `SnapKameraView` does the same.
///
/// Deliberately NOT built (Ahmed's explicit "do NOT want" list, even though Snapchat has them): AI,
/// Sounds, Greenscreen, duale Kamera, HD-Modus, Geschwindigkeit, Selfie-Einstellungen, Lenses.
struct KameraSeitenMenu: View {
    let steuerung: SnapKameraSteuerung
    /// Wrapped by the view (Review Minor fix, 2026-10-01: a bare `steuerung.kameraWechseln` method
    /// reference has no precedent elsewhere in this file — everywhere else wraps in `{ … }`) AND
    /// (Review Important fix: timer cancel) so the view can cancel a running countdown before the
    /// camera actually switches.
    let onWechseln: () -> Void
    @Binding var erweitert: Bool
    @Binding var timer: KameraTimer
    @Binding var rasterAn: Bool
    @Binding var freihandAn: Bool
    @Binding var multiSnapAn: Bool
    @Binding var filterOffen: Bool
    /// A filter other than Original is picked: the button lights up.
    let filterGewaehlt: Bool
    let nimmtVideoAuf: Bool

    var body: some View {
        VStack(spacing: 6) {
            knopf("arrow.triangle.2.circlepath.camera") { onWechseln() }
                .accessibilityLabel("Kamera wechseln")
                .disabled(nimmtVideoAuf)

            knopf(steuerung.blitzAn ? "bolt.fill" : "bolt.slash.fill") { steuerung.blitzAn.toggle() }
                .foregroundStyle(steuerung.blitzAn ? .yellow : .white)
                .accessibilityLabel("Blitz")
                .accessibilityValue(steuerung.blitzAn ? "an" : "aus")

            knopf("camera.filters") {
                Haptik.auswahl()
                withAnimation(Feder.schnell) { filterOffen.toggle() }
            }
            .foregroundStyle(filterGewaehlt || filterOffen ? Color.loveaRose : .white)
            .accessibilityLabel("Filter")
            .accessibilityValue(filterGewaehlt ? "gewählt" : "Original")

            if erweitert {
                zeile(label: timer.label, symbol: "timer") { timer = timer.naechster }
                    .foregroundStyle(timer == .aus ? .white : Color.loveaRose)
                zeile(label: "Raster", symbol: "grid") { rasterAn.toggle() }
                    .foregroundStyle(rasterAn ? Color.loveaRose : .white)
                zeile(label: "Freihand", symbol: freihandAn ? "record.circle.fill" : "record.circle") { freihandAn.toggle() }
                    .foregroundStyle(freihandAn ? Color.loveaRose : .white)
                    .disabled(nimmtVideoAuf)
                zeile(label: "Multi-Snap", symbol: "square.stack") { multiSnapAn.toggle() }
                    .foregroundStyle(multiSnapAn ? Color.loveaRose : .white)
                zeile(label: "Stabilisierung", symbol: "video.and.waveform") { steuerung.stabilisierungAn.toggle() }
                    .foregroundStyle(steuerung.stabilisierungAn ? Color.loveaRose : .white)
                zeile(label: "Schönheit", symbol: "sparkles") { steuerung.schoenheitAn.toggle() }
                    .foregroundStyle(steuerung.schoenheitAn ? Color.loveaRose : .white)
            }

            knopf(erweitert ? "chevron.up" : "chevron.down") {
                Haptik.auswahl()
                withAnimation(Feder.schnell) { erweitert.toggle() }
            }
            .accessibilityLabel(erweitert ? "Menü einklappen" : "Mehr Kamera-Optionen")
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.vertical, 6)
        .padding(.horizontal, erweitert ? 10 : 0)
        .glassEffect(.regular.tint(Color.black.opacity(0.3)), in: .rect(cornerRadius: 26))
        .padding(.trailing, 12)
    }

    private func knopf(_ symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) { Image(systemName: symbol).frame(width: 44, height: 44) }
    }

    private func zeile(label: String, symbol: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 8) {
                Text(label).font(.subheadline.weight(.semibold))
                Image(systemName: symbol).frame(width: 30, height: 30)
            }
        }
        .accessibilityLabel(label)
    }
}
