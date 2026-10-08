import SwiftUI

/// Camera chrome pieces that need no AVFoundation, so `SnapKameraView` stays small and the render
/// board can draw them (Runde 3, p43). Glass only on the floating control layer, over the preview.

/// X, top left.
struct KameraSchliessenKnopf: View {
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Abbrechen")
    }
}

/// Filter picked BEFORE the shot. No live preview on purpose (live filters froze the phone, see
/// the project rules): the choice only seeds the editor, which renders it once on the photo.
/// Text chips, no thumbnails: nothing to load when the camera opens.
struct KameraFilterLeiste: View {
    @Binding var auswahl: SnapFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SnapFilter.allCases) { filter in
                    chip(filter)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
        .accessibilityLabel("Filter")
    }

    private func chip(_ filter: SnapFilter) -> some View {
        let gewaehlt = filter == auswahl
        return Button {
            guard !gewaehlt else { return }
            Haptik.auswahl()
            auswahl = filter
        } label: {
            Text(filter.anzeigename)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(gewaehlt ? Color.black : .white)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(gewaehlt ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.black.opacity(0.35)), in: .capsule)
        }
        .accessibilityLabel(filter.anzeigename)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}

/// "Memories": the library button left of the shutter (system picker, loads nothing until tapped).
struct KameraMemoriesKnopf: View {
    let laedt: Bool

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if laedt {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "photo.stack")
                }
            }
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            Text("Memories")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memories, Foto oder Video aus der Galerie")
    }
}

/// Shutter look only; the gestures stay on `SnapKameraView`.
struct KameraAusloeserBild: View {
    let fortschritt: Double

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.4), lineWidth: 4).frame(width: 76, height: 76)
            Circle()
                .trim(from: 0, to: fortschritt)
                .stroke(Color.loveaRose, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(-90))
            Circle().fill(.white).frame(width: 62, height: 62)
        }
        .contentShape(Circle())
    }
}
