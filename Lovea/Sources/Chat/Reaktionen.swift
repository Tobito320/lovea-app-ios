import SwiftUI
import UIKit

/// Z-33.1: what `nachricht.reaktion {id, emoji}` carries in `emoji` — an emoji, `"figur:<id>"` or
/// `"sticker:<assetName>"`. Older builds show the raw string, which is accepted.
enum Reaktion: Equatable, Sendable {
    case emoji(String), figur(String), sticker(String)

    init(_ wert: String) {
        if wert.hasPrefix("figur:") {
            self = .figur(String(wert.dropFirst("figur:".count)))
        } else if wert.hasPrefix("sticker:") {
            self = .sticker(String(wert.dropFirst("sticker:".count)))
        } else {
            self = .emoji(wert)
        }
    }

    var wert: String {
        switch self {
        case .emoji(let zeichen): zeichen
        case .figur(let id): "figur:" + id
        case .sticker(let name): "sticker:" + name
        }
    }

    /// Spoken by VoiceOver and shown in "who reacted".
    var beschreibung: String {
        switch self {
        case .emoji(let zeichen): zeichen
        case .figur(let id): FigurReaktionen.von(id)?.titel ?? "Figur"
        case .sticker: "Sticker"
        }
    }

    /// The emoji keyboard's first character — never a letter or digit typed on a switched keyboard.
    static func istEmoji(_ zeichen: Character) -> Bool {
        zeichen.unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || (zeichen.unicodeScalars.count > 1 && zeichen.unicodeScalars.first?.properties.isEmoji == true)
    }
}

/// One figure reaction. Single ones use the reacting person's figure and their `id` is the
/// `FigurZustand` raw value; couple ones (`paar`) show both figures.
struct FigurReaktion: Identifiable, Sendable {
    let id: String
    let titel: String
    let paar: Bool
}

/// Couple scene: Ahmed left, Annika right, like `FreundschaftsSticker`.
struct PaarPose: Sendable {
    let links: String
    let rechts: String
    var zugewandt = false
    var symbol: String?
}

enum FigurReaktionen {
    /// Spec 2.4: the long-press bar — lachen, verliebt, weinen, schockiert, Daumen, Kuss.
    static let schnell: [FigurReaktion] = ["lacht", "verliebt", "weint", "schockiert", "daumen", "kuss"].compactMap { FigurReaktionen.von($0) }

    static let alle: [FigurReaktion] = einzeln.map { FigurReaktion(id: $0.id, titel: $0.titel, paar: false) }
        + paare.map { FigurReaktion(id: $0.id, titel: $0.titel, paar: true) }

    static func von(_ id: String) -> FigurReaktion? { alle.first { $0.id == id } }

    static func paarPose(_ id: String) -> PaarPose? { paare.first { $0.id == id }?.pose }

    // Raw values rather than `FigurZustand` cases: a state an older figure build lacks falls back to
    // `.ruhig` when drawn instead of breaking the build.
    private static let einzeln: [(id: String, titel: String)] = [
        ("lacht", "Lachen"), ("verliebt", "Verliebt"), ("weint", "Weinen"), ("schockiert", "Schockiert"),
        ("daumen", "Daumen hoch"), ("kuss", "Kuss"), ("lachtTraenen", "Tränen lachen"), ("zwinkert", "Zwinkern"),
        ("herz", "Denk an dich"), ("feiert", "Feiern"), ("tanzt", "Tanzen"), ("ueberrascht", "Überrascht"),
        ("denkt", "Nachdenken"), ("verlegen", "Verlegen"), ("schmollt", "Schmollen"), ("sauer", "Sauer"),
        ("muede", "Müde"), ("naehe", "Umarmung"), ("anstossen", "Prost"), ("pokal", "Gewonnen"),
        ("imChat", "Hallo"), ("morgen", "Guten Morgen"), ("schlaeft", "Gute Nacht"), ("anstupsen", "Anstupsen"),
        ("worte", "Liebe Worte"), ("gut", "Freude"),
    ]

    private static let paare: [(id: String, titel: String, pose: PaarPose)] = [
        ("paar-kuss", "Küssen", PaarPose(links: "kuss", rechts: "kuss", zugewandt: true)),
        ("paar-herz", "Herz", PaarPose(links: "herz", rechts: "herz", symbol: "heart.fill")),
        ("paar-prost", "Anstoßen", PaarPose(links: "anstossen", rechts: "anstossen", zugewandt: true)),
        ("paar-lachen", "Zusammen lachen", PaarPose(links: "lachtTraenen", rechts: "lachtTraenen")),
        ("paar-kuscheln", "Kuscheln", PaarPose(links: "naehe", rechts: "naehe", symbol: "heart.fill")),
        ("paar-feiern", "Feiern", PaarPose(links: "feiert", rechts: "feiert", symbol: "party.popper.fill")),
        ("paar-tanzen", "Tanzen", PaarPose(links: "tanzt", rechts: "tanzt", zugewandt: true, symbol: "music.note")),
        ("paar-verliebt", "Verliebt", PaarPose(links: "verliebt", rechts: "verliebt", zugewandt: true, symbol: "heart.fill")),
        ("paar-nacht", "Gute Nacht", PaarPose(links: "schlaeft", rechts: "schlaeft", symbol: "moon.stars.fill")),
        ("paar-hallo", "High-Five", PaarPose(links: "imChat", rechts: "imChat", zugewandt: true, symbol: "sparkle")),
        ("paar-sieg", "Gewonnen", PaarPose(links: "pokal", rechts: "gut", symbol: "trophy.fill")),
        ("paar-morgen", "Guten Morgen", PaarPose(links: "morgen", rechts: "morgen", symbol: "sun.max.fill")),
    ]
}

// MARK: - Figure reactions as cached images (Spec 2.4: never a live-drawn figure in a bubble)

/// A figure reaction drawn once, static. Singles: the reacting person's figure, head and upper body.
/// Couples: both figures (Ahmed left, Annika right) with an optional symbol between.
struct FigurReaktionAnsicht: View {
    let reaktion: FigurReaktion
    let person: Person
    let ahmed: FigurAussehen
    let annika: FigurAussehen

    var body: some View {
        if let pose = FigurReaktionen.paarPose(reaktion.id) {
            paar(pose)
        } else {
            FigurView(person == .ahmed ? ahmed : annika, zustand: Self.zustand(reaktion.id), groesse: 140, animiert: false)
                .frame(width: 120, height: 120, alignment: .top)
                .clipped()
        }
    }

    private func paar(_ pose: PaarPose) -> some View {
        ZStack {
            FigurView(ahmed, zustand: Self.zustand(pose.links), groesse: 120, animiert: false)
                .offset(x: -34)
            FigurView(annika, zustand: Self.zustand(pose.rechts), groesse: 120, animiert: false)
                .scaleEffect(x: pose.zugewandt ? -1 : 1, y: 1)
                .offset(x: 34)
            if let symbol = pose.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.loveaRose)
                    .offset(y: -50)
            }
        }
        .frame(width: 180, height: 130)
    }

    static func zustand(_ id: String) -> FigurZustand { FigurZustand(rawValue: id) ?? .ruhig }
}

/// Renders each figure reaction once per (reaction, person, outfit) with `ImageRenderer` and keeps
/// it in memory. Views read `bild`; a miss (or a changed outfit) schedules one render and keeps
/// showing the old image meanwhile; the finished image re-renders every reader.
// ponytail: plain dictionary, at most ~64 small images; an NSCache if memory warnings ever show up.
@MainActor
@Observable
final class ReaktionsBilder {
    static let shared = ReaktionsBilder()

    private var cache: [String: (aussehen: [FigurAussehen], bild: UIImage)] = [:]
    @ObservationIgnored private var ausstehend: Set<String> = []

    func bild(_ reaktion: FigurReaktion, von person: Person) -> UIImage? {
        let ahmed = FigurenModell.shared.aussehen(.ahmed)
        let annika = FigurenModell.shared.aussehen(.annika)
        let schluessel = reaktion.paar ? reaktion.id : "\(reaktion.id)|\(person.rawValue)"
        let aussehen = reaktion.paar ? [ahmed, annika] : [person == .ahmed ? ahmed : annika]
        let eintrag = cache[schluessel]
        if eintrag?.aussehen != aussehen, ausstehend.insert(schluessel).inserted {
            Task { [weak self] in
                let renderer = ImageRenderer(content: FigurReaktionAnsicht(reaktion: reaktion, person: person, ahmed: ahmed, annika: annika))
                renderer.scale = 2
                guard let self else { return }
                if let bild = renderer.uiImage { self.cache[schluessel] = (aussehen, bild) }
                self.ausstehend.remove(schluessel)
            }
        }
        return eintrag?.bild
    }

    /// The long-press bar should never wait: render the own quick six once the chat is open.
    func vorwaermen(_ ich: Person) {
        for reaktion in FigurReaktionen.schnell { _ = bild(reaktion, von: ich) }
    }
}

struct FigurReaktionBild: View {
    let reaktion: FigurReaktion
    let person: Person

    var body: some View {
        Group {
            if let bild = ReaktionsBilder.shared.bild(reaktion, von: person) {
                Image(uiImage: bild).resizable().scaledToFit()
            } else {
                Color.clear
            }
        }
        .accessibilityElement()
        .accessibilityLabel(reaktion.titel)
    }
}

/// Bundled sticker assets offered as reactions (`sticker:<assetName>`).
// ponytail: empty in wave A (no sticker assets yet), so the Sticker tab stays hidden. Z-40.2
// (Agent H) fills in the `wir-*`/`meme-*` asset names.
enum StickerReaktionen {
    static let namen: [String] = []
}

/// Emoji, figure image or sticker, square.
struct ReaktionsInhalt: View {
    let reaktion: Reaktion
    let von: Person
    var groesse: CGFloat = 28

    var body: some View {
        Group {
            switch reaktion {
            case .emoji(let zeichen):
                Text(zeichen).font(.system(size: groesse * 0.72))
            case .figur(let id):
                if let figur = FigurReaktionen.von(id) {
                    FigurReaktionBild(reaktion: figur, person: von)
                } else {
                    Image(systemName: "face.smiling").foregroundStyle(.secondary)
                }
            case .sticker(let name):
                if let bild = UIImage(named: name) {
                    Image(uiImage: bild).resizable().scaledToFit()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: groesse, height: groesse)
    }
}

// MARK: - Badge on the bubble corner (iMessage)

/// Up to two reactions (one per person), the second slightly offset. Tap shows who set what; the
/// own one can be removed there.
struct ReaktionsAbzeichen: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    @State private var werOffen = false
    @Environment(\.chatBackdrop) private var festerBackdrop

    private var eintraege: [(person: Person, reaktion: Reaktion)] {
        [ich.partner, ich].compactMap { person in
            nachricht.reaktionen[person].map { (person: person, reaktion: Reaktion($0)) }
        }
    }

    var body: some View {
        let liste = eintraege
        if !liste.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(Array(liste.enumerated()), id: \.offset) { index, eintrag in
                    abzeichen(eintrag.person, eintrag.reaktion)
                        .offset(x: CGFloat(index) * 16, y: CGFloat(index) * 3)
                }
            }
            .padding(.trailing, CGFloat(liste.count - 1) * 16)
            .contentShape(.rect)
            .onTapGesture {
                Haptik.auswahl()
                werOffen = true
            }
            .popover(isPresented: $werOffen) { werListe(liste) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(beschreibung(liste))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { werOffen = true }
        }
    }

    private func beschreibung(_ liste: [(person: Person, reaktion: Reaktion)]) -> String {
        "Reaktionen: " + liste.map { "\($0.reaktion.beschreibung) von \($0.person == ich ? "dir" : $0.person.name)" }.joined(separator: ", ")
    }

    private func abzeichen(_ person: Person, _ reaktion: Reaktion) -> some View {
        let backdrop = festerBackdrop ?? Backdrops.aktuell
        let farbe = person == ich ? (backdrop.verlauf.first ?? Color.loveaRose) : backdrop.partnerBlase
        return ReaktionsInhalt(reaktion: reaktion, von: person, groesse: 26)
            .frame(width: 34, height: 34)
            .background(farbe, in: .circle)
            .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private func werListe(_ liste: [(person: Person, reaktion: Reaktion)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(liste.enumerated()), id: \.offset) { _, eintrag in
                HStack(spacing: 10) {
                    ReaktionsInhalt(reaktion: eintrag.reaktion, von: eintrag.person, groesse: 36)
                    Text(eintrag.person == ich ? "Du" : eintrag.person.name).font(.body.weight(.medium))
                    Spacer(minLength: 0)
                }
            }
            if nachricht.reaktionen[ich] != nil {
                Button("Meine Reaktion entfernen", systemImage: "xmark.circle", role: .destructive) {
                    ChatModell.shared.reagieren(nachricht.id, emoji: nil)
                    Haptik.mittel()
                    werOffen = false
                }
                .frame(minHeight: 44)
            }
        }
        .padding()
        .frame(minWidth: 220)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - Long-press bar

/// Spec 2.4: glass bar over the bubble with the own figure's six quick reactions and a plus.
struct ReaktionsLeiste: View {
    let ich: Person
    /// The raw value of the own current reaction, highlighted.
    let aktuell: String?
    let onWahl: (Reaktion) -> Void
    let onMehr: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FigurReaktionen.schnell) { reaktion in
                Button { onWahl(.figur(reaktion.id)) } label: {
                    FigurReaktionBild(reaktion: reaktion, person: ich)
                        .frame(width: 40, height: 40)
                        .frame(width: 44, height: 44)
                        .background(aktuell == Reaktion.figur(reaktion.id).wert ? Color.primary.opacity(0.14) : Color.clear, in: .circle)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(reaktion.titel)
            }
            Button(action: onMehr) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.1), in: .circle)
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("Weitere Reaktionen")
        }
        .padding(6)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Plus sheet: every figure reaction, stickers, emoji keyboard

struct ReaktionenBlatt: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    @Environment(\.dismiss) private var dismiss
    @State private var reiter = Reiter.figur

    private enum Reiter: String, CaseIterable, Identifiable {
        case figur = "Figur", paar = "Zu zweit", sticker = "Sticker", emoji = "Emoji"
        var id: String { rawValue }
    }

    private var reiterListe: [Reiter] { Reiter.allCases.filter { $0 != .sticker || !StickerReaktionen.namen.isEmpty } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Art", selection: $reiter) {
                    ForEach(reiterListe) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                inhalt
            }
            .padding(.top, 8)
            .navigationTitle("Reagieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        // Haptik.auswahl(), not `.sensoryFeedback`: the latter ignores the "Haptik" settings switch.
        .onChange(of: reiter) { _, _ in Haptik.auswahl() }
    }

    @ViewBuilder private var inhalt: some View {
        switch reiter {
        case .figur: figurRaster(FigurReaktionen.alle.filter { !$0.paar })
        case .paar: figurRaster(FigurReaktionen.alle.filter(\.paar))
        case .sticker: stickerRaster
        case .emoji: EmojiWahl { waehlen(.emoji($0)) }
        }
    }

    private func figurRaster(_ liste: [FigurReaktion]) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 14) {
                ForEach(liste) { reaktion in
                    Button { waehlen(.figur(reaktion.id)) } label: {
                        VStack(spacing: 4) {
                            FigurReaktionBild(reaktion: reaktion, person: ich).frame(height: 64)
                            Text(reaktion.titel).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityLabel(reaktion.titel)
                }
            }
            .padding()
        }
    }

    private var stickerRaster: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 14) {
                ForEach(StickerReaktionen.namen, id: \.self) { name in
                    Button { waehlen(.sticker(name)) } label: {
                        ReaktionsInhalt(reaktion: .sticker(name), von: ich, groesse: 76)
                            .frame(maxWidth: .infinity, minHeight: 84)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityLabel("Sticker")
                }
            }
            .padding()
        }
    }

    private func waehlen(_ reaktion: Reaktion) {
        ChatModell.shared.reagierenUmschalten(nachricht, reaktion, ich: ich)
        Haptik.mittel()
        dismiss()
    }
}

/// The system emoji keyboard (a `UITextField` asking for the emoji input mode); without an emoji
/// keyboard installed, a grid of common emoji instead.
private struct EmojiWahl: View {
    let onEmoji: (String) -> Void

    private static let haeufige = [
        "❤️", "😂", "😍", "🥰", "😘", "😊", "😁", "🤣", "😭", "🥺", "😢", "😮", "😱", "😳", "🙈",
        "🙏", "👍", "👎", "👏", "🙌", "💪", "🔥", "✨", "🎉", "🥳", "😎", "🤔", "🙄", "😴", "🤤",
        "😋", "😜", "😇", "🤗", "🫶", "💕", "💖", "💘", "💯", "✅", "😡", "😤", "🤯", "🥲", "😅",
        "😬", "🤭", "🫣", "💋", "🌹", "🌙", "☀️", "⭐️", "🌈", "🍕", "☕️", "🍿", "🎂", "🐶", "🐱",
    ]

    var body: some View {
        if EmojiTastatur.verfuegbar {
            VStack(spacing: 10) {
                EmojiEingabe(onEmoji: onEmoji)
                    .frame(height: 56)
                    .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 14))
                    .padding(.horizontal)
                Text("Tippe ein Emoji auf der Tastatur").font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 6)], spacing: 6) {
                    ForEach(Self.haeufige, id: \.self) { emoji in
                        Button { onEmoji(emoji) } label: {
                            Text(emoji).font(.system(size: 30)).frame(width: 48, height: 48)
                        }
                        .buttonStyle(.federnd)
                    }
                }
                .padding()
            }
        }
    }
}

@MainActor
enum EmojiTastatur {
    static var verfuegbar: Bool { UITextInputMode.activeInputModes.contains { $0.primaryLanguage == "emoji" } }
}

/// Text field that opens straight on the emoji keyboard; its first emoji is the reaction.
final class EmojiTextFeld: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }

    override var textInputContextIdentifier: String? { "" }
}

private struct EmojiEingabe: UIViewRepresentable {
    let onEmoji: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextFeld {
        let feld = EmojiTextFeld()
        feld.placeholder = "Emoji"
        feld.textAlignment = .center
        feld.font = .preferredFont(forTextStyle: .title1)
        feld.adjustsFontForContentSizeCategory = true
        feld.accessibilityLabel = "Emoji eingeben"
        feld.delegate = context.coordinator
        // The sheet is still sliding up; a first responder right away is dropped.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            feld.becomeFirstResponder()
        }
        return feld
    }

    func updateUIView(_ uiView: EmojiTextFeld, context: Context) {
        context.coordinator.onEmoji = onEmoji
    }

    func makeCoordinator() -> Coordinator { Coordinator(onEmoji: onEmoji) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var onEmoji: (String) -> Void

        init(onEmoji: @escaping (String) -> Void) { self.onEmoji = onEmoji }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let erstes = string.first, Reaktion.istEmoji(erstes) else { return false }
            onEmoji(String(erstes))
            return false
        }
    }
}
