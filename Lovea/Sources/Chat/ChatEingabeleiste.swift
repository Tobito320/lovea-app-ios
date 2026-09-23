import PhotosUI
import SwiftUI
import UIKit

/// Input bar (Z-4.3, Z-5.1–Z-5.3): multi-line field, photo/video picker, GIF/Sticker sheet, voice
/// recording, send, reply quote. Throttles the own "tippt" signal and the figure state (Z-4.5).
struct ChatEingabeleiste: View {
    let ich: Person
    @Binding var antwortAuf: ChatModell.Nachricht?
    @State private var eingabe = ""
    @State private var tippen = TippenSender()
    @State private var fotoAuswahl: [PhotosPickerItem] = []
    @State private var gifBlattOffen = false

    var body: some View {
        VStack(spacing: 6) {
            if let antwortAuf {
                ZitatLeiste(nachricht: antwortAuf, ich: ich) { self.antwortAuf = nil }
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button {} label: { Image(systemName: "camera.fill") }
                    .disabled(true) // ponytail: Snap-Kamera kommt in Block 6
                PhotosPicker(selection: $fotoAuswahl, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle")
                }
                .onChange(of: fotoAuswahl) { _, neu in sendeAuswahl(neu) }
                Button { gifBlattOffen = true } label: { Image(systemName: "face.smiling") }
                    .sheet(isPresented: $gifBlattOffen) {
                        GifStickerBlatt(ich: ich, antwortAuf: antwortAuf?.id) {
                            gifBlattOffen = false
                            self.antwortAuf = nil
                        }
                    }

                ZStack(alignment: .topLeading) {
                    if eingabe.isEmpty {
                        Text("Nachricht").foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 8)
                    }
                    GenmojiEingabefeld(text: $eingabe)
                        .frame(minHeight: 34, maxHeight: 110)
                        .onChange(of: eingabe) { _, _ in tippen.tastenanschlag() }
                }
                .padding(2)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                if eingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SprachAufnahmeButton(ich: ich, antwortAuf: antwortAuf?.id) { self.antwortAuf = nil }
                } else {
                    Button { senden() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .task { await ChatMedien.ausstehendeAbarbeiten() }
    }

    private func senden() {
        ChatModell.shared.nachrichtSenden(text: eingabe, antwortAuf: antwortAuf?.id)
        eingabe = ""
        antwortAuf = nil
        tippen.beenden()
    }

    private func sendeAuswahl(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let antwortAuf = antwortAuf?.id
        Task {
            await ChatMedien.auswahlSenden(items, antwortAuf: antwortAuf)
            fotoAuswahl = []
            self.antwortAuf = nil
        }
    }
}

/// Multi-line `UITextView` wrapper (Z-4.2/Z-4.3): `supportsAdaptiveImageGlyph` — so Genmoji/Memoji/
/// iOS-Sticker from the keyboard can be typed at all — is a `UITextInput` property, not a SwiftUI
/// `View` modifier (confirmed against developer.apple.com/documentation/uikit/uitextinput/
/// supportsadaptiveimageglyph; SwiftUI's `TextField`/`TextEditor` don't expose it), hence UIKit here.
// ponytail: binds plain `String` for now — the typed glyphs render as placeholder characters until
// Block 5/6 switches this to `NSAttributedString` and turns each `NSAdaptiveImageGlyph` run into a
// `medien` upload before sending, per the decision to defer media/glyph handling to those blocks.
private struct GenmojiEingabefeld: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.isScrollEnabled = true
        view.supportsAdaptiveImageGlyph = true
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) { text.wrappedValue = textView.text }
    }
}

private struct ZitatLeiste: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    let onAbbrechen: () -> Void

    var body: some View {
        HStack {
            Rectangle().fill(Color.person(nachricht.von)).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(nachricht.von == ich ? "Du" : nachricht.von.name).font(.caption.bold())
                Text(nachricht.text ?? "Nachricht").font(.caption).lineLimit(1)
            }
            Spacer()
            Button { onAbbrechen() } label: { Image(systemName: "xmark.circle.fill") }
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
    }
}

/// Throttles `tippt` and the own figure state: sends at most every 2 s, ends after 5 s idle (Z-4.5).
@MainActor
private final class TippenSender {
    private var letzteSendung: Date?
    private var endeTask: Task<Void, Never>?

    func tastenanschlag() {
        let jetzt = Date()
        if letzteSendung == nil || jetzt.timeIntervalSince(letzteSendung!) >= 2 {
            letzteSendung = jetzt
            Raum.shared.fluechtig("tippt", ["an": true])
            FigurenModell.shared.zustandSenden(.init(haupt: .tippt))
        }
        endeTask?.cancel()
        endeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.beenden()
        }
    }

    func beenden() {
        endeTask?.cancel()
        endeTask = nil
        guard letzteSendung != nil else { return }
        letzteSendung = nil
        Raum.shared.fluechtig("tippt", ["an": false])
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
    }
}
