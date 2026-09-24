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

    /// Text after the name per `art`; mirrored by `server/regeln.js AUFNAHME_TEXT` for the push.
    /// Unknown values (and the snap's own "screenshot") read "hat einen Screenshot gemacht".
    static let texte: [String: String] = [
        "bildschirmaufnahme": "hat den Bildschirm aufgenommen",
        chatScreenshot: "hat einen Screenshot vom Chat gemacht",
        chatAufnahme: "nimmt den Chat auf",
        gespeichertFoto: "hat ein Bild in Aufnahmen gespeichert",
        gespeichertVideo: "hat ein Video in Aufnahmen gespeichert",
        "profilScreenshot": "hat einen Screenshot von deinem Profil gemacht",
        "profilAufnahme": "nimmt dein Profil auf",
        "stickerScreenshot": "hat einen Screenshot von einem Sticker gemacht",
        "stickerAufnahme": "nimmt einen Sticker auf",
        "fotoScreenshot": "hat einen Screenshot von deinem Foto gemacht",
        "fotoAufnahme": "nimmt dein Foto auf",
        "videoScreenshot": "hat einen Screenshot von deinem Video gemacht",
        "videoAufnahme": "nimmt dein Video auf",
        "chatFotoScreenshot": "hat einen Screenshot von einem Foto im Chat gemacht",
        "chatFotoAufnahme": "nimmt ein Foto im Chat auf",
        "chatVideoScreenshot": "hat einen Screenshot von einem Video im Chat gemacht",
        "chatVideoAufnahme": "nimmt ein Video im Chat auf",
    ]

    /// `snap.wiederholt`: "Annika hat den Snap wiederholt" / "… 2-mal wiederholt".
    static func wiederholtText(von name: String, anzahl: Int) -> String {
        anzahl > 1 ? "\(name) hat den Snap \(anzahl)-mal wiederholt" : "\(name) hat den Snap wiederholt"
    }

    static func text(von name: String, art: String) -> String {
        "\(name) \(texte[art] ?? "hat einen Screenshot gemacht")"
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

/// What is on screen for screenshot/recording notices. Views register while visible
/// (`.screenshotKontext(_:)`); the most specific registered one wins. Nothing registered (Home,
/// Health, Karte, Zeichnen, own profile) → no notice. The snap viewer sends its own notices.
enum ScreenshotKontext: Equatable, Sendable {
    case chat, partnerProfil, sticker
    /// Photo or video opened big; `eigen` = the screenshotter's own medium.
    case medium(video: Bool, eigen: Bool)

    private var rang: Int {
        switch self {
        case .chat: 1
        case .partnerProfil: 2
        case .sticker: 3
        case .medium: 4
        }
    }

    /// The most specific visible context.
    static func aktiv(_ sichtbar: [ScreenshotKontext]) -> ScreenshotKontext? {
        sichtbar.max { $0.rang < $1.rang }
    }

    /// The `snap.aufnahme` art for a screenshot or a starting recording in this context.
    func art(aufnahme: Bool) -> String {
        let basis: String
        switch self {
        case .chat: basis = "chat"
        case .partnerProfil: basis = "profil"
        case .sticker: basis = "sticker"
        case .medium(let video, let eigen):
            basis = eigen ? (video ? "chatVideo" : "chatFoto") : (video ? "video" : "foto")
        }
        return basis + (aufnahme ? "Aufnahme" : "Screenshot")
    }
}

extension View {
    /// Registers `kontext` for screenshot notices while this view is on screen.
    func screenshotKontext(_ kontext: ScreenshotKontext) -> some View {
        onAppear { AppNavigation.shared.bildschirm.append(kontext) }
            .onDisappear {
                if let index = AppNavigation.shared.bildschirm.lastIndex(of: kontext) { AppNavigation.shared.bildschirm.remove(at: index) }
            }
    }
}

/// App-wide listener (on `AppRootView`): a screenshot or the start of a screen recording while a
/// registered context is visible sends one notice, at most one per 10 s.
struct ChatAufnahmeHinweise: ViewModifier {
    @State private var letzte: Date?
    @State private var nimmtAuf = false
    @Environment(\.scenePhase) private var scenePhase

    private var aktiv: ScreenshotKontext? { ScreenshotKontext.aktiv(AppNavigation.shared.bildschirm) }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                melden(aufnahme: false)
            }
            // `sceneCaptureState` (iOS 17) replaces the deprecated `UIScreen.isCaptured`; no
            // notification exists for it in SwiftUI, so it's polled once a second while something
            // reportable is on screen.
            .task(id: aktiv != nil) {
                guard aktiv != nil else { return }
                while !Task.isCancelled {
                    let laeuft = Self.aufnahmeLaeuft
                    if laeuft, !nimmtAuf { melden(aufnahme: true) }
                    nimmtAuf = laeuft
                    try? await Task.sleep(for: .seconds(1))
                }
            }
    }

    private static var aufnahmeLaeuft: Bool {
        UIApplication.shared.connectedScenes.contains { ($0 as? UIWindowScene)?.traitCollection.sceneCaptureState == .active }
    }

    private func melden(aufnahme: Bool) {
        guard let aktiv, scenePhase == .active, ChatHinweis.darfMelden(letzte: letzte, jetzt: Date()) else { return }
        letzte = Date()
        ChatModell.shared.snapAufnahmeSenden("chat", art: aktiv.art(aufnahme: aufnahme))
    }
}
