import AVKit
import Combine
import SwiftUI
import UIKit

/// Fullscreen snap viewer (Z-6.3, Z-6.4): tap or swipe down to close. Nothing sits on the picture
/// except the three-dot menu top right (save in chat, save to Photos, close). Only the recipient's very
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
    @State private var hinweis: String?
    /// Interaktives Runterziehen (wie `MedienVollbild.ziehGeste`): folgt dem Finger statt beim
    /// Loslassen hart zuzuschnappen — 120pt-Schwellwert wie dort, jetzt mit Rückfeder statt hartem Schnitt.
    @State private var zieh: CGFloat = 0

    private var binEmpfaenger: Bool { nachricht.von != ich }
    /// Live statt der beim Öffnen übergebenen Kopie — der Umschalt-Button soll sofort umspringen,
    /// auch wenn die Nachricht als Wert-Typ nur einmal in diese View hineinkopiert wurde.
    private var aktuell: ChatModell.Nachricht { ChatModell.shared.nachricht(nachricht.id) ?? nachricht }
    private var istVideo: Bool { nachricht.medien.first?.typ == "video" }

    var body: some View {
        ZStack {
            Color.black.opacity(1 - min(zieh / 400, 0.6)).ignoresSafeArea()
            Group {
                if let spieler {
                    // `.allowsHitTesting(false)` — otherwise `VideoPlayer`'s own controls swallow the
                    // tap this view uses to dismiss, and a first tap just pauses/plays instead.
                    VideoPlayer(player: spieler).ignoresSafeArea().allowsHitTesting(false)
                } else if let bild {
                    Image(uiImage: bild).resizable().scaledToFit()
                } else {
                    ladeAnzeige
                }
            }
            .offset(y: zieh)
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
        .gesture(ziehGeste)
        .overlay(alignment: .topTrailing) { menueKnopf.opacity(zieh > 0 ? 0 : 1) }
        .overlay(alignment: .bottom) { hinweisEbene.opacity(zieh > 0 ? 0 : 1) }
        .task { await laden() }
        .onAppear { FigurenModell.shared.zustandSenden(.init(haupt: istVideo ? .schautVideo : .schautBild)) }
        .onDisappear {
            FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
            // Nicht nur über `schliessen()`: die Zoom-Transition erlaubt jetzt auch das System-eigene
            // Wegwischen (`.navigationTransition(.zoom)`), das `schliessen()` nie durchläuft — das
            // "angesehen" muss trotzdem raus, egal wodurch der Viewer verschwindet.
            if binEmpfaenger, !nachricht.snapAngesehen, let begonnen {
                let sekunden = Date().timeIntervalSince(begonnen)
                ChatModell.shared.snapAngesehenSenden(nachricht.id, lange: sekunden >= 120)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            aufnahmeMelden(art: "screenshot")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            bildschirmaufnahmePruefen()
        }
        .onAppear { bildschirmaufnahmePruefen() }
    }

    /// Spinner, solange nichts lokal ist; läuft ein Download (oder wartet er auf den Absender), steht
    /// stattdessen der ehrliche Stand da.
    @ViewBuilder private var ladeAnzeige: some View {
        if FortschrittsStand.shared.stand(nachricht.medien.first?.id ?? "") != nil {
            FortschrittsAnzeige(medienId: nachricht.medien.first?.id ?? "")
        } else {
            ProgressView().tint(.white)
        }
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
            if let geholt = try? await MedienUebertragung.holen(medium.id) {
                await anzeigen(geholt)
                return
            }
            // 1s, nicht 2s (PR #14 hat `MedienDatei.url` aus demselben Grund schon auf 1s gesenkt):
            // die Nachricht kommt an, bevor der Upload fertig ist, 2s hier hieß der Snap stand bis
            // zu 2s länger als nötig auf "lädt".
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func anzeigen(_ url: URL) async {
        if istVideo {
            let player = AVPlayer(url: Videobild.abspielbar(url))
            spieler = player
            player.play()
        } else {
            bild = await Bilddatei.laden(url) // decoded off the main actor (Z-16.2)
        }
        begonnen = Date() // only once it's actually on screen
        // Snaps replay without limit; each reopening of an already viewed one tells the sender.
        if binEmpfaenger, nachricht.snapAngesehen { ChatModell.shared.snapWiederholtSenden(nachricht.id) }
    }

    /// Folgt dem Finger nach unten; ab 120pt (wie `MedienVollbild`) schließt es, sonst federt es zurück.
    private var ziehGeste: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { wert in
                guard wert.translation.height > 0, wert.translation.height > abs(wert.translation.width) else { return }
                zieh = wert.translation.height
            }
            .onEnded { _ in
                if zieh > 120 {
                    schliessen()
                } else {
                    withAnimation(Feder.schnell) { zieh = 0 }
                }
            }
    }

    private func schliessen() {
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

    /// `UIScreen.main.isCaptured` is the documented way to detect screen recording; checked once on
    /// open and whenever `capturedDidChangeNotification` fires (no polling timer, Akku).
    private func bildschirmaufnahmePruefen() {
        if UIScreen.main.isCaptured { aufnahmeMelden(art: "bildschirmaufnahme") }
    }

    /// Drei-Punkte-Menü oben rechts, wie in der Vorlage: die einzige Bedienung auf dem Bild.
    @ViewBuilder private var menueKnopf: some View {
        if bild != nil || spieler != nil {
            Menu {
                Button { imChatSpeichernUmschalten() } label: {
                    Label(aktuell.snapGespeichert ? "Nicht mehr im Chat speichern" : "Im Chat speichern",
                          systemImage: aktuell.snapGespeichert ? "bookmark.slash" : "bookmark")
                }
                Button { Task { await inAufnahmenSpeichern() } } label: {
                    Label("In Aufnahmen speichern", systemImage: "square.and.arrow.down")
                }
                Button { schliessen() } label: { Label("Schließen", systemImage: "xmark") }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 3)
                    .frame(width: 48, height: 48)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Mehr")
            .padding(.trailing, 6)
        }
    }

    @ViewBuilder private var hinweisEbene: some View {
        if let hinweis {
            Text(hinweis)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: hinweis) {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(Feder.weich) { self.hinweis = nil }
                }
        }
    }

    private func inAufnahmenSpeichern() async {
        guard let medium = nachricht.medien.first else { return }
        do {
            try await AufnahmenSpeichern.speichern([medium])
            Haptik.erfolg()
            withAnimation(Feder.weich) { hinweis = "In Aufnahmen gespeichert" }
        } catch AufnahmenSpeichern.Fehler.keineErlaubnis {
            Haptik.warnung()
            withAnimation(Feder.weich) { hinweis = "Keine Erlaubnis für Fotos. Bitte in den Einstellungen erlauben." }
        } catch {
            Haptik.warnung()
            withAnimation(Feder.weich) { hinweis = "Speichern hat nicht geklappt" }
        }
    }

    /// "Im Chat speichern" (Snapchat-Toggle): bleibt als echtes Foto/Video im Chat stehen, erneut
    /// ansehbar, und wird über `snap.gespeichert` (`ChatModell`) bei beiden Seiten synchronisiert.
    /// Gegenstück "In Aufnahmen speichern" (Fotos-App) lebt weiter im Lang-Druck-Menü (`NachrichtFokus`).
    private func imChatSpeichernUmschalten() {
        let neu = !aktuell.snapGespeichert
        ChatModell.shared.snapGespeichertSenden(nachricht.id, an: neu)
        Haptik.erfolg()
        withAnimation(Feder.weich) { hinweis = neu ? "Im Chat gespeichert" : "Nicht mehr im Chat gespeichert" }
    }
}
