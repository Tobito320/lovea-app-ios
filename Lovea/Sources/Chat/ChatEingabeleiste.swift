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
    @State private var eingabeAttr = NSAttributedString()
    @State private var mehrzeilig = false
    @State private var vollansichtOffen = false
    @State private var feldHandle = TextFeldHandle()
    @State private var tippen = TippenSender()
    @State private var fotoAuswahl: [PhotosPickerItem] = []
    @State private var anhaenge: [ChatAnhang] = []
    @State private var bearbeiten: ChatAnhang?
    @State private var gifBlattOffen = false
    @State private var kameraOffen = false
    @State private var spieleOffen = false
    @State private var sprachBelegt = false

    private static let hoehe: CGFloat = 36

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
        // Z-26.1: "Vollansicht" — same text, large editor, closes via the button or the sheet's own
        // swipe-down.
        .sheet(isPresented: $vollansichtOffen) { VollansichtEditor(text: $eingabeAttr) }
        .task { await ChatMedien.ausstehendeAbarbeiten() }
        // Z-26.5: prewarms the capture session as soon as the conversation (this bar is only ever
        // shown inside it) is visible, so the very first camera open has nothing left to wait for.
        .onAppear {
            SnapKameraSteuerung.geteilt.halten()
            Task { await SnapKameraSteuerung.geteilt.vorwaermen() }
        }
        .onDisappear { SnapKameraSteuerung.geteilt.loslassen() }
        // Z-26.4: same poll-for-`nachgeholt` idiom as `KalenderModell` — runs once the log has
        // fully caught up, so `UmzugAufraeumen`'s own `aufgeraeumt` fold has already replayed.
        .task {
            while !Raum.shared.nachgeholt {
                try? await Task.sleep(for: .seconds(1))
            }
            UmzugAufraeumen.shared.versuchen()
        }
    }

    /// The rounded outline field: text, then GIF/sticker and mic inside on the right. No send
    /// button (Z-26.1) — Return in the field sends; the "Vollansicht" icon appears top-right once
    /// two or more lines are showing.
    private var feld: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if !sprachBelegt {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .leading) {
                        if eingabeAttr.length == 0 {
                            Text("Chat senden").foregroundStyle(.tertiary).padding(.leading, 5)
                                .accessibilityHidden(true) // the text view itself carries the label
                        }
                        GenmojiEingabefeld(
                            text: $eingabeAttr, mehrzeilig: $mehrzeilig, handle: feldHandle,
                            onSenden: senden, onAendert: { tippen.tastenanschlag() }
                        )
                    }
                    .padding(.trailing, mehrzeilig ? 24 : 0)

                    if mehrzeilig {
                        Button { ChatHaptik.leicht(); vollansichtOffen = true } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color(uiColor: .systemBackground).opacity(0.7), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Vollansicht")
                    }
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
            SprachAufnahmeButton(ich: ich, antwortAuf: antwortAuf?.id, onGesendet: { self.antwortAuf = nil }, onBelegt: { sprachBelegt = $0 })
                .foregroundStyle(.secondary)
                .padding(.trailing, sprachBelegt ? 4 : 0)
        }
        .padding(.leading, sprachBelegt ? 8 : 10)
        .padding(.trailing, 3)
        // Fills the row even while recording, so the mic never moves under the holding finger.
        .frame(maxWidth: .infinity, minHeight: Self.hoehe, alignment: .trailing)
        .overlay(RoundedRectangle(cornerRadius: Self.hoehe / 2).strokeBorder(Color(uiColor: .separator), lineWidth: 1))
        .background(Color(uiColor: .systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: Self.hoehe / 2))
    }

    private func uebernehmen(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        fotoAuswahl = []
        Task {
            for item in items {
                if let anhang = await ChatAnhang.laden(item) { anhaenge.append(anhang) }
            }
            ChatHaptik.leicht()
            // No send button anymore (Z-26.1) — an attachment-only send needs the keyboard up so
            // Return has something to send from.
            feldHandle.fokussieren()
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

    /// Stickers first (each `NSAdaptiveImageGlyph` in the composed text, Z-26.1), then media (one
    /// message per item, so they stack), then the leftover text. Only the very first thing sent
    /// carries the reply reference.
    private func senden() {
        let attributiert = eingabeAttr
        let inhalte = anhaenge.map(\.inhalt)
        let antwortID = antwortAuf?.id
        // Extracted now, on the main actor — `NSAdaptiveImageGlyph`/`NSAttributedString` aren't
        // Sendable, so this can't wait until inside the `Task` below.
        let glyphDaten = GenmojiExtraktion.glyphBilder(in: attributiert)
        let text = GenmojiExtraktion.textOhneGlyphen(attributiert)

        eingabeAttr = NSAttributedString()
        anhaenge = []
        antwortAuf = nil
        mehrzeilig = false
        tippen.beenden()

        guard !inhalte.isEmpty || !glyphDaten.isEmpty || !text.isEmpty else { return }
        ChatHaptik.leicht()

        Task {
            var antwort = antwortID
            for daten in glyphDaten {
                // Genmoji/Memoji hand back multi-resolution HEIC, not PNG — re-encode off the main
                // actor so `stickerHochladen`'s `.png` staging matches the actual bytes.
                let png = await Task.detached(priority: .userInitiated) { UIImage(data: daten)?.pngData() }.value
                guard let png, let id = await ChatMedien.stickerHochladen(png: png) else { continue }
                ChatModell.shared.stickerSenden(medienId: id, antwortAuf: antwort)
                antwort = nil
            }
            if !inhalte.isEmpty {
                await ChatMedien.anhaengeSenden(inhalte, antwortAuf: antwort)
                antwort = nil
            }
            if !text.isEmpty {
                ChatModell.shared.nachrichtSenden(text: text, antwortAuf: antwort)
            }
        }
    }
}

/// Focuses the composer's `UITextView` from outside (Z-26.1): with no send button left, picking an
/// attachment with an empty text field needs the keyboard up so Return has something to send.
@MainActor
private final class TextFeldHandle {
    weak var view: UITextView?
    func fokussieren() { view?.becomeFirstResponder() }
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

/// Multi-line `UITextView` wrapper (Z-4.2/Z-4.3, rewritten for Z-26.1): `supportsAdaptiveImageGlyph`
/// — so Genmoji/Memoji/iOS-Sticker from the keyboard can be typed at all — is a `UITextInput`
/// property, not a SwiftUI `View` modifier, hence UIKit here. Binds the live `NSAttributedString`
/// (not `String`) so an attached glyph's `.adaptiveImageGlyph` attribute survives until send. One
/// line tall, grows with the text up to five lines, then scrolls. Return sends (delegate
/// `shouldChangeTextIn`, "\n" → `onSenden`, no newline inserted).
private struct GenmojiEingabefeld: UIViewRepresentable {
    @Binding var text: NSAttributedString
    @Binding var mehrzeilig: Bool
    let handle: TextFeldHandle
    var onSenden: () -> Void
    var onAendert: () -> Void

    private static let maxZeilen: CGFloat = 5
    private static let schrift = UIFont.preferredFont(forTextStyle: .body)

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = Self.schrift
        view.adjustsFontForContentSizeCategory = true // Dynamic Type changes apply live (Z-16.3)
        view.accessibilityLabel = "Nachricht"
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.supportsAdaptiveImageGlyph = true
        view.typingAttributes = [.font: Self.schrift]
        view.delegate = context.coordinator
        handle.view = view
        return view
    }

    /// `makeCoordinator()` only runs once, so the closures it captured on the first render would
    /// otherwise go stale — refreshed here on every update instead.
    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onSenden = onSenden
        context.coordinator.onAendert = onAendert
        guard uiView.attributedText.string != text.string else { return }
        uiView.attributedText = text
        // A programmatic set (clear after send, draft restore, synced back from "Vollansicht")
        // otherwise leaves `typingAttributes` derived from whatever's now at the cursor — empty
        // text has nothing to derive from, so the next character typed can fall back to a tiny
        // default font.
        uiView.typingAttributes = [.font: Self.schrift]
        // Deferred: mutating a binding synchronously inside `updateUIView` runs during SwiftUI's
        // own update pass.
        DispatchQueue.main.async { context.coordinator.zeilenAktualisieren(uiView) }
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

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, mehrzeilig: $mehrzeilig, onSenden: onSenden, onAendert: onAendert)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let text: Binding<NSAttributedString>
        let mehrzeilig: Binding<Bool>
        var onSenden: () -> Void
        var onAendert: () -> Void

        init(text: Binding<NSAttributedString>, mehrzeilig: Binding<Bool>, onSenden: @escaping () -> Void, onAendert: @escaping () -> Void) {
            self.text = text
            self.mehrzeilig = mehrzeilig
            self.onSenden = onSenden
            self.onAendert = onAendert
        }

        /// Hardware/software Return delivers "\n" as the replacement text — swallow it and send
        /// instead of inserting a newline (Z-26.1; there's no other way to add a line break).
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement == "\n" else { return true }
            onSenden()
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.attributedText
            onAendert()
            textView.invalidateIntrinsicContentSize()
            zeilenAktualisieren(textView)
        }

        /// Two or more lines showing → the "Vollansicht" icon appears (Z-26.1's "ab Zeile 2").
        func zeilenAktualisieren(_ textView: UITextView) {
            let zeile = textView.font?.lineHeight ?? 20
            let rand = textView.textContainerInset.top + textView.textContainerInset.bottom
            let breite = max(textView.bounds.width, 1)
            let inhalt = textView.sizeThatFits(CGSize(width: breite, height: .greatestFiniteMagnitude)).height
            let neu = inhalt > zeile * 1.5 + rand
            if mehrzeilig.wrappedValue != neu { mehrzeilig.wrappedValue = neu }
        }
    }
}

/// Z-26.1 "Vollansicht": same text, a large scrollable editor; closes via the toolbar button or the
/// sheet's own swipe-down (the default `.sheet` dismiss gesture, nothing extra needed for that).
private struct VollansichtEditor: View {
    @Binding var text: NSAttributedString
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VollansichtTextView(text: $text)
                .padding()
                .navigationTitle("Nachricht")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }
}

/// Same attributed-text field as the input bar, just full-size and free-scrolling: Return here
/// inserts an ordinary newline (only the compact bar's Return sends).
private struct VollansichtTextView: UIViewRepresentable {
    @Binding var text: NSAttributedString
    private static let schrift = UIFont.preferredFont(forTextStyle: .body)

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = Self.schrift
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = "Nachricht"
        view.supportsAdaptiveImageGlyph = true
        view.typingAttributes = [.font: Self.schrift]
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        guard uiView.attributedText.string != text.string else { return }
        uiView.attributedText = text
        uiView.typingAttributes = [.font: Self.schrift]
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        let text: Binding<NSAttributedString>
        init(text: Binding<NSAttributedString>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) { text.wrappedValue = textView.attributedText }
    }
}

/// What a composed attributed string turns into when sent (Z-26.1): each attached Genmoji/Memoji/
/// iOS-sticker glyph becomes its own image; the leftover text has every glyph's placeholder
/// character (U+FFFC, `NSAttributedString.textAttachmentCharacter` renders as this) removed and
/// trimmed. Pure, so it's testable without a live `UITextView`.
enum GenmojiExtraktion {
    static func glyphBilder(in text: NSAttributedString) -> [Data] {
        var bilder: [Data] = []
        text.enumerateAttribute(.adaptiveImageGlyph, in: NSRange(location: 0, length: text.length)) { wert, _, _ in
            guard let glyph = wert as? NSAdaptiveImageGlyph else { return }
            bilder.append(glyph.imageContent)
        }
        return bilder
    }

    static func textOhneGlyphen(_ text: NSAttributedString) -> String {
        text.string.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
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
