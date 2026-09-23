import PhotosUI
import SwiftUI
import UIKit

/// A picked photo/video waiting in the input bar (Block 18: never sent straight from the picker).
struct ChatAnhang: Identifiable {
    enum Inhalt: Sendable { case foto(Data), video(URL) }

    let id = UUID()
    var inhalt: Inhalt
    var vorschau: UIImage?

    var istVideo: Bool {
        switch inhalt {
        case .video: true
        case .foto: false
        }
    }

    static func laden(_ item: PhotosPickerItem) async -> ChatAnhang? {
        if let video = try? await item.loadTransferable(type: VideoDatei.self) {
            return ChatAnhang(inhalt: .video(video.url), vorschau: await Videobild.erstesBild(video.url))
        }
        guard let daten = try? await item.loadTransferable(type: Data.self) else { return nil }
        return ChatAnhang(inhalt: .foto(daten), vorschau: await vorschau(daten))
    }

    static func vorschau(_ daten: Data) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let bild = UIImage(data: daten), bild.size.width > 0, bild.size.height > 0 else { return nil }
            let faktor = 200 / max(bild.size.width, bild.size.height)
            return bild.preparingThumbnail(of: CGSize(width: bild.size.width * faktor, height: bild.size.height * faktor))
        }.value
    }
}

/// Input bar (Block 18, Snapchat order): camera · rounded field (GIF/sticker + mic inside, mic turns
/// into send once there is something to send) · photos · games. One line tall, grows only when the
/// text needs more lines (max 5). Picked photos wait as thumbnails above; tap or hold one to edit it.
/// Throttles the own "tippt" signal and the figure state (Z-4.5).
struct ChatEingabeleiste: View {
    let ich: Person
    @Binding var antwortAuf: ChatModell.Nachricht?
    @State private var eingabe = ""
    @State private var tippen = TippenSender()
    @State private var fotoAuswahl: [PhotosPickerItem] = []
    @State private var anhaenge: [ChatAnhang] = []
    @State private var bearbeiten: ChatAnhang?
    @State private var gifBlattOffen = false
    @State private var kameraOffen = false
    @State private var spieleOffen = false
    @State private var sprachBelegt = false

    private static let hoehe: CGFloat = 36

    private var kannSenden: Bool {
        !anhaenge.isEmpty || !eingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            if let antwortAuf {
                ZitatLeiste(nachricht: antwortAuf, ich: ich) { self.antwortAuf = nil }
            }
            if !anhaenge.isEmpty {
                AnhangLeiste(anhaenge: $anhaenge) { anhang in
                    if anhang.istVideo { ChatHaptik.leicht() } else { bearbeiten = anhang }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .bottom, spacing: 6) {
                Button { ChatHaptik.leicht(); kameraOffen = true } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: Self.hoehe, height: Self.hoehe)
                        .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                }
                .accessibilityLabel("Snap aufnehmen")

                feld

                PhotosPicker(selection: $fotoAuswahl, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .frame(width: Self.hoehe, height: Self.hoehe)
                }
                .accessibilityLabel("Fotos und Videos")

                Button { ChatHaptik.leicht(); spieleOffen = true } label: {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 20))
                        .frame(width: Self.hoehe, height: Self.hoehe)
                }
                .accessibilityLabel("Spiel starten")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .animation(.snappy(duration: 0.2), value: anhaenge.count)
        .onChange(of: fotoAuswahl) { _, neu in uebernehmen(neu) }
        .fullScreenCover(isPresented: $kameraOffen) {
            SnapKameraFluss(ich: ich, antwortAuf: antwortAuf?.id) {
                kameraOffen = false
                self.antwortAuf = nil
            }
        }
        .fullScreenCover(item: $bearbeiten) { anhang in
            if case .foto(let daten) = anhang.inhalt, let bild = UIImage(data: daten) {
                SnapEditor(
                    inhalt: .foto(bild), ich: ich, antwortAuf: nil,
                    onFertig: { bearbeiten = nil },
                    onUebernehmen: { jpeg in ersetzen(anhang.id, durch: jpeg) }
                )
            }
        }
        .sheet(isPresented: $gifBlattOffen) {
            GifStickerBlatt(ich: ich, antwortAuf: antwortAuf?.id) {
                gifBlattOffen = false
                self.antwortAuf = nil
            }
        }
        .sheet(isPresented: $spieleOffen) { SpieleStarter() }
        .task { await ChatMedien.ausstehendeAbarbeiten() }
        // Z-26.5: prewarms the capture session as soon as the conversation (this bar is only ever
        // shown inside it) is visible, so the very first camera open has nothing left to wait for.
        .onAppear {
            SnapKameraSteuerung.geteilt.halten()
            Task { await SnapKameraSteuerung.geteilt.vorwaermen() }
        }
        .onDisappear { SnapKameraSteuerung.geteilt.loslassen() }
    }

    /// The rounded outline field: text, then GIF/sticker and mic (or send) inside on the right.
    private var feld: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !sprachBelegt {
                ZStack(alignment: .leading) {
                    if eingabe.isEmpty {
                        Text("Chat senden").foregroundStyle(.tertiary).padding(.leading, 5)
                            .accessibilityHidden(true) // the text view itself carries the label
                    }
                    GenmojiEingabefeld(text: $eingabe)
                        .onChange(of: eingabe) { _, _ in tippen.tastenanschlag() }
                }
                .frame(maxWidth: .infinity, minHeight: Self.hoehe)

                Button { ChatHaptik.leicht(); gifBlattOffen = true } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 19))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: Self.hoehe)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("GIFs und Sticker")
            }
            if kannSenden, !sprachBelegt {
                Button { senden() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.loveaRose)
                        .frame(width: 34, height: Self.hoehe)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Senden")
                .transition(.scale.combined(with: .opacity))
            } else {
                SprachAufnahmeButton(ich: ich, antwortAuf: antwortAuf?.id, onGesendet: { self.antwortAuf = nil }, onBelegt: { sprachBelegt = $0 })
                    .foregroundStyle(.secondary)
                    .padding(.trailing, sprachBelegt ? 4 : 0)
            }
        }
        .padding(.leading, sprachBelegt ? 8 : 10)
        .padding(.trailing, 3)
        // Fills the row even while recording, so the mic never moves under the holding finger.
        .frame(maxWidth: .infinity, minHeight: Self.hoehe, alignment: .trailing)
        .overlay(RoundedRectangle(cornerRadius: Self.hoehe / 2).strokeBorder(Color(uiColor: .separator), lineWidth: 1))
        .background(Color(uiColor: .systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: Self.hoehe / 2))
        .animation(.snappy(duration: 0.18), value: kannSenden)
    }

    private func uebernehmen(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        fotoAuswahl = []
        Task {
            for item in items {
                if let anhang = await ChatAnhang.laden(item) { anhaenge.append(anhang) }
            }
            ChatHaptik.leicht()
        }
    }

    private func ersetzen(_ id: UUID, durch jpeg: Data) {
        Task {
            let vorschau = await ChatAnhang.vorschau(jpeg)
            guard let index = anhaenge.firstIndex(where: { $0.id == id }) else { return }
            anhaenge[index].inhalt = .foto(jpeg)
            anhaenge[index].vorschau = vorschau
        }
    }

    /// Media first (one message per item, so they stack), then the text.
    private func senden() {
        let text = eingabe
        let inhalte = anhaenge.map(\.inhalt)
        let antwort = antwortAuf?.id
        eingabe = ""
        anhaenge = []
        antwortAuf = nil
        tippen.beenden()
        ChatHaptik.leicht()
        guard !inhalte.isEmpty else {
            ChatModell.shared.nachrichtSenden(text: text, antwortAuf: antwort)
            return
        }
        Task {
            await ChatMedien.anhaengeSenden(inhalte, antwortAuf: antwort)
            ChatModell.shared.nachrichtSenden(text: text)
        }
    }
}

/// Picked photos/videos as small thumbnails with a remove button each.
private struct AnhangLeiste: View {
    @Binding var anhaenge: [ChatAnhang]
    let onBearbeiten: (ChatAnhang) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(anhaenge) { anhang in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let vorschau = anhang.vorschau {
                                Image(uiImage: vorschau).resizable().scaledToFill()
                            } else {
                                Rectangle().fill(.thinMaterial)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .bottomLeading) {
                            if anhang.istVideo {
                                Image(systemName: "video.fill").font(.caption2).foregroundStyle(.white).shadow(radius: 2).padding(5)
                            } else {
                                Image(systemName: "pencil").font(.caption2.bold()).foregroundStyle(.white).shadow(radius: 2).padding(5)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { onBearbeiten(anhang) }
                        .onLongPressGesture(minimumDuration: 0.35) { ChatHaptik.mittel(); onBearbeiten(anhang) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(anhang.istVideo ? "Video" : "Foto")
                        .accessibilityHint(anhang.istVideo ? "" : "Bearbeiten")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onBearbeiten(anhang) }

                        Button {
                            ChatHaptik.leicht()
                            withAnimation(.snappy) { anhaenge.removeAll { $0.id == anhang.id } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Color.black.opacity(0.65))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: 9, y: -9)
                        .accessibilityLabel("Anhang entfernen")
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 10)
        }
    }
}

/// Multi-line `UITextView` wrapper (Z-4.2/Z-4.3): `supportsAdaptiveImageGlyph` — so Genmoji/Memoji/
/// iOS-Sticker from the keyboard can be typed at all — is a `UITextInput` property, not a SwiftUI
/// `View` modifier, hence UIKit here. Block 18: one line tall (same height as the bar's icons), grows
/// with the text up to five lines, then scrolls.
// ponytail: binds plain `String` for now — the typed glyphs render as placeholder characters until
// this switches to `NSAttributedString` and turns each `NSAdaptiveImageGlyph` run into a `medien` upload.
private struct GenmojiEingabefeld: UIViewRepresentable {
    @Binding var text: String
    private static let maxZeilen: CGFloat = 5

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true // Dynamic Type changes apply live (Z-16.3)
        view.accessibilityLabel = "Nachricht"
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.supportsAdaptiveImageGlyph = true
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let breite = proposal.width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 200
        let zeile = uiView.font?.lineHeight ?? 20
        let rand = uiView.textContainerInset.top + uiView.textContainerInset.bottom
        let maxHoehe = zeile * Self.maxZeilen + rand
        let passend = uiView.sizeThatFits(CGSize(width: breite, height: .greatestFiniteMagnitude)).height
        let zuHoch = passend > maxHoehe
        if uiView.isScrollEnabled != zuHoch { uiView.isScrollEnabled = zuHoch }
        return CGSize(width: breite, height: min(max(passend, zeile + rand), maxHoehe))
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            textView.invalidateIntrinsicContentSize()
        }
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
                Text(ChatVorschau.inhalt(nachricht)).font(.caption).lineLimit(1)
            }
            Spacer()
            Button { onAbbrechen() } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 32, minHeight: 32) }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Antwort abbrechen")
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 2)
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
