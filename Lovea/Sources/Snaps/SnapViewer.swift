import AVKit
import Combine
import SwiftUI
import UIKit

/// Fullscreen snap viewer (Z-6.3, Z-6.4): tap or swipe down to close. Only the recipient's very
/// first open sends `snap.angesehen` (`lange` from 2 minutes on screen); "Erneut ansehen" reopens
/// this same view without resending it. A screenshot or screen recording while open sends
/// `snap.aufnahme`, attributed to whoever is looking right now (`ich`), never the original sender.
struct SnapViewer: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person

    @Environment(\.dismiss) private var dismiss
    @State private var bild: UIImage?
    @State private var localVideoURL: URL?
    @State private var begonnen = Date()
    @State private var gemeldeteAufnahmeArten: Set<String> = []

    private var binEmpfaenger: Bool { nachricht.von != ich }
    private var istVideo: Bool { nachricht.medien.first?.typ == "video" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if istVideo, let localVideoURL {
                VideoPlayer(player: AVPlayer(url: localVideoURL)).ignoresSafeArea()
            } else if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { schliessen() }
        .gesture(DragGesture().onEnded { wert in if wert.translation.height > 60 { schliessen() } })
        .task { begonnen = Date(); await laden() }
        .onAppear { FigurenModell.shared.zustandSenden(.init(haupt: istVideo ? .schautVideo : .schautBild)) }
        .onDisappear { FigurenModell.shared.zustandSenden(.init(haupt: .imChat)) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            aufnahmeMelden(art: "screenshot")
        }
        .task { await bildschirmaufnahmeUeberwachen() }
    }

    private func laden() async {
        guard let medium = nachricht.medien.first else { return }
        let url = ChatMedien.eigeneQuellen[medium.id] ?? Medien.lokal(medium.id) ?? (try? await Medien.holen(medium.id))
        if istVideo {
            localVideoURL = url
        } else {
            bild = url.flatMap { UIImage(contentsOfFile: $0.path) }
        }
    }

    private func schliessen() {
        if binEmpfaenger, !nachricht.snapAngesehen {
            let sekunden = Date().timeIntervalSince(begonnen)
            ChatModell.shared.snapAngesehenSenden(nachricht.id, lange: sekunden >= 120)
        }
        dismiss()
    }

    private func aufnahmeMelden(art: String) {
        // ponytail: at most one `snap.aufnahme` per type per viewing (not one per screenshot) —
        // enough to notify without spamming the chat if someone mashes the screenshot shortcut.
        guard gemeldeteAufnahmeArten.insert(art).inserted else { return }
        ChatModell.shared.snapAufnahmeSenden(nachricht.id, art: art)
    }

    /// No notification exists for screen recording — `UIScreen.main.isCaptured` is the documented
    /// way to detect it, polled while the viewer is open.
    private func bildschirmaufnahmeUeberwachen() async {
        while !Task.isCancelled {
            if UIScreen.main.isCaptured { aufnahmeMelden(art: "bildschirmaufnahme") }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
