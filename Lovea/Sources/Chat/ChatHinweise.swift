import Combine
import Photos
import SwiftUI
import UIKit

/// Fix round 3: grey system lines for saving to Photos, screenshots and screen recordings of the
/// chat. They reuse `snap.aufnahme {id, art}`: the fold turns each op into one centred line (keyed
/// by op id), like Snapchat. Older builds show unknown `art` values as "hat einen Screenshot gemacht".
enum ChatHinweis {
    static let chatScreenshot = "chatScreenshot"
    static let chatAufnahme = "chatAufnahme"
    static let gespeichertFoto = "gespeichertFoto"
    static let gespeichertVideo = "gespeichertVideo"

    static func text(von name: String, art: String) -> String {
        switch art {
        case "bildschirmaufnahme": "\(name) hat den Bildschirm aufgenommen"
        case chatScreenshot: "\(name) hat einen Screenshot vom Chat gemacht"
        case chatAufnahme: "\(name) nimmt den Chat auf"
        case gespeichertFoto: "\(name) hat ein Bild in Aufnahmen gespeichert"
        case gespeichertVideo: "\(name) hat ein Video in Aufnahmen gespeichert"
        default: "\(name) hat einen Screenshot gemacht"
        }
    }

    /// Screenshot and recording notices: at most one per `abstand` seconds.
    static func darfMelden(letzte: Date?, jetzt: Date, abstand: TimeInterval = 10) -> Bool {
        guard let letzte else { return true }
        return jetzt.timeIntervalSince(letzte) >= abstand
    }
}

/// "In Aufnahmen speichern": photos and videos into the Photos library with add-only permission.
@MainActor
enum AufnahmenSpeichern {
    enum Fehler: Error { case keineErlaubnis, nichtGeladen }

    static func speichern(_ medien: [ChatModell.MedienEintrag]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Fehler.keineErlaubnis }
        for medium in medien where medium.typ == "foto" || medium.typ == "video" {
            var gefunden = MedienDatei.lokal(medium)
            if gefunden == nil { gefunden = try? await Medien.holen(medium.id) }
            guard let quelle = gefunden else { throw Fehler.nichtGeladen }
            if medium.typ == "video" {
                // Cached media have no file extension; PhotoKit needs one to read a video file.
                let kopie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                try FileManager.default.copyItem(at: quelle, to: kopie)
                defer { try? FileManager.default.removeItem(at: kopie) }
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: kopie, options: nil)
                }
            } else {
                // As data: the photo's type is read from its bytes, not from the (missing) extension.
                let daten = try await Task.detached(priority: .userInitiated) { try Data(contentsOf: quelle) }.value
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset().addResource(with: .photo, data: daten, options: nil)
                }
            }
        }
    }
}

/// While the conversation is on screen and the app active: a screenshot or the start of a screen
/// recording sends one notice, at most one per 10 s.
struct ChatAufnahmeHinweise: ViewModifier {
    @State private var sichtbar = false
    @State private var letzte: Date?
    @State private var nimmtAuf = false
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { sichtbar = true }
            .onDisappear { sichtbar = false }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                melden(ChatHinweis.chatScreenshot)
            }
            // `sceneCaptureState` (iOS 17) replaces the deprecated `UIScreen.isCaptured`; no
            // notification exists for it in SwiftUI, so it's polled once a second while visible.
            .task(id: sichtbar) {
                guard sichtbar else { return }
                while !Task.isCancelled {
                    let laeuft = Self.aufnahmeLaeuft
                    if laeuft, !nimmtAuf { melden(ChatHinweis.chatAufnahme) }
                    nimmtAuf = laeuft
                    try? await Task.sleep(for: .seconds(1))
                }
            }
    }

    private static var aufnahmeLaeuft: Bool {
        UIApplication.shared.connectedScenes.contains { ($0 as? UIWindowScene)?.traitCollection.sceneCaptureState == .active }
    }

    private func melden(_ art: String) {
        guard sichtbar, scenePhase == .active, ChatHinweis.darfMelden(letzte: letzte, jetzt: Date()) else { return }
        letzte = Date()
        ChatModell.shared.snapAufnahmeSenden("chat", art: art)
    }
}
