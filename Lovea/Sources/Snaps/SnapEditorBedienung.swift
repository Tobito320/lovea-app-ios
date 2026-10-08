import SwiftUI

/// Editor chrome pieces without editor state (Runde 3, p43): the tool column, the one send action,
/// and the tap-to-place math. Glass only on the floating control layer.

/// Pure math for "tap the photo to put text there". Positions are fractions (0...1) of the content
/// box, like every other editor element, so live preview and export agree.
enum SnapTextPlatz {
    /// A touch that moved less than this (points, both axes) is a tap, not a swipe or a stroke.
    static let tippGrenze: CGFloat = 10

    /// Keeps the text fully on the photo: x within 0.12...0.88, y within 0.08...0.92.
    static let xBereich: ClosedRange<CGFloat> = 0.12...0.88
    static let yBereich: ClosedRange<CGFloat> = 0.08...0.92

    static func istTippen(_ verschiebung: CGSize) -> Bool {
        abs(verschiebung.width) < tippGrenze && abs(verschiebung.height) < tippGrenze
    }

    static func bruchteil(punkt: CGPoint, groesse: CGSize) -> CGPoint {
        guard groesse.width > 0, groesse.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return begrenzt(x: punkt.x / groesse.width, y: punkt.y / groesse.height)
    }

    static func begrenzt(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: min(max(xBereich.lowerBound, x), xBereich.upperBound),
                y: min(max(yBereich.lowerBound, y), yBereich.upperBound))
    }
}

/// Right-hand tool column: Text, Kritzeln, Sticker. No story/music/crop buttons.
struct SnapEditorWerkzeuge: View {
    let zeichnenAktiv: Bool
    let onText: () -> Void
    let onKritzeln: () -> Void
    let onSticker: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            knopf("textformat", "Text hinzufügen", onText)
            knopf(zeichnenAktiv ? "pencil.tip.crop.circle.fill" : "pencil.tip", "Kritzeln", onKritzeln)
                .foregroundStyle(zeichnenAktiv ? Color.loveaRose : .white)
                .accessibilityValue(zeichnenAktiv ? "an" : "aus")
            knopf("face.smiling", "Sticker hinzufügen", onSticker)
        }
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }

    private func knopf(_ symbol: String, _ label: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }
}

/// The one action: "Senden" (or "Übernehmen" in the chat tray). "bleibt im Chat" is an option on
/// the same send, not a second action, so it stays a quiet chip next to it.
struct SnapSendenLeiste: View {
    /// `nil` in tray mode: nothing is sent from there, so there is no "bleibt" option.
    let bleibt: Binding<Bool>?
    let sendetGerade: Bool
    let tray: Bool
    let onSenden: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let bleibt { bleibtChip(bleibt) }
            Spacer(minLength: 0)
            sendenKnopf
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func bleibtChip(_ bleibt: Binding<Bool>) -> some View {
        Button {
            Haptik.auswahl()
            bleibt.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: bleibt.wrappedValue ? "pin.fill" : "pin")
                Text("bleibt im Chat")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(bleibt.wrappedValue ? Color.loveaRose : .white)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("bleibt im Chat")
        .accessibilityValue(bleibt.wrappedValue ? "an" : "aus")
    }

    private var sendenKnopf: some View {
        Button(action: onSenden) {
            HStack(spacing: 8) {
                if sendetGerade {
                    ProgressView().tint(.white)
                } else {
                    Text(tray ? "Übernehmen" : "Senden")
                    Image(systemName: tray ? "checkmark" : "paperplane.fill")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: 48)
        }
        .glassEffect(.regular.tint(Color.loveaRose).interactive(), in: .capsule)
        .disabled(sendetGerade)
        .accessibilityLabel(tray ? "Übernehmen" : "Senden")
    }
}
