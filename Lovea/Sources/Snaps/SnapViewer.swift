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
    @State private var spieler: AVPlayer?
    /// Set only once the medium actually finished loading (not on open) — `schliessen()` uses this
    /// both to time `lange` correctly and to never mark a snap "angesehen" that never rendered.
    @State private var begonnen: Date?
    @State private var gemeldeteAufnahmeArten: Set<String> = []

    private var binEmpfaenger: Bool { nachricht.von != ich }
    private var istVideo: Bool { nachricht.medien.first?.typ == "video" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let spieler {
                // `.allowsHitTesting(false)` — otherwise `VideoPlayer`'s own controls swallow the
                // tap this view uses to dismiss, and a first tap just pauses/plays instead.
                VideoPlayer(player: spieler).ignoresSafeArea().allowsHitTesting(false)
            } else if let bild {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { schliessen() }
        // VoiceOver (Z-16.3): one element, activate or scrub (escape) to close.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(istVideo ? "Video-Snap von \(nachricht.von.name)" : "Foto-Snap von \(nachricht.von.name)")
        .accessibilityHint("Tippen zum Schließen")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { schliessen() }
        .accessibilityAction(.escape) { schliessen() }
        .gesture(DragGesture().onEnded { wert in if wert.translation.height > 60 { schliessen() } })
        .task { await laden() }
        .onAppear { FigurenModell.shared.zustandSenden(.init(haupt: istVideo ? .schautVideo : .schautBild)) }
        .onDisappear { FigurenModell.shared.zustandSenden(.init(haupt: .imChat)) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            aufnahmeMelden(art: "screenshot")
        }
        .task { await bildschirmaufnahmeUeberwachen() }
    }

    /// The sender may still be uploading when this opens (Review-Fokus #5) — retries instead of
    /// giving up after one miss, same pattern as `MedienNachrichtView.laden()`.
    private func laden() async {
        guard let medium = nachricht.medien.first else { return }
        if let quelle = ChatMedien.eigeneQuellen[medium.id] ?? Medien.lokal(medium.id) {
            await anzeigen(quelle)
            return
        }
        while !Task.isCancelled {
            if let geholt = try? await Medien.holen(medium.id) {
                await anzeigen(geholt)
                return
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func anzeigen(_ url: URL) async {
        if istVideo {
            let player = AVPlayer(url: url)
            spieler = player
            player.play()
        } else {
            bild = await Bilddatei.laden(url) // decoded off the main actor (Z-16.2)
        }
        begonnen = Date() // only once it's actually on screen
        // Snaps replay without limit; each reopening of an already viewed one tells the sender.
        if binEmpfaenger, nachricht.snapAngesehen { ChatModell.shared.snapWiederholtSenden(nachricht.id) }
    }

    private func schliessen() {
        if binEmpfaenger, !nachricht.snapAngesehen, let begonnen {
            let sekunden = Date().timeIntervalSince(begonnen)
            ChatModell.shared.snapAngesehenSenden(nachricht.id, lange: sekunden >= 120)
        }
        dismiss()
    }

    private func aufnahmeMelden(art: String) {
        // Spec 6: the notice is for the sender ("X hat einen Screenshot gemacht") — the sender
        // previewing their own still-unviewed snap and screenshotting it is not that.
        guard binEmpfaenger else { return }
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
