import LinkPresentation
import SwiftUI
import UIKit

/// One bubble (Z-4.2, Z-4.3, Z-5.1–Z-5.3, Z-6.3, Block 18). Gestures: swipe right to reply (haptic
/// at the threshold), swipe left to peek at the time, double tap for ❤️, long press for the menu
/// with a reaction row on top. A photo stack (several photo messages in a row) renders as `FotoStapel`.
struct ChatNachrichtRow: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    /// Every message of this row's photo stack (first == `nachricht`); just `[nachricht]` otherwise.
    var stapel: [ChatModell.Nachricht] = []
    let zeigeDatumstrenner: Bool
    let zeigeZeitstempel: Bool
    let zustellStatus: String?
    let onAntworten: (ChatModell.Nachricht) -> Void
    let onBearbeiten: (ChatModell.Nachricht) -> Void
    let onLoeschen: ([String]) -> Void
    let onSpringeZu: (String) -> Void

    @State private var wischOffset: CGFloat = 0
    @State private var herzSichtbar = false

    static let emojis = ["❤️", "😂", "👍", "😮", "😢", "🙏"]
    private static let antwortSchwelle: CGFloat = 56

    private var eigene: Bool { nachricht.von == ich }
    private var alleMedien: [ChatModell.MedienEintrag] { stapel.count > 1 ? stapel.flatMap(\.medien) : nachricht.medien }
    private var istStapel: Bool { ChatStapel.istBild(nachricht) && alleMedien.count > 1 }

    var body: some View {
        if let einladung = nachricht.einladung {
            ZeichnungEinladungZeile(zeichnungId: einladung.zeichnungId, name: einladung.name, von: nachricht.von, ich: ich)
        } else {
            zeile
        }
    }

    private var zeile: some View {
        VStack(alignment: .center, spacing: 4) {
            if zeigeDatumstrenner {
                Text(nachricht.zeit.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            if zeigeZeitstempel {
                Text(nachricht.zeit.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack {
                if eigene { Spacer(minLength: 40) }
                VStack(alignment: eigene ? .trailing : .leading, spacing: 3) {
                    if let antwortAuf = nachricht.antwortAuf {
                        Button { onSpringeZu(antwortAuf) } label: {
                            Label("Antwort", systemImage: "arrowshape.turn.up.left.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    blase
                        .overlay {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.red)
                                .shadow(color: .black.opacity(0.25), radius: 4)
                                .scaleEffect(herzSichtbar ? 1 : 0.3)
                                .opacity(herzSichtbar ? 1 : 0)
                                .allowsHitTesting(false)
                        }
                        .onTapGesture(count: 2) { herzReaktion() }
                        .contextMenu { kontextMenu }

                    if !nachricht.reaktionen.isEmpty {
                        Text(nachricht.reaktionen.values.joined())
                            .font(.caption)
                            .padding(4)
                            // Solid, not material: no blur on content (Masterplan §10).
                            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                            .accessibilityLabel("Reaktionen: " + nachricht.reaktionen.map { "\($0.value) von \($0.key == ich ? "dir" : $0.key.name)" }.joined(separator: ", "))
                    }

                    if let zustellStatus {
                        Text(zustellStatus).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if !eigene { Spacer(minLength: 40) }
            }
            .offset(x: wischOffset)
            // Revealed behind the moving bubble: reply arrow on the left, time on the right.
            .background(alignment: .leading) {
                Image(systemName: "arrowshape.turn.up.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.loveaRose)
                    .scaleEffect(wischOffset >= Self.antwortSchwelle ? 1.15 : 0.8)
                    .opacity(Double(max(wischOffset, 0) / Self.antwortSchwelle))
                    .animation(.snappy(duration: 0.15), value: wischOffset >= Self.antwortSchwelle)
                    .accessibilityHidden(true)
            }
            .background(alignment: .trailing) {
                Text(nachricht.zeit.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
                    .opacity(Double(max(-wischOffset, 0) / 50))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        // `.simultaneousGesture` (not `.gesture`) so this never steals the ScrollView's vertical
        // pan; the width-vs-height check keeps it from reacting to an ordinary vertical scroll touch.
        .simultaneousGesture(wischGeste)
        .accessibilityAction(named: "Antworten") { onAntworten(nachricht) }
    }

    private var wischGeste: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { wert in
                // Leave the left screen edge to the system back swipe.
                guard wert.startLocation.x > 30, abs(wert.translation.width) > abs(wert.translation.height) else { return }
                let breite = wert.translation.width
                let neu = breite > 0 ? min(breite * 0.8, 84) : max(breite * 0.8, -64)
                if wischOffset < Self.antwortSchwelle, neu >= Self.antwortSchwelle { ChatHaptik.mittel() }
                wischOffset = neu
            }
            .onEnded { _ in
                if wischOffset >= Self.antwortSchwelle { onAntworten(nachricht) }
                withAnimation(.spring(duration: 0.3)) { wischOffset = 0 }
            }
    }

    private func herzReaktion() {
        guard !nachricht.geloescht else { return }
        let neu: String? = nachricht.reaktionen[ich] == "❤️" ? nil : "❤️"
        ChatModell.shared.reagieren(nachricht.id, emoji: neu)
        ChatHaptik.mittel()
        guard neu != nil else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { herzSichtbar = true }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.25)) { herzSichtbar = false }
        }
    }

    @ViewBuilder private var blase: some View {
        if nachricht.geloescht {
            Text("Nachricht gelöscht")
                .italic()
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        } else if istStapel {
            FotoStapel(medien: alleMedien, eigene: eigene)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // A snap is never rendered via the plain medium path (view-once).
                if let snap = nachricht.snap {
                    SnapZeile(nachricht: nachricht, snap: snap, ich: ich, eigene: eigene, onAntworten: onAntworten)
                } else if let medium = nachricht.medien.first {
                    if medium.typ == "sprache" {
                        SprachBlase(medium: medium)
                    } else {
                        MedienNachrichtView(medium: medium, eigene: eigene)
                    }
                }
                if let gif = nachricht.gif, let url = URL(string: gif.url) {
                    AnimiertesGif(url: url)
                        .frame(width: 180, height: gif.breite > 0 && gif.hoehe > 0 ? 180 * gif.hoehe / gif.breite : 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if let sticker = nachricht.sticker {
                    StickerKachel(medienId: sticker.medienId).frame(width: 140, height: 140)
                }
                if let text = nachricht.text, !text.isEmpty {
                    // Who wrote it is otherwise only color and side (Z-16.3).
                    Text(text).accessibilityLabel("\(eigene ? "Du" : nachricht.von.name): \(text)")
                    if let url = ersterLink(in: text) {
                        LinkVorschau(url: url)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                if let platzhalter {
                    HStack(spacing: 4) {
                        Image(systemName: platzhalter.symbol)
                        Text(platzhalter.text)
                    }
                    .font(.subheadline)
                }
                if nachricht.bearbeitet {
                    Text("bearbeitet").font(.caption2)
                }
            }
            .padding(10)
            .foregroundStyle(Color.personText(nachricht.von))
            .background(Color.person(nachricht.von), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    /// `system` stays text-only; `spiel` rows are `SpielKarte` in the list, this is only a fallback.
    private var platzhalter: (text: String, symbol: String)? {
        if nachricht.spiel != nil { return ("Spiel", "gamecontroller.fill") }
        if let system = nachricht.system { return (system, "info.circle") }
        return nil
    }

    private var reaktion: Binding<String> {
        Binding(
            get: { nachricht.reaktionen[ich] ?? "" },
            set: { neu in
                ChatHaptik.leicht()
                ChatModell.shared.reagieren(nachricht.id, emoji: neu.isEmpty ? nil : neu)
            }
        )
    }

    @ViewBuilder private var kontextMenu: some View {
        if !nachricht.geloescht {
            // Reaction row on top of the menu, like iMessage/Instagram (Spec 5.2).
            Picker("Reagieren", selection: reaktion) {
                ForEach(Self.emojis, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.palette)
            if nachricht.reaktionen[ich] != nil {
                Button("Reaktion entfernen", systemImage: "heart.slash") { ChatModell.shared.reagieren(nachricht.id, emoji: nil) }
            }
        }
        Button("Antworten", systemImage: "arrowshape.turn.up.left") { onAntworten(nachricht) }
        if eigene, !nachricht.geloescht, !(nachricht.text ?? "").isEmpty {
            Button("Bearbeiten", systemImage: "pencil") { onBearbeiten(nachricht) }
        }
        if let text = nachricht.text, !text.isEmpty {
            Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
        }
        if nachricht.snap == nil, !nachricht.geloescht, !lokaleFotos.isEmpty {
            Button(lokaleFotos.count > 1 ? "Alle in Galerie speichern" : "In Galerie speichern", systemImage: "photo.badge.plus") {
                for url in lokaleFotos { ChatGalerie.inGaleriesSpeichern(bildURL: url) }
                ChatHaptik.leicht()
            }
        }
        Menu("Anheften", systemImage: "pin") {
            Button("Für immer") { ChatModell.shared.anheften(nachricht.id, bis: nil) }
            Button("Bis morgen") { ChatModell.shared.anheften(nachricht.id, bis: naechsteBerlinMitternacht()) }
            Button("1 Woche") { ChatModell.shared.anheften(nachricht.id, bis: Date().addingTimeInterval(7 * 86_400)) }
        }
        if nachricht.angeheftet {
            Button("Lösen", systemImage: "pin.slash") { ChatModell.shared.loesen(nachricht.id) }
        }
        Button {
            ChatModell.shared.sternSetzen(nachricht.id, an: !nachricht.gesternt.contains(ich))
        } label: {
            Label(nachricht.gesternt.contains(ich) ? "Stern entfernen" : "Stern", systemImage: nachricht.gesternt.contains(ich) ? "star.slash" : "star")
        }
        if eigene {
            Button(eigeneIDs.count > 1 ? "Alle löschen" : "Löschen", systemImage: "trash", role: .destructive) { onLoeschen(eigeneIDs) }
        }
    }

    private var lokaleFotos: [URL] { alleMedien.filter { $0.typ == "foto" }.compactMap { MedienDatei.lokal($0) } }
    private var eigeneIDs: [String] { (stapel.isEmpty ? [nachricht] : stapel).filter { $0.von == ich }.map(\.id) }

    private func naechsteBerlinMitternacht() -> Date {
        Calendar.berlin.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(86_400)
    }
}

/// The snap row (Z-6.3): before viewing, a tappable "Snap" bubble; after, a text-only spur
/// ("Snap angesehen"/"Snap lange angesehen") unless `bleibt` or saved — those show the real photo
/// like any other medium. Long-press on the spur offers "Erneut ansehen" (no new op — the viewer
/// only sends `snap.angesehen` once) and "Speichern".
private struct SnapZeile: View {
    let nachricht: ChatModell.Nachricht
    let snap: ChatModell.SnapInfo
    let ich: Person
    let eigene: Bool
    let onAntworten: (ChatModell.Nachricht) -> Void

    @State private var vollbild = false

    // `bleibt` only stops the snap from collapsing into a spur *after* it's been viewed once — a
    // still-unviewed `bleibt` snap goes through the fullscreen viewer like any other (Spec 6),
    // `snap.angesehen` still has to fire. `snapGespeichert`, by contrast, is a photo immediately.
    private var alsFoto: Bool { nachricht.snapGespeichert || (snap.bleibt && nachricht.snapAngesehen) }

    var body: some View {
        Group {
            if alsFoto, let medium = nachricht.medien.first {
                MedienNachrichtView(medium: medium, eigene: eigene)
            } else if nachricht.snapAngesehen {
                spur(nachricht.snapLange ? "Snap lange angesehen" : "Snap angesehen")
                    .contextMenu {
                        Button("Antworten", systemImage: "arrowshape.turn.up.left") { onAntworten(nachricht) }
                        Button("Erneut ansehen", systemImage: "arrow.clockwise") { vollbild = true }
                        Button("Speichern", systemImage: "square.and.arrow.down") {
                            ChatModell.shared.snapGespeichertSenden(nachricht.id)
                        }
                    }
            } else {
                spur(eigene ? "Snap" : "Snap ansehen")
            }
        }
        .fullScreenCover(isPresented: $vollbild) {
            SnapViewer(nachricht: nachricht, ich: ich)
        }
    }

    private func spur(_ text: String) -> some View {
        Button { ChatHaptik.leicht(); vollbild = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Text(text)
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
    }
}

/// `LPLinkView` wrapper for `Z-4.2`'s link preview.
// ponytail: shows the bare `LPLinkView(url:)` card (no title/thumbnail) rather than fetching rich
// `LPLinkMetadata` — `LPMetadataProvider`'s completion hands back a non-Sendable link view across
// an arbitrary queue, which is a real Swift 6 strict-concurrency risk with no local compiler to
// check it against. Upgrade: fetch metadata through a `Coordinator` once confirmed safe on iOS 26.
private struct LinkVorschau: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LPLinkView { LPLinkView(url: url) }
    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}
