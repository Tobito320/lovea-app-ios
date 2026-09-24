import LinkPresentation
import SwiftUI
import UIKit

/// What a row can ask of the conversation.
struct ChatZeilenAktionen {
    let antworten: (ChatModell.Nachricht) -> Void
    let springen: (String) -> Void
    let fokussieren: (ChatFokus) -> Void
}

/// Where a row sits among its neighbours (Z-32.4): separators, 2 pt inside a group, 8 pt between
/// groups, tail on the last bubble of a group.
struct ZeilenLayout {
    var datumstrenner: Bool
    var zeitstempel: Bool
    var gruppenAnfang: Bool
    var gruppenEnde: Bool

    init(vorher: ChatModell.Nachricht?, erste: ChatModell.Nachricht, letzte: ChatModell.Nachricht, nachher: ChatModell.Nachricht?) {
        datumstrenner = vorher.map { !Calendar.berlin.isDate(erste.zeit, inSameDayAs: $0.zeit) } ?? true
        zeitstempel = vorher.map { erste.zeit.timeIntervalSince($0.zeit) > 900 } ?? true
        gruppenAnfang = datumstrenner || zeitstempel || !(vorher.map { BlasenGruppe.zusammen($0, erste) } ?? false)
        let naechsteMitTrenner = nachher.map { $0.zeit.timeIntervalSince(letzte.zeit) > 900 } ?? false
        gruppenEnde = naechsteMitTrenner || !(nachher.map { BlasenGruppe.zusammen(letzte, $0) } ?? false)
    }
}

/// One row (Z-4.2, Block 18, Z-32.4, Z-33.1–Z-33.3). Gestures: swipe right to reply, swipe left to
/// peek at the time, double tap for ❤️, long press for reactions and the menu (`NachrichtFokusEbene`).
/// A photo stack (several photo messages in a row) renders as `FotoStapel`.
struct ChatNachrichtRow: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    /// Every message of this row's photo stack (first == `nachricht`); just `[nachricht]` otherwise.
    var stapel: [ChatModell.Nachricht] = []
    let layout: ZeilenLayout
    /// Set on the row holding the newest own message the partner has read (Z-32.4).
    var gelesenAm: Date?
    var zustellText: String?
    let aktionen: ChatZeilenAktionen

    @State private var wischOffset: CGFloat = 0
    @State private var herzSichtbar = false
    @State private var rahmen = RahmenBox()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let antwortSchwelle: CGFloat = 56
    private var eigene: Bool { nachricht.von == ich }

    var body: some View {
        VStack(spacing: 4) {
            trenner
            inhalt
        }
        .padding(.top, layout.gruppenAnfang ? 8 : 2)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : Feder.weich, value: nachricht.geloescht)
    }

    @ViewBuilder private var trenner: some View {
        if layout.datumstrenner {
            Text(nachricht.zeit.formatted(date: .abbreviated, time: .omitted))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        if layout.zeitstempel {
            Text(nachricht.zeit.formatted(date: .omitted, time: .shortened))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var inhalt: some View {
        if let einladung = nachricht.einladung {
            ZeichnungEinladungZeile(zeichnungId: einladung.zeichnungId, name: einladung.name, von: nachricht.von, ich: ich)
        } else if nachricht.geloescht {
            hinweisZeile(eigene ? "Du hast eine Nachricht zurückgezogen" : "\(nachricht.von.name) hat eine Nachricht zurückgezogen", symbol: "arrow.uturn.backward")
                .transition(.opacity)
        } else if let system = nachricht.system {
            hinweisZeile(system, symbol: "info.circle")
        } else {
            blasenZeile
                .transition(reduceMotion ? AnyTransition.opacity : .puff)
        }
    }

    /// Centered caption instead of a bubble (unsent message, screenshot notice, …).
    private func hinweisZeile(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
    }

    private var blasenZeile: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if eigene { Spacer(minLength: 48) }
            VStack(alignment: eigene ? .trailing : .leading, spacing: 3) {
                if let antwortAuf = nachricht.antwortAuf { zitat(antwortAuf) }
                blase
                NachrichtFusszeile(nachricht: nachricht, ich: ich, gelesenAm: gelesenAm, zustellText: zustellText)
            }
            .padding(.top, nachricht.reaktionen.isEmpty ? 0 : 16)
            // Quick fix: the reply swipe starts only on the bubble plus 12 pt around it, not on the
            // empty part of the row. `.simultaneousGesture` (not `.gesture`) so it never steals the
            // ScrollView's vertical pan; the width-vs-height check ignores ordinary scroll touches.
            .padding(12)
            .contentShape(.rect)
            .simultaneousGesture(wischGeste)
            .padding(-12)
            if !eigene { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 10)
        .offset(x: wischOffset)
        .background(alignment: .leading) { antwortPfeil }
        .background(alignment: .trailing) { wischZeit }
        .modifier(Aufstieg(aktiv: eigene && Date().timeIntervalSince(nachricht.zeit) < 2))
        .accessibilityAction(named: "Antworten") { aktionen.antworten(nachricht) }
        .accessibilityAction(named: "Mit Herz reagieren") { herzReaktion() }
        .accessibilityAction(named: "Reaktionen und Optionen") { fokussieren() }
    }

    private var blase: some View {
        NachrichtBlase(nachricht: nachricht, ich: ich, stapel: stapel, schwanz: layout.gruppenEnde)
            // Gemerkt (both see it): soft rose glow. Own star: yellow glow + badge.
            .shadow(color: hervorhebung.opacity(0.7), radius: hervorhebung == .clear ? 0 : 7)
            .overlay(alignment: eigene ? .bottomLeading : .bottomTrailing) {
                if !nachricht.gemerkt.isEmpty || nachricht.gesternt.contains(ich) {
                    HStack(spacing: 2) {
                        if !nachricht.gemerkt.isEmpty { Image(systemName: "bookmark.fill").foregroundStyle(Color.loveaRose) }
                        if nachricht.gesternt.contains(ich) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    }
                    .font(.caption2.weight(.bold))
                    .padding(4)
                    .background(.ultraThinMaterial, in: .capsule)
                    .offset(x: eigene ? -10 : 10, y: 6)
                    .accessibilityHidden(true)
                }
            }
            .animation(Feder.weich, value: nachricht.gemerkt)
            .overlay { herzPop }
            .overlay(alignment: eigene ? .topLeading : .topTrailing) {
                ReaktionsAbzeichen(nachricht: nachricht, ich: ich)
                    .offset(x: eigene ? -12 : 12, y: -18)
            }
            .onGeometryChange(for: CGRect.self) { geo in geo.frame(in: .global) } action: { rahmen.wert = $0 }
            .onTapGesture(count: 2) { herzReaktion() }
            .onTapGesture { if !LangDruck.geradeEben { effektNochmal(); merkenTippen() } }
            // Fix round 3: simultaneous, not `.onLongPressGesture`. Photos, videos, snaps and letters
            // carry their own tap gesture; SwiftUI let that child tap win over an exclusive parent
            // long press, so holding a photo often opened nothing. `LangDruck` stops the child tap
            // that ends the same touch.
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in fokussieren() })
            .onAppear { ChatEffektSpieler.shared.erstesSehen(nachricht) }
    }

    private func zitat(_ id: String) -> some View {
        Button { aktionen.springen(id) } label: {
            Label(ChatModell.shared.nachricht(id).map(ChatVorschau.inhalt) ?? "Antwort", systemImage: "arrowshape.turn.up.left.fill")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(uiColor: .secondarySystemBackground).opacity(0.9), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Zur beantworteten Nachricht springen")
    }

    private var herzPop: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 44))
            .foregroundStyle(.red)
            .shadow(color: .black.opacity(0.25), radius: 4)
            .scaleEffect(herzSichtbar ? 1 : 0.3)
            .opacity(herzSichtbar ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var antwortPfeil: some View {
        Image(systemName: "arrowshape.turn.up.left.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.loveaRose)
            .scaleEffect(wischOffset >= Self.antwortSchwelle ? 1.15 : 0.8)
            .opacity(Double(max(wischOffset, 0) / Self.antwortSchwelle))
            .animation(Feder.schnell, value: wischOffset >= Self.antwortSchwelle)
            .accessibilityHidden(true)
    }

    private var wischZeit: some View {
        Text(nachricht.zeit.formatted(date: .omitted, time: .shortened))
            .font(.caption2).foregroundStyle(.secondary)
            .opacity(Double(max(-wischOffset, 0) / 50))
            .accessibilityHidden(true)
    }

    private var wischGeste: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onChanged { wert in
                // The left 32 pt belong to the leave-chat swipe (`Unterhaltung.randGeste`).
                guard wert.startLocation.x > 32, abs(wert.translation.width) > abs(wert.translation.height) else { return }
                let breite = wert.translation.width
                let neu = breite > 0 ? min(breite * 0.8, 84) : max(breite * 0.8, -64)
                if wischOffset < Self.antwortSchwelle, neu >= Self.antwortSchwelle { Haptik.mittel() }
                wischOffset = neu
            }
            .onEnded { _ in
                if wischOffset >= Self.antwortSchwelle { aktionen.antworten(nachricht) }
                withAnimation(Feder.schnell) { wischOffset = 0 }
            }
    }

    /// Double tap (Spec 2.4): ❤️ pops with a spring; again removes it.
    private func herzReaktion() {
        let herz = Reaktion.emoji("❤️")
        let entfernt = nachricht.reaktionen[ich] == herz.wert
        ChatModell.shared.reagierenUmschalten(nachricht, herz, ich: ich)
        Haptik.mittel()
        guard !entfernt else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Feder.federnd) { herzSichtbar = true }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(Feder.weich) { herzSichtbar = false }
        }
    }

    private var hervorhebung: Color {
        if !nachricht.gemerkt.isEmpty { return .loveaRose }
        if nachricht.gesternt.contains(ich) { return .yellow }
        return .clear
    }

    /// Single tap keeps/unkeeps the message for both. 0.5 s lock per message so it can't be spammed.
    private func merkenTippen() {
        guard MerkSperre.frei(nachricht.id) else { return }
        ChatModell.shared.merkenSetzen(nachricht.id, an: !nachricht.gemerkt.contains(ich))
        Haptik.leicht()
    }

    private func effektNochmal() {
        guard let effekt = nachricht.effekt else { return }
        ChatEffektSpieler.shared.spielen(effekt)
    }

    private func fokussieren() {
        LangDruck.merken()
        Haptik.leicht()
        let ids = (stapel.isEmpty ? [nachricht] : stapel).map(\.id)
        aktionen.fokussieren(ChatFokus(id: nachricht.id, stapel: ids, rahmen: rahmen.wert))
    }
}

/// The bubble's global frame, written on every layout change without re-rendering the row.
@MainActor
final class RahmenBox {
    var wert: CGRect = .zero
}

/// Z-32.4 "Senden: Die Blase steigt aus dem Feld an ihren Platz" — a fresh own row rises with the
/// spring once; everything else draws as is.
private struct Aufstieg: ViewModifier {
    let aktiv: Bool
    @State private var gelandet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let wartet = aktiv && !gelandet
        content
            .offset(y: wartet && !reduceMotion ? 36 : 0)
            .scaleEffect(wartet && !reduceMotion ? 0.92 : 1, anchor: .bottomTrailing)
            .opacity(wartet ? 0 : 1)
            .onAppear {
                guard aktiv, !gelandet else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Feder.federnd) { gelandet = true }
            }
    }
}

/// Z-33.3 unsend: the bubble puffs away (scale up, blur, fade).
private struct PuffWirkung: ViewModifier {
    let aktiv: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(aktiv ? 1.25 : 1)
            .blur(radius: aktiv ? 14 : 0)
            .opacity(aktiv ? 0 : 1)
    }
}

extension AnyTransition {
    static var puff: AnyTransition {
        .asymmetric(insertion: .opacity, removal: .modifier(active: PuffWirkung(aktiv: true), identity: PuffWirkung(aktiv: false)))
    }
}

/// The message itself, without row gestures: text in a `BlasenForm` bubble, photos/GIFs/stickers
/// without one (like iMessage), emoji-only text large and bare.
struct NachrichtBlase: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    var stapel: [ChatModell.Nachricht] = []
    let schwanz: Bool
    @Environment(\.chatBackdrop) private var festerBackdrop

    private var eigene: Bool { nachricht.von == ich }
    private var backdrop: Backdrop { festerBackdrop ?? Backdrops.aktuell }
    private var alleMedien: [ChatModell.MedienEintrag] { stapel.count > 1 ? stapel.flatMap(\.medien) : nachricht.medien }
    private var text: String { nachricht.text ?? "" }

    var body: some View {
        if ChatStapel.istBild(nachricht) && alleMedien.count > 1 {
            FotoStapel(medien: alleMedien, eigene: eigene)
        } else {
            VStack(alignment: eigene ? .trailing : .leading, spacing: 4) {
                medienTeil
                textTeil
            }
        }
    }

    @ViewBuilder private var medienTeil: some View {
        let mitSchwanz = schwanz && text.isEmpty
        if let snap = nachricht.snap {
            SnapZeile(nachricht: nachricht, snap: snap, ich: ich, eigene: eigene, schwanz: mitSchwanz, backdrop: backdrop)
        } else if let medium = nachricht.medien.first {
            if medium.typ == "sprache" {
                SprachBlase(medium: medium).blase(eigene: eigene, schwanz: mitSchwanz, backdrop: backdrop)
            } else {
                MedienNachrichtView(medium: medium, eigene: eigene)
            }
        }
        if let gif = nachricht.gif, let url = URL(string: gif.url) {
            AnimiertesGif(url: url)
                .frame(width: 200, height: gif.breite > 0 && gif.hoehe > 0 ? min(200 * gif.hoehe / gif.breite, 240) : 200)
                .clipShape(.rect(cornerRadius: 18))
        }
        if let sticker = nachricht.sticker {
            StickerKachel(medienId: sticker.medienId).frame(width: 140, height: 140)
        }
        if nachricht.spiel != nil {
            Label("Spiel", systemImage: "gamecontroller.fill").blase(eigene: eigene, schwanz: mitSchwanz, backdrop: backdrop)
        }
    }

    @ViewBuilder private var textTeil: some View {
        if !text.isEmpty {
            if Self.nurEmoji(text) {
                Text(text)
                    .font(.system(size: 48))
                    .accessibilityLabel("\(eigene ? "Du" : nachricht.von.name): \(text)")
            } else {
                // Who wrote it is otherwise only colour and side (Z-16.3).
                Text(text)
                    .font(.body)
                    .blase(eigene: eigene, schwanz: schwanz, backdrop: backdrop)
                    .accessibilityLabel("\(eigene ? "Du" : nachricht.von.name): \(text)")
            }
            if let url = ersterLink(in: text) {
                LinkVorschau(url: url)
                    .frame(maxWidth: 260)
                    .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    /// One to three emoji and nothing else: shown large without a bubble.
    static func nurEmoji(_ text: String) -> Bool {
        let zeichen = text.filter { !$0.isWhitespace }
        return (1...3).contains(zeichen.count) && zeichen.allSatisfy(Reaktion.istEmoji)
    }
}

/// Below the bubble: "bearbeitet" (tap → earlier versions), the effect (tap → replay), the read
/// head of the partner (tap → "Gelesen HH:mm") or "Zugestellt".
private struct NachrichtFusszeile: View {
    let nachricht: ChatModell.Nachricht
    let ich: Person
    let gelesenAm: Date?
    let zustellText: String?
    @State private var fassungenOffen = false
    @State private var gelesenZeigen = false

    var body: some View {
        if nachricht.bearbeitet || nachricht.effekt != nil || gelesenAm != nil || zustellText != nil {
            HStack(spacing: 10) {
                if nachricht.bearbeitet { bearbeitetKnopf }
                if let effekt = nachricht.effekt {
                    Button { ChatEffektSpieler.shared.spielen(effekt) } label: {
                        Label(effekt.titel, systemImage: effekt.symbol)
                    }
                    .accessibilityHint("Effekt erneut abspielen")
                }
                if let gelesenAm { lesekopf(gelesenAm) }
                if let zustellText { Text(zustellText) }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }

    private var bearbeitetKnopf: some View {
        Button("bearbeitet") { fassungenOffen = true }
            .disabled(nachricht.fassungen.isEmpty)
            .accessibilityHint("Frühere Fassungen zeigen")
            .popover(isPresented: $fassungenOffen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frühere Fassungen").font(.headline)
                    ForEach(Array(nachricht.fassungen.enumerated()), id: \.offset) { _, alt in
                        Text(alt).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text(nachricht.text ?? "")
                }
                .padding()
                .frame(maxWidth: 300, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
    }

    private func lesekopf(_ zeit: Date) -> some View {
        Button {
            Haptik.auswahl()
            withAnimation(Feder.schnell) { gelesenZeigen.toggle() }
        } label: {
            HStack(spacing: 4) {
                if gelesenZeigen { Text("Gelesen " + zeit.formatted(date: .omitted, time: .shortened)) }
                KopfFigur(person: ich.partner, groesse: 18, animiert: false)
            }
            .frame(minHeight: 28)
            .contentShape(.rect)
        }
        .accessibilityLabel("Gelesen " + zeit.formatted(date: .omitted, time: .shortened))
    }
}

/// The snap row (Z-6.3): before viewing, a tappable "Snap" bubble; after, a text-only spur
/// ("Snap angesehen"/"Snap lange angesehen") unless `bleibt` or saved — those show the real photo
/// like any other medium. "Erneut ansehen" and "Speichern" live in the long-press menu.
private struct SnapZeile: View {
    let nachricht: ChatModell.Nachricht
    let snap: ChatModell.SnapInfo
    let ich: Person
    let eigene: Bool
    let schwanz: Bool
    let backdrop: Backdrop

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
                // Snaps replay without limit: the spur stays tappable ("nochmal" for the receiver).
                spur(nachricht.snapLange ? "Snap lange angesehen" : (eigene ? "Snap angesehen" : "Snap angesehen · nochmal"))
            } else {
                spur(eigene ? "Snap" : "Snap ansehen")
            }
        }
        .fullScreenCover(isPresented: $vollbild) {
            SnapViewer(nachricht: nachricht, ich: ich)
        }
    }

    // A tap gesture, not a Button: a Button inside the bubble would swallow the long press.
    // Snapchat colours: red square for a photo snap, purple for a video snap (camera or gallery).
    private func spur(_ text: String) -> some View {
        let farbe = SnapFarbe.farbe(istVideo: nachricht.medien.first?.typ == "video")
        return HStack(spacing: 6) {
            // White backing: stays visible on a rose/red own-bubble gradient.
            Image(systemName: nachricht.snapAngesehen ? "square" : "square.fill")
                .foregroundStyle(farbe)
                .padding(3)
                .background(.white, in: .rect(cornerRadius: 5))
            Text(text)
        }
        .font(.subheadline.weight(.medium))
        .blase(eigene: eigene, schwanz: schwanz, backdrop: backdrop)
        .contentShape(.rect)
        .onTapGesture {
            guard !LangDruck.geradeEben else { return }
            Haptik.leicht()
            vollbild = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((nachricht.medien.first?.typ == "video" ? "Video-Snap, " : "Foto-Snap, ") + text)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { vollbild = true }
    }
}

/// Snapchat's snap colours, the same for camera and gallery snaps.
enum SnapFarbe {
    static let foto = Color(red: 0.95, green: 0.24, blue: 0.34)
    static let video = Color(red: 0.63, green: 0.36, blue: 0.80)
    static func farbe(istVideo: Bool) -> Color { istVideo ? video : foto }
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

/// ponytail: in-memory per-message cooldown; resets on app restart, which is fine for anti-spam.
@MainActor
enum MerkSperre {
    private static var zuletzt: [String: Date] = [:]
    static func frei(_ id: String, jetzt: Date = Date()) -> Bool {
        if let t = zuletzt[id], jetzt.timeIntervalSince(t) < 0.5 { return false }
        zuletzt[id] = jetzt
        return true
    }
}
