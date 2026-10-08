import Observation
import SwiftUI
import TipKit

/// Chat tab: a one-row inbox (Ahmed's wish, like Snapchat/iMessage) that pushes the full-screen
/// conversation. Jumps from `AppNavigation` (`chatZiel`, `chatSuche`, `kameraOeffnen`) open the
/// conversation straight away; it handles them itself, and back returns to this list.
struct ChatTab: View {
    @State private var offen = false

    var body: some View {
        NavigationStack {
            if let ich = Raum.shared.ich {
                ChatListe(ich: ich) { offen = true }
                    .gymLeisteOben()
                    // Follows `offen`: hidden in the conversation, back at once on the pop.
                    .toolbar(offen ? .hidden : .visible, for: .tabBar)
                    // R6: nur auf der Liste, nicht in der offenen Unterhaltung (dort ist der
                    // Rand-Wisch "zurück").
                    .tabWischen(vorheriger: "home", naechster: "drawing")
                    .navigationDestination(isPresented: $offen) {
                        Unterhaltung(ich: ich) { offen = false }
                    }
            } else {
                ContentUnavailableView("Chat", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .onChange(of: AppNavigation.shared.chatZiel, initial: true) { _, ziel in if ziel != nil { offen = true } }
        .onChange(of: AppNavigation.shared.chatSuche, initial: true) { _, an in if an { offen = true } }
        .onChange(of: AppNavigation.shared.kameraOeffnen, initial: true) { _, an in if an { offen = true } }
        .onChange(of: AppNavigation.shared.gespraechOeffnen, initial: true) { _, an in if an { offen = true; AppNavigation.shared.gespraechOeffnen = false } }
        .onChange(of: AppNavigation.shared.partnerProfilOeffnen, initial: true) { _, an in if an { offen = true } }
        .onChange(of: offen) { _, auf in if auf { ChatPerf.shared.oeffnenBeginn() } }
    }
}

/// The inbox: large title "Chat" and one big row for the partner. Keeps the camera warm like the
/// conversation does, so a snap from here is instant too.
private struct ChatListe: View {
    let ich: Person
    let onOeffnen: () -> Void
    private let modell = ChatModell.shared
    @State private var adresse: String?

    var body: some View {
        let partner = ich.partner
        ScrollView {
            Button {
                Haptik.leicht()
                onOeffnen()
            } label: {
                TimelineView(.everyMinute) { _ in
                    let letzte = modell.nachrichten.last { !$0.geloescht && ChatModell.sichtbar($0) }
                    ChatListenZeile(
                        partner: partner,
                        vorschau: ChatListenZeile.vorschau(letzte, ich: ich, tippt: FigurenModell.shared.anzeige(partner).haupt == .tippt),
                        zeit: letzte.map { ZeitText.relativ($0.zeit) },
                        ungelesen: modell.ungelesen(fuer: ich),
                        ort: PartnerOrt.text(partner, adresse: adresse),
                        online: Raum.shared.partnerDa,
                        gesehen: letzte.flatMap { $0.von == ich && $0.system == nil ? ($0.zeit <= (modell.gelesenBis[partner] ?? .distantPast)) : nil }
                    )
                }
            }
            .buttonStyle(.federnd)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .top, spacing: 0) { SyncStatusZeile() }
        .task(id: PartnerOrt.adressSchluessel(partner)) {
            if let neu = await PartnerOrt.adresseLaden(partner) { adresse = neu }
        }
        .onAppear {
            StartProtokoll.marke("screen.chatListe")
            SnapKameraSteuerung.geteilt.halten()
            Task { await SnapKameraSteuerung.geteilt.vorwaermen() }
        }
        .onDisappear { SnapKameraSteuerung.geteilt.loslassen() }
    }
}

/// The partner's row: live figure with online ring, name, time, last message (or "Tippt …"),
/// unread badge, and where the partner is as a quiet second line.
struct ChatListenZeile: View {
    let partner: Person
    let vorschau: String
    let zeit: String?
    let ungelesen: Int
    let ort: String?
    let online: Bool
    /// Own last message: false = "Zugestellt", true = "Gesehen"; nil when the last one is hers.
    var gesehen: Bool? = nil
    var animiert = true

    var body: some View {
        HStack(spacing: 14) {
            KopfFigur(person: partner, groesse: 58, animiert: animiert)
                .padding(4)
                .overlay(Circle().strokeBorder(online ? Color.green : Color.clear, lineWidth: 2.5))
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(partner.name).font(.title3.weight(.semibold)).foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if let zeit {
                        Text(zeit).font(.caption).foregroundStyle(ungelesen > 0 ? Color.loveaRose : Color.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Text(vorschau)
                        .font(.subheadline.weight(ungelesen > 0 ? .semibold : .regular))
                        .foregroundStyle(ungelesen > 0 ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let gesehen {
                        Label(gesehen ? "Gesehen" : "Zugestellt", systemImage: gesehen ? "eye.fill" : "checkmark")
                            .font(.caption.weight(gesehen ? .semibold : .regular))
                            .foregroundStyle(gesehen ? Color.loveaRose : Color.secondary)
                            .labelStyle(.titleAndIcon)
                            .fixedSize()
                    }
                    if ungelesen > 0 {
                        Text("\(ungelesen)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Color.loveaRose, in: .capsule)
                    }
                }
                if let ort {
                    Label(ort, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beschreibung)
        .accessibilityHint("Chat öffnen")
        .accessibilityAddTraits(.isButton)
    }

    private var beschreibung: String {
        var teile = [partner.name, online ? "online" : nil, vorschau, zeit, ort].compactMap { $0 }
        if let gesehen { teile.append(gesehen ? "gesehen" : "zugestellt") }
        if ungelesen > 0 { teile.append("\(ungelesen) ungelesen") }
        return teile.joined(separator: ", ")
    }

    /// Preview text: "Tippt …" live, else the last message (own ones start with "Du: ").
    static func vorschau(_ letzte: ChatModell.Nachricht?, ich: Person, tippt: Bool) -> String {
        if tippt { return "Tippt …" }
        guard let letzte else { return "Noch keine Nachrichten" }
        return (letzte.von == ich && letzte.system == nil ? "Du: " : "") + ChatVorschau.inhalt(letzte)
    }
}

/// Every sheet and cover of the conversation in one place.
struct ChatBlaetter {
    var profil = false
    var kamera = false
    var bearbeiten: ChatModell.Nachricht?
    var reaktionen: ChatModell.Nachricht?
    var snap: ChatModell.Nachricht?
}

// MARK: - Conversation

private struct Unterhaltung: View {
    let ich: Person
    /// Back to the chat list (header chevron, native iOS back swipe).
    let onZurueck: () -> Void
    private let modell = ChatModell.shared

    @State private var zielID: String?
    @State private var antwortAuf: ChatModell.Nachricht?
    @State private var fokus: ChatFokus?
    @State private var blatt = ChatBlaetter()
    @State private var sucheAktiv = false
    @State private var breite: CGFloat = 390
    /// Short confirmation under the header ("In Aufnahmen gespeichert").
    @State private var toast: String?

    var body: some View {
        NachrichtenListe(modell: modell, ich: ich, zielID: $zielID, aktionen: aktionen)
            // Ahmed 25.09.: no blurred band above the header or behind the input, the backdrop and
            // the bubbles stay visible up to the glass controls.
            .scrollEdgeEffectHidden(true, for: [.top, .bottom])
            .safeAreaBar(edge: .top, spacing: 0) { oben }
            .safeAreaBar(edge: .bottom, spacing: 0) { unten }
            .background { ChatHintergrundAnsicht(ich: ich) }
            .overlay { ChatEffektEbene() }
            // R6: the per-row bubble frame used to be tracked continuously via `.global`
            // `onGeometryChange` (every visible row, every scroll frame). Rows now publish an
            // `Anchor<CGRect>` instead (cheap — no coordinate-space walk until resolved); this
            // reads the whole published dictionary and resolves exactly the pressed bubble's
            // anchor, once, inside `NachrichtFokusEbene`'s own `GeometryReader`.
            .overlayPreferenceValue(BubbleAnkerKey.self) { anker in fokusEbene(anker) }
            // Chat-Tempo: one backdrop lookup for the whole list instead of 3-4 per bubble, each of
            // which also watched every shared setting. nil (switch off) = every bubble looks it up.
            .environment(\.chatBackdrop, ChatTempo.an ? Backdrops.aktuell : nil)
            .environment(\.chatBreite, breite)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { breite = $0 }
            .toolbar(.hidden, for: .navigationBar)
            // The open conversation is full screen; the tab bar returns on the chat list.
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden()
            .modifier(UnterhaltungBlaetter(ich: ich, blatt: $blatt))
            .modifier(Lesebestaetigung(ich: ich, modell: modell))
            .screenshotKontext(.chat)
            .modifier(Spruenge(modell: modell, zielID: $zielID, sucheAktiv: $sucheAktiv, blatt: $blatt))
            .task { ReaktionsBilder.shared.vorwaermen(ich) }
    }

    private var aktionen: ChatZeilenAktionen {
        ChatZeilenAktionen(
            antworten: { nachricht in
                Haptik.leicht()
                antwortAuf = nachricht
            },
            springen: { zielID = $0 },
            fokussieren: { ziel in
                withAnimation(Feder.schnell) { fokus = ziel }
            }
        )
    }

    /// Back to the chat list from the header; the native iOS swipe pops the same destination.
    private func zurueck() {
        Haptik.leicht()
        ChatTastatur.schliessen()
        onZurueck()
    }

    private var oben: some View {
        VStack(spacing: 6) {
            ChatKopf(partner: ich.partner, modell: modell, onZurueck: zurueck) { blatt.profil = true }
            TipView(ChatNachrichtGesteTip())
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation(Feder.weich) { self.toast = nil }
                    }
            }
            if sucheAktiv {
                ChatSuchleiste(modell: modell, onSpringeZu: { zielID = $0 }) {
                    withAnimation(Feder.schnell) { sucheAktiv = false }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            ChatAngeheftetLeiste(modell: modell) { zielID = $0 }
            SyncStatusZeile()
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 4)
        .tastaturWischen()
    }

    private var unten: some View {
        VStack(spacing: 0) {
            PartnerFigurLeiste(partner: ich.partner)
            ChatEingabeleiste(ich: ich, antwortAuf: $antwortAuf)
        }
        // Transparent, but bubbles under the input area don't take taps (the header area does).
        .contentShape(Rectangle())
        .tastaturWischen()
    }

    /// `anker` only has entries for bubbles currently in the `LazyVStack` — guards the rare case a
    /// scrolled-away row's anchor vanished right as the long press fired.
    @ViewBuilder private func fokusEbene(_ anker: [String: Anchor<CGRect>]) -> some View {
        if let fokus, let nachricht = modell.nachricht(fokus.id), let bubbleAnker = anker[fokus.id] {
            NachrichtFokusEbene(fokus: fokus, anker: bubbleAnker, nachricht: nachricht, ich: ich) { wunsch in
                erfuellen(wunsch, nachricht)
            } onSchliessen: {
                self.fokus = nil
            }
        }
    }

    private func erfuellen(_ wunsch: FokusWunsch, _ nachricht: ChatModell.Nachricht) {
        switch wunsch {
        case .antworten:
            Haptik.leicht()
            antwortAuf = nachricht
        case .bearbeiten: blatt.bearbeiten = nachricht
        case .reaktionen: blatt.reaktionen = nachricht
        case .snapAnsehen: blatt.snap = nachricht
        case .aufnahmenSpeichern:
            let ids = fokus?.stapel ?? [nachricht.id]
            Task { await inAufnahmenSpeichern(ids) }
        }
    }

    /// Fix round 3: save straight from the bubble, then haptic + toast, and a grey line for the partner.
    private func inAufnahmenSpeichern(_ ids: [String]) async {
        let medien = ids.compactMap { modell.nachricht($0) }.flatMap(\.medien).filter { $0.typ == "foto" || $0.typ == "video" }
        guard !medien.isEmpty else { return }
        do {
            try await AufnahmenSpeichern.speichern(medien)
            Haptik.erfolg()
            zeigen(medien.count > 1 ? "\(medien.count) in Aufnahmen gespeichert" : "In Aufnahmen gespeichert")
            let nurVideo = medien.allSatisfy { $0.typ == "video" }
            modell.snapAufnahmeSenden(ids.first ?? "chat", art: nurVideo ? ChatHinweis.gespeichertVideo : ChatHinweis.gespeichertFoto)
        } catch AufnahmenSpeichern.Fehler.keineErlaubnis {
            Haptik.warnung()
            zeigen("Kein Zugriff auf Fotos. In den Einstellungen erlauben.")
        } catch {
            Haptik.warnung()
            zeigen("Speichern hat nicht geklappt")
        }
    }

    private func zeigen(_ text: String) {
        withAnimation(Feder.federnd) { toast = text }
    }
}

private struct UnterhaltungBlaetter: ViewModifier {
    let ich: Person
    @Binding var blatt: ChatBlaetter

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $blatt.profil) { PartnerProfilView(person: ich.partner) }
            .fullScreenCover(isPresented: $blatt.kamera) {
                SnapKameraFluss(ich: ich, antwortAuf: nil) { blatt.kamera = false }
            }
            .fullScreenCover(item: $blatt.snap) { SnapViewer(nachricht: $0, ich: ich) }
            .sheet(item: $blatt.bearbeiten) { BearbeitenBlatt(nachricht: $0) }
            .sheet(item: $blatt.reaktionen) { ReaktionenBlatt(nachricht: $0, ich: ich) }
    }
}

/// Read receipts, the "im Chat" figure state and the arrival haptic belong to the open conversation.
private struct Lesebestaetigung: ViewModifier {
    let ich: Person
    let modell: ChatModell
    @State private var sichtbar = false
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear {
                StartProtokoll.marke("screen.gespraech")
                sichtbar = true
                leseBestaetigen()
                FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
            }
            // Z-33.5: leaving the tab used to leave the partner seeing "ist im Chat" until the next
            // screen reported something. Covers (camera, viewer) send their own state right after.
            .onDisappear {
                sichtbar = false
                Anwesenheit.shared.appEnde(.imChat, .tippt)
            }
            .onChange(of: scenePhase) { _, _ in leseBestaetigen() }
            .onChange(of: modell.nachrichten.count) { _, _ in
                leseBestaetigen()
                // Only a fresh partner message while looking at it, not a reconnect backlog or own send.
                if sichtbar, scenePhase == .active, let letzte = modell.nachrichten.last, letzte.von != ich,
                   Date().timeIntervalSince(letzte.zeit) < 10 {
                    ChatHaptik.weich()
                }
            }
            // Z-33.5: an upload that failed offline is retried as soon as the socket is back, not
            // only on the next chat appear.
            .onChange(of: Raum.shared.verbunden) { _, verbunden in
                guard verbunden else { return }
                Task { await ChatMedien.ausstehendeAbarbeiten() }
            }
    }

    /// Sends `nachricht.gelesen` only while the conversation is on screen and the app is active,
    /// and only up to the newest partner message — not `Date()`, which a clock-skewed partner
    /// device could read as "not yet sent" and leave the badge stuck forever (Z-4.6).
    private func leseBestaetigen() {
        guard sichtbar, scenePhase == .active, modell.ungelesen(fuer: ich) > 0 else { return }
        guard let letztePartnerZeit = modell.nachrichten.last(where: { $0.von != ich })?.zeit else { return }
        modell.gelesenSenden(bis: letztePartnerZeit)
    }
}

/// `AppNavigation` jumps into the conversation (Z-32.1).
private struct Spruenge: ViewModifier {
    let modell: ChatModell
    @Binding var zielID: String?
    @Binding var sucheAktiv: Bool
    @Binding var blatt: ChatBlaetter

    func body(content: Content) -> some View {
        content
            // Profile → "Kamera": close the profile first; a cover can't present while a sheet is closing.
            .onChange(of: AppNavigation.shared.kameraOeffnen, initial: true) { _, an in
                guard an else { return }
                AppNavigation.shared.kameraOeffnen = false
                let warten = blatt.profil
                blatt.profil = false
                Task {
                    if warten { try? await Task.sleep(for: .milliseconds(500)) }
                    blatt.kamera = true
                }
            }
            // Profile → "Im Chat suchen".
            .onChange(of: AppNavigation.shared.chatSuche, initial: true) { _, an in
                guard an else { return }
                AppNavigation.shared.chatSuche = false
                blatt.profil = false
                withAnimation(Feder.schnell) { sucheAktiv = true }
            }
            // Notification tap, "Heute vor …": waits until the message has arrived (a cold start
            // replays the log, the catch-up follows).
            .onChange(of: AppNavigation.shared.chatZiel, initial: true) { _, _ in zielPruefen() }
            .onChange(of: modell.nachrichten.count) { _, _ in zielPruefen() }
            // Kuss/Anstupsen/Herz-Push angetippt: Partnerprofil öffnen (25.09.).
            .onChange(of: AppNavigation.shared.partnerProfilOeffnen, initial: true) { _, an in
                guard an else { return }
                AppNavigation.shared.partnerProfilOeffnen = false
                blatt.profil = true
            }
    }

    private func zielPruefen() {
        guard let ziel = AppNavigation.shared.chatZiel, modell.nachricht(ziel) != nil else { return }
        AppNavigation.shared.chatZiel = nil
        blatt.profil = false
        zielID = ziel
    }
}

/// Search mode (Block 18): newest hit first, arrows step through older/newer hits, the list
/// scrolls there and highlights the bubble.
private struct ChatSuchleiste: View {
    let modell: ChatModell
    let onSpringeZu: (String) -> Void
    let onFertig: () -> Void

    @State private var text = ""
    @State private var treffer: [String] = []
    @State private var index = 0
    @FocusState private var fokus: Bool

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Im Chat suchen", text: $text)
                    .focused($fokus)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { suchen() }
                if !text.isEmpty {
                    Text(treffer.isEmpty ? "0" : "\(index + 1)/\(treffer.count)")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .glassEffect(.regular, in: .capsule)

            Button { springe(-1) } label: { Image(systemName: "chevron.up").frame(width: 44, height: 44) }
                .disabled(treffer.count < 2)
                .accessibilityLabel("Älterer Treffer")
            Button { springe(1) } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                .disabled(treffer.count < 2)
                .accessibilityLabel("Neuerer Treffer")
            Button("Fertig") { onFertig() }
                .fontWeight(.semibold)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 12)
        .onChange(of: text) { _, _ in suchen() }
        // Focus set right away is dropped while the profile sheet is still closing.
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            fokus = true
        }
    }

    private func suchen() {
        treffer = modell.suchen(text)
        index = max(treffer.count - 1, 0)
        if let id = treffer.last { onSpringeZu(id) }
    }

    private func springe(_ richtung: Int) {
        guard !treffer.isEmpty else { return }
        index = (index + richtung + treffer.count) % treffer.count
        Haptik.auswahl()
        onSpringeZu(treffer[index])
    }
}

/// Message history (Z-4.2): date separators, time groups, photo stacks, anchored to the bottom.
/// Shows the newest `anzahl` messages; pulling down at the top (or the button there) loads older ones.
private struct NachrichtenListe: View {
    let modell: ChatModell
    let ich: Person
    @Binding var zielID: String?
    let aktionen: ChatZeilenAktionen

    @State private var fenster = ChatListenFenster()
    @State private var hervorID: String?
    // R7: true while the user is actively dragging the list — including an interactive keyboard
    // dismiss, which is the same drag. See `ListenAutoScroll`.
    @State private var nutzerZiehtGerade = false

    var body: some View {
        let alle = modell.nachrichten
        let sichtbar = Array(alle.suffix(fenster.anzahl))
        let vorFenster = alle.count > sichtbar.count ? alle[alle.count - sichtbar.count - 1] : nil
        let gruppen = ChatStapel.gruppieren(sichtbar)
        // Once per render, not one backwards scan per built row (Z-16.2, 10,000 messages).
        let status = LeseStatus(nachrichten: alle, ich: ich, gelesenBisPartner: modell.gelesenBis[ich.partner])
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if alle.count > sichtbar.count { aeltereKnopf }
                    ForEach(Array(gruppen.enumerated()), id: \.element.id) { eintrag in
                        zeile(eintrag.offset, gruppen: gruppen, vorFenster: vorFenster, status: status)
                    }
                }
                .padding(.vertical, 8)
            }
            // Z-35: `scrollEdgeEffectHidden` above means no blur band under the header, so an
            // overscrolled bubble used to slide straight up under the status bar and collide with
            // the clock, and show through the glass header capsule. A static top fade (no per-frame
            // work — GPU composites the mask once) hides content before it reaches that zone.
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 70)
                    Color.black
                }
            }
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { ChatTastatur.schliessen() })
            // R7: interactive keyboard dismiss is a drag on this same list — `.tracking`/
            // `.interacting` cover it. Only `.idle`/`.decelerating`/`.animating` count as "not the
            // user's own gesture right now" for `ListenAutoScroll` below.
            .onScrollPhaseChange { _, neu in
                nutzerZiehtGerade = neu == .tracking || neu == .interacting
                // Chat-Tempo: the leaf views that animate (particles, figures, GIFs) calm down while it moves.
                if ChatTempo.an { ChatTempo.shared.phase(neu) }
            }
            .onDisappear { ChatTempo.shared.zuruecksetzen() }
            // Captures only the two main-actor objects, not the view, in the `@Sendable` action.
            .refreshable { [fenster, modell] in await fenster.mehr(modell) }
            .onChange(of: zielID) { _, id in
                guard let id else { return }
                zielID = nil
                springen(zu: id, proxy: proxy)
            }
            // Open at the very bottom. `defaultScrollAnchor(.bottom)` sets that position from the
            // first frame; `for: .sizeChanges` (added later, below) keeps re-anchoring to the
            // bottom as photos reserve/load their space, which is what the old triple re-pin
            // (0/150/500 ms, chat-tempo-befund.md #2) used to paper over by brute-force polling —
            // that cost up to 650 ms of visible re-settling on every open. One immediate,
            // non-animated scroll covers the very first layout pass, before the anchor modifiers
            // have anything to anchor to; new messages arriving later are handled separately by
            // `onScrollGeometryChange`/`onChange(of: modell.nachrichten.last?.id)` below.
            .task {
                guard zielID == nil, AppNavigation.shared.chatZiel == nil, let letzte = modell.nachrichten.last?.id else { return }
                proxy.scrollTo(gruppeID(fuer: letzte), anchor: .bottom)
            }
            // Voice autoplay moved on: bring that bubble into view.
            .onChange(of: SprachSpieler.shared.autoWeiterNachricht) { _, id in
                guard let id else { return }
                withAnimation(Feder.weich) { proxy.scrollTo(gruppeID(fuer: id), anchor: .center) }
            }
            // Voice round: the bar below grew or shrank (reply bar, lines, recording panel, "ist im
            // Chat", keyboard). The inset alone keeps the offset, so the newest messages slid under
            // the bar; if the list was at the bottom before, it stays there.
            .onScrollGeometryChange(for: ListenLage.self) { geo in
                ListenLage(
                    sichtbar: geo.containerSize.height - geo.contentInsets.top - geo.contentInsets.bottom,
                    amEnde: geo.contentOffset.y + geo.containerSize.height - geo.contentInsets.bottom >= geo.contentSize.height - 24,
                    nahOben: ListenNachladen.nahOben(abstandOben: geo.contentOffset.y + geo.contentInsets.top)
                )
            } action: { alt, neu in
                // Scrolling up: the next page of older messages loads before the top is reached.
                if ListenNachladen.sollMehr(warNahOben: alt.nahOben, istNahOben: neu.nahOben, nochAelteres: modell.nachrichten.count > fenster.anzahl) {
                    aeltereLaden(proxy: proxy)
                }
                guard ListenAutoScroll.sollNachUntenSpringen(
                    sichtbarGeaendert: alt.sichtbar != neu.sichtbar, warAmEnde: alt.amEnde, nutzerZiehtGerade: nutzerZiehtGerade
                ), zielID == nil, let letzte = modell.nachrichten.last?.id else { return }
                withAnimation(Feder.schnell) { proxy.scrollTo(gruppeID(fuer: letzte), anchor: .bottom) }
            }
            // Own send: jump to the bottom like Snapchat, even when scrolled up. Not for grey
            // system rows ("hat in Aufnahmen gespeichert"): saving must leave the list where it was.
            .onAppear { ChatPerf.shared.ersteListeSichtbar() }
            // Diagnose: Server-Bestätigung verarbeitet (schließt jeden Trace einmalig ab).
            .onChange(of: ChatPerf.shared.antwortZaehler) { _, _ in ChatPerf.shared.gerendert() }
            .onChange(of: modell.nachrichten.last?.id) { _, id in
                if let id { ChatPerf.shared.lokalSichtbar(messageId: id) }
                guard let id, let letzte = modell.nachrichten.last, letzte.von == ich, letzte.system == nil else { return }
                let ziel = gruppeID(fuer: id)
                withAnimation(Feder.schnell) { proxy.scrollTo(ziel, anchor: .bottom) }
            }
        }
    }

    private var aeltereKnopf: some View {
        Button { fenster.mehr(modell) } label: {
            Label("Ältere Nachrichten", systemImage: "arrow.down")
                .font(.caption).foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func zeile(_ index: Int, gruppen: [ChatStapel.Gruppe], vorFenster: ChatModell.Nachricht?, status: LeseStatus) -> some View {
        let gruppe = gruppen[index]
        let erste = gruppe.nachrichten[0]
        if let spiel = erste.spiel {
            if SpieleModell.shared.sichtbar(spiel.id) {
                SpielKarte(nachricht: erste).padding(.top, 8).id(gruppe.id)
            }
        } else {
            let vorher = index > 0 ? gruppen[index - 1].letzte : vorFenster
            let nachher = index + 1 < gruppen.count ? gruppen[index + 1].nachrichten[0] : nil
            let ids = gruppe.nachrichten.map(\.id)
            let reihe = ChatNachrichtRow(
                nachricht: erste, ich: ich, stapel: gruppe.nachrichten,
                layout: ZeilenLayout(vorher: vorher, erste: erste, letzte: gruppe.letzte, nachher: nachher),
                gelesenAm: status.gelesenID.map { ids.contains($0) } == true ? modell.gelesenBis[ich.partner] : nil,
                zustellText: status.offen.map { ids.contains($0.id) } == true ? zustellText(status.offen) : nil,
                aktionen: aktionen
            )
            gleichBleibend(reihe)
                .background(hervorID == gruppe.id ? Color.loveaRose.opacity(0.18) : Color.clear)
                .id(gruppe.id)
        }
    }

    /// Chat-Tempo: a row whose message, neighbours and receipts are unchanged is not rebuilt when the
    /// list is (new message, read receipt, reaction elsewhere). Off = every row is rebuilt as before.
    @ViewBuilder private func gleichBleibend(_ reihe: ChatNachrichtRow) -> some View {
        if ChatTempo.an { reihe.equatable() } else { reihe }
    }

    /// "Zugestellt" once the server has it; while offline "Wartet auf Netz" (Z-33.5).
    private func zustellText(_ nachricht: ChatModell.Nachricht?) -> String? {
        guard let nachricht else { return nil }
        if nachricht.seq != nil { return "Zugestellt" }
        return Raum.shared.verbunden ? nil : "Wartet auf Netz"
    }

    /// One more page above, then the list is put back on the row that was on top, so the view does
    /// not jump when rows appear above it.
    private func aeltereLaden(proxy: ScrollViewProxy) {
        guard let anker = ChatStapel.gruppieren(Array(modell.nachrichten.suffix(fenster.anzahl))).first?.id else { return }
        fenster.mehr(modell, leise: true)
        Task {
            try? await Task.sleep(for: .milliseconds(60)) // let the widened window lay out first
            proxy.scrollTo(anker, anchor: .top)
        }
    }

    /// Target may sit inside a stack (keyed by its first message) or above the loaded window.
    private func springen(zu id: String, proxy: ScrollViewProxy) {
        let alle = modell.nachrichten
        guard let index = alle.firstIndex(where: { $0.id == id }) else { return }
        if index < alle.count - fenster.anzahl { fenster.anzahl = alle.count - index + 30 }
        Task {
            try? await Task.sleep(for: .milliseconds(60)) // let the widened window lay out first
            let ziel = gruppeID(fuer: id)
            withAnimation(Feder.weich) { proxy.scrollTo(ziel, anchor: .center) }
            hervorID = ziel
            try? await Task.sleep(for: .seconds(1.4))
            if hervorID == ziel { withAnimation(Feder.weich) { hervorID = nil } }
        }
    }

    private func gruppeID(fuer id: String) -> String {
        ChatStapel.gruppieren(Array(modell.nachrichten.suffix(fenster.anzahl))).first { gruppe in gruppe.nachrichten.contains { $0.id == id } }?.id ?? id
    }
}

/// Width and window origin of the conversation (the photo cap and the left-edge swipe need them).
/// Visible height between the bars, and whether the list sits at its bottom.
private struct ListenLage: Equatable {
    let sichtbar: CGFloat
    let amEnde: Bool
    let nahOben: Bool
}

/// How many of the newest messages the list builds; grows by one page per pull at the top.
@MainActor
@Observable
final class ChatListenFenster {
    static let seite = 150
    var anzahl = ChatListenFenster.seite

    func mehr(_ modell: ChatModell, leise: Bool = false) {
        guard modell.nachrichten.count > anzahl else { return }
        anzahl += Self.seite
        if !leise { Haptik.leicht() }
    }
}
