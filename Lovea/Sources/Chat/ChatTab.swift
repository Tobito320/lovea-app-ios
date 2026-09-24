import Observation
import SwiftUI

/// Chat tab: a one-row inbox (Ahmed's wish, like Snapchat/iMessage) that pushes the full-screen
/// conversation. Jumps from `AppNavigation` (`chatZiel`, `chatSuche`, `kameraOeffnen`) open the
/// conversation straight away; it handles them itself, and back returns to this list.
struct ChatTab: View {
    @State private var offen = false

    var body: some View {
        NavigationStack {
            if let ich = Raum.shared.ich {
                ChatListe(ich: ich) { offen = true }
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
                        online: Raum.shared.partnerDa
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
    /// Back to the chat list (header chevron, left-edge swipe).
    let onZurueck: () -> Void
    private let modell = ChatModell.shared

    @State private var zielID: String?
    @State private var antwortAuf: ChatModell.Nachricht?
    @State private var fokus: ChatFokus?
    @State private var blatt = ChatBlaetter()
    @State private var sucheAktiv = false
    @State private var flaeche = CGSize(width: 390, height: 900)
    /// Left-edge swipe back to the list: the finger's rightward distance and height (local).
    @State private var randWeg: CGFloat = 0
    @State private var randY: CGFloat = 0
    @State private var ursprung: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let randZone: CGFloat = 32
    private static let randSchwelle: CGFloat = 80
    /// Short confirmation under the header ("In Aufnahmen gespeichert").
    @State private var toast: String?

    var body: some View {
        NachrichtenListe(modell: modell, ich: ich, zielID: $zielID, aktionen: aktionen)
            .safeAreaInset(edge: .top, spacing: 0) { oben }
            .safeAreaInset(edge: .bottom, spacing: 0) { unten }
            .background { ChatHintergrundAnsicht(ich: ich) }
            .overlay { ChatEffektEbene() }
            .overlay { fokusEbene }
            .environment(\.chatVerlaufHoehe, flaeche.height)
            .environment(\.chatBreite, flaeche.width)
            .onGeometryChange(for: CGRect.self) { geo in geo.frame(in: .global) } action: { rahmen in
                flaeche = CGSize(width: rahmen.width, height: rahmen.maxY)
                ursprung = rahmen.origin
            }
            .offset(x: reduceMotion ? 0 : min(randWeg, 120) * 0.35)
            .overlay(alignment: .topLeading) { if randWeg > 0 { randPfeil } }
            // Simultaneous: taps (chevron, camera, bubbles) and the list's scrolling pass through;
            // only a rightward drag that starts in the left 32 pt counts.
            .simultaneousGesture(randGeste)
            .toolbar(.hidden, for: .navigationBar)
            // The open conversation is full screen; the tab bar returns on the chat list.
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden()
            .modifier(UnterhaltungBlaetter(ich: ich, blatt: $blatt))
            .modifier(Lesebestaetigung(ich: ich, modell: modell))
            .modifier(ChatAufnahmeHinweise())
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

    /// Back to the chat list (header chevron and left-edge swipe), so leaving never gets lost.
    private func zurueck() {
        Haptik.leicht()
        ChatTastatur.schliessen()
        onZurueck()
    }

    /// Swipe right from the left 32 pt to leave the chat. Rows ignore drags starting there (their
    /// reply swipe needs `x > 32`), so the two never compete.
    private var randGeste: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { wert in
                guard wert.startLocation.x - ursprung.x < Self.randZone,
                      wert.translation.width > abs(wert.translation.height) || randWeg > 0
                else { return }
                let weg = max(0, wert.translation.width)
                if randWeg < Self.randSchwelle, weg >= Self.randSchwelle { Haptik.leicht() }
                randWeg = weg
                randY = wert.location.y - ursprung.y
            }
            .onEnded { wert in
                guard randWeg > 0 else { return }
                if randWeg >= Self.randSchwelle || wert.predictedEndTranslation.width > 220 {
                    randWeg = 0
                    zurueck()
                } else {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Feder.schnell) { randWeg = 0 }
                }
            }
    }

    /// Circle with a chevron at the left edge: follows the finger vertically, grows with the drag and
    /// fills once past the threshold (Reduce Motion: fades only).
    private var randPfeil: some View {
        let fortschritt = min(randWeg / Self.randSchwelle, 1)
        let erreicht = randWeg >= Self.randSchwelle
        return Image(systemName: "chevron.left")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(erreicht ? Color.white : Color.primary)
            .frame(width: 44, height: 44)
            .background(erreicht ? AnyShapeStyle(Color.loveaRose) : AnyShapeStyle(.regularMaterial), in: .circle)
            .scaleEffect(reduceMotion ? 1 : 0.6 + 0.4 * fortschritt)
            .opacity(Double(fortschritt))
            .offset(x: 10 + (reduceMotion ? 0 : 24 * fortschritt), y: randY - 22)
            .animation(Feder.schnell, value: erreicht)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var oben: some View {
        VStack(spacing: 6) {
            ChatKopf(partner: ich.partner, modell: modell, onZurueck: zurueck) { blatt.profil = true }
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
        .tastaturWischen()
    }

    @ViewBuilder private var fokusEbene: some View {
        if let fokus, let nachricht = modell.nachricht(fokus.id) {
            NachrichtFokusEbene(fokus: fokus, nachricht: nachricht, ich: ich) { wunsch in
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
                sichtbar = true
                leseBestaetigen()
                FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
            }
            // Z-33.5: leaving the tab used to leave the partner seeing "ist im Chat" until the next
            // screen reported something. Covers (camera, viewer) send their own state right after.
            .onDisappear {
                sichtbar = false
                FigurenModell.shared.zustandSenden(.init(haupt: .ruhig))
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
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { ChatTastatur.schliessen() })
            // Captures only the two main-actor objects, not the view, in the `@Sendable` action.
            .refreshable { [fenster, modell] in await fenster.mehr(modell) }
            .onChange(of: zielID) { _, id in
                guard let id else { return }
                zielID = nil
                springen(zu: id, proxy: proxy)
            }
            // Own send: jump to the bottom like Snapchat, even when scrolled up.
            .onChange(of: modell.nachrichten.last?.id) { _, id in
                guard let id, modell.nachrichten.last?.von == ich else { return }
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
            ChatNachrichtRow(
                nachricht: erste, ich: ich, stapel: gruppe.nachrichten,
                layout: ZeilenLayout(vorher: vorher, erste: erste, letzte: gruppe.letzte, nachher: nachher),
                gelesenAm: status.gelesenID.map { ids.contains($0) } == true ? modell.gelesenBis[ich.partner] : nil,
                zustellText: status.offen.map { ids.contains($0.id) } == true ? zustellText(status.offen) : nil,
                aktionen: aktionen
            )
            .background(hervorID == gruppe.id ? Color.loveaRose.opacity(0.18) : Color.clear)
            .id(gruppe.id)
        }
    }

    /// "Zugestellt" once the server has it; while offline "Wartet auf Netz" (Z-33.5).
    private func zustellText(_ nachricht: ChatModell.Nachricht?) -> String? {
        guard let nachricht else { return nil }
        if nachricht.seq != nil { return "Zugestellt" }
        return Raum.shared.verbunden ? nil : "Wartet auf Netz"
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

/// How many of the newest messages the list builds; grows by one page per pull at the top.
@MainActor
@Observable
final class ChatListenFenster {
    static let seite = 150
    var anzahl = ChatListenFenster.seite

    func mehr(_ modell: ChatModell) {
        guard modell.nachrichten.count > anzahl else { return }
        anzahl += Self.seite
        Haptik.leicht()
    }
}
