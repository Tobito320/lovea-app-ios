import LinkPresentation
import SwiftUI
import UIKit

/// One bubble (Z-4.2, Z-4.3, Z-5.1–Z-5.3, Z-6.3). Renders `text`, `medien` (photo/video/voice),
/// `gif`, `sticker` and `snap` for real; `spiel` still shows a neutral placeholder row (Block 14).
struct ChatNachrichtRow: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    let zeigeDatumstrenner: Bool
    let zeigeZeitstempel: Bool
    let zustellStatus: String?
    let onAntworten: (ChatModell.Nachricht) -> Void
    let onBearbeiten: (ChatModell.Nachricht) -> Void
    let onLoeschen: (String) -> Void
    let onSpringeZu: (String) -> Void

    @State private var wischOffset: CGFloat = 0
    @State private var zeigeReaktionen = false

    private var eigene: Bool { nachricht.von == ich }

    var body: some View {
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

                    if !nachricht.reaktionen.isEmpty {
                        Text(nachricht.reaktionen.values.joined())
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: Capsule())
                    }

                    if let zustellStatus {
                        Text(zustellStatus).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if !eigene { Spacer(minLength: 40) }
            }
        }
        .padding(.horizontal, 12)
        .offset(x: wischOffset)
        // `.simultaneousGesture` (not `.gesture`) so this never steals the ScrollView's vertical
        // pan; the width-vs-height check keeps it from reacting to an ordinary vertical scroll touch.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard value.translation.width > 0, value.translation.width > abs(value.translation.height) else { return }
                    wischOffset = min(value.translation.width, 70)
                }
                .onEnded { value in
                    if wischOffset > 50 { onAntworten(nachricht) }
                    withAnimation(.spring(duration: 0.25)) { wischOffset = 0 }
                }
        )
        .onTapGesture(count: 2) { zeigeReaktionen = true }
        .popover(isPresented: $zeigeReaktionen) {
            ReaktionsAuswahl(aktuell: nachricht.reaktionen[ich]) { emoji in
                ChatModell.shared.reagieren(nachricht.id, emoji: emoji)
                zeigeReaktionen = false
            }
            .presentationCompactAdaptation(.popover)
        }
        .contextMenu { kontextMenu }
    }

    @ViewBuilder private var blase: some View {
        if nachricht.geloescht {
            Text("Nachricht gelöscht")
                .italic()
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Z-5.1/Z-5.2/Z-5.3/Z-6.2–6.3: real media views. Spiel/System still fall through to
                // `platzhalter` below; a snap is never rendered via the plain medium path (view-once).
                if let snap = nachricht.snap {
                    SnapZeile(nachricht: nachricht, snap: snap, ich: ich, eigene: eigene)
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
                    Text(text)
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
                    Text("bearbeitet").font(.caption2).opacity(0.7)
                }
            }
            .padding(10)
            .foregroundStyle(Color.personText(nachricht.von))
            .background(Color.person(nachricht.von), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    /// Block 14 still replaces `spiel`'s row with the real game view; `system` stays text-only.
    private var platzhalter: (text: String, symbol: String)? {
        if nachricht.spiel != nil { return ("Spiel", "gamecontroller.fill") }
        if let system = nachricht.system { return (system, "info.circle") }
        return nil
    }

    @ViewBuilder private var kontextMenu: some View {
        if eigene, !nachricht.geloescht { Button("Bearbeiten", systemImage: "pencil") { onBearbeiten(nachricht) } }
        Button("Antworten", systemImage: "arrowshape.turn.up.left") { onAntworten(nachricht) }
        Menu("Anheften") {
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
            HStack {
                Image(systemName: nachricht.gesternt.contains(ich) ? "star.slash" : "star")
                Text(nachricht.gesternt.contains(ich) ? "Stern entfernen" : "Stern")
            }
        }
        if let text = nachricht.text {
            Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
        }
        if eigene {
            Button("Löschen", systemImage: "trash", role: .destructive) { onLoeschen(nachricht.id) }
        }
    }

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

    @State private var vollbild = false

    private var alsFoto: Bool { snap.bleibt || nachricht.snapGespeichert }

    var body: some View {
        Group {
            if alsFoto, let medium = nachricht.medien.first {
                MedienNachrichtView(medium: medium, eigene: eigene)
            } else if nachricht.snapAngesehen {
                spur(nachricht.snapLange ? "Snap lange angesehen" : "Snap angesehen")
                    .contextMenu {
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
        Button { vollbild = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Text(text)
            }
            .font(.subheadline)
        }
        .buttonStyle(.plain)
    }
}

/// Small emoji bar, opened by a double tap (Spec 5.2).
private struct ReaktionsAuswahl: View {
    let aktuell: String?
    let onWahl: (String?) -> Void
    private let emojis = ["❤️", "😂", "👍", "😮", "😢", "🙏"]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(emojis, id: \.self) { emoji in
                Button {
                    onWahl(aktuell == emoji ? nil : emoji)
                } label: {
                    Text(emoji).font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
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
