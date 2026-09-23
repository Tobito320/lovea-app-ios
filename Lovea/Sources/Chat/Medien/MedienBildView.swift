import AVKit
import SwiftUI
import UIKit

/// Photo/video bubble content (Z-5.1): "wird geladen" placeholder until the file is local, then a
/// thumbnail that opens a fullscreen zoomable/playable viewer. Long-press on a photo offers
/// "In Galerie speichern" (Z-5.5).
struct MedienNachrichtView: View {
    let medium: ChatModell.MedienEintrag
    let eigene: Bool

    @State private var localURL: URL?
    @State private var vollbild = false

    var body: some View {
        Group {
            if let localURL {
                Button { vollbild = true } label: {
                    MedienVorschau(url: localURL, istVideo: medium.typ == "video")
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if medium.typ == "foto" {
                        Button("In Galerie speichern", systemImage: "photo.badge.plus") {
                            ChatGalerie.inGaleriesSpeichern(bildURL: localURL)
                        }
                    }
                }
                .fullScreenCover(isPresented: $vollbild) {
                    MedienVollbild(url: localURL, istVideo: medium.typ == "video")
                }
            } else {
                LadePlatzhalter(istVideo: medium.typ == "video")
            }
        }
        .frame(width: 220, height: medium.hoehe > 0 ? 220 * medium.hoehe / max(medium.breite, 1) : 220)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: medium.id) { await laden() }
    }

    private func laden() async {
        if eigene, let quelle = ChatMedien.eigeneQuellen[medium.id] { localURL = quelle; return }
        if let vorhanden = Medien.lokal(medium.id) { localURL = vorhanden; return }
        // Retries while the row is on screen (`.task(id:)` cancels when it scrolls away and restarts
        // when it reappears) — never caches a failed attempt as final, matches Review-Fokus #5.
        while !Task.isCancelled {
            if let geholt = try? await Medien.holen(medium.id) {
                localURL = geholt
                return
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }
}

private struct LadePlatzhalter: View {
    let istVideo: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(.thinMaterial)
            VStack(spacing: 6) {
                ProgressView()
                Text("wird geladen").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .topLeading) {
            if istVideo {
                Image(systemName: "video.fill").font(.caption).padding(6).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MedienVorschau: View {
    let url: URL
    let istVideo: Bool
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            if let bild {
                Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.thinMaterial)
            }
            if istVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
        }
        .task(id: url) {
            bild = istVideo ? await Videobild.erstesBild(url) : UIImage(contentsOfFile: url.path)
        }
    }
}

/// Fullscreen viewer (Z-5.1): pinch/drag zoom for photos, `VideoPlayer` for videos.
private struct MedienVollbild: View {
    let url: URL
    let istVideo: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var zoom = 1.0
    @State private var versatz: CGSize = .zero
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if istVideo {
                VideoPlayer(player: AVPlayer(url: url)).ignoresSafeArea()
            } else if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .offset(versatz)
                    .gesture(MagnificationGesture().onChanged { zoom = max(1, $0) })
                    .gesture(DragGesture().onChanged { if zoom > 1 { versatz = $0.translation } })
                    .onTapGesture(count: 2) { withAnimation { zoom = zoom > 1 ? 1 : 2; versatz = .zero } }
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                .font(.title2)
                .foregroundStyle(.white)
                .padding()
        }
        .task {
            if !istVideo { bild = UIImage(contentsOfFile: url.path) }
            FigurenModell.shared.zustandSenden(.init(haupt: istVideo ? .schautVideo : .schautBild))
        }
        .onDisappear { FigurenModell.shared.zustandSenden(.init(haupt: .imChat)) }
    }
}

/// First-frame thumbnail for a local video file, off the main actor.
enum Videobild {
    static func erstesBild(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

/// "In Galerie speichern" (Z-5.5): imports a received photo as a new drawing with an image layer.
@MainActor
enum ChatGalerie {
    // ponytail: a fresh `ArtworkLibrary()` pointed at its default Application Support folder — the
    // same file on disk Drawing's own `@StateObject ArtworkLibrary` uses, so this survives and shows
    // up there. That tab's already-open instance won't refresh until it re-`load()`s though — Chat
    // doesn't own Drawing/**, so this is reported instead of fixed here.
    static func inGaleriesSpeichern(bildURL: URL) {
        guard let image = UIImage(contentsOfFile: bildURL.path), let png = image.pngData() else { return }
        let library = ArtworkLibrary()
        let breite = ArtworkLibrary.clampDimension(image.size.width * image.scale)
        let hoehe = ArtworkLibrary.clampDimension(image.size.height * image.scale)
        var artwork = library.createArtwork(name: "Aus dem Chat", projectID: nil, format: .custom, customWidth: breite, customHeight: hoehe, background: .white)
        let bildEbene = ArtworkLayer.image(name: "Bild")
        artwork.layers.append(bildEbene)
        library.saveLayerData(png, layer: bildEbene, artworkID: artwork.id)
        library.saveDocument(artwork)
    }
}
