import Observation
import SwiftUI

/// Chat tab (Block 18): Snapchat-style "Chats" screen with the one conversation. Tapping the row
/// pushes it, so the back button and the edge swipe from the left lead out again. Search is a mode
/// of the conversation, opened from the partner profile through `AppNavigation.shared.chatSuche`.
struct ChatTab: View {
    @State private var offen = false
    @State private var sucheAktiv = false
    @State private var profilOffen = false
    @State private var kameraOffen = false

    var body: some View {
        NavigationStack {
            Group {
                if let ich = Raum.shared.ich {
                    ChatsListe(ich: ich, offen: $offen, profilOffen: $profilOffen, kameraOffen: $kameraOffen)
                        .navigationDestination(isPresented: $offen) {
                            Unterhaltung(ich: ich, partner: ich.partner, sucheAktiv: $sucheAktiv, profilOffen: $profilOffen)
                        }
                } else {
                    ContentUnavailableView("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .navigationTitle("Chats")
        }
        // Search mode ends with the conversation; not in its onDisappear, which also fires for covers.
        .onChange(of: offen) { _, auf in if !auf { sucheAktiv = false } }
        .sheet(isPresented: $profilOffen) {
            if let ich = Raum.shared.ich { PartnerProfilView(person: ich.partner) }
        }
        .fullScreenCover(isPresented: $kameraOffen) {
            if let ich = Raum.shared.ich {
                SnapKameraFluss(ich: ich, antwortAuf: nil) { kameraOffen = false }
            }
        }
        // Profile → "Kamera": close the profile first; a cover can't present while a sheet is closing.
        .onChange(of: AppNavigation.shared.kameraOeffnen, initial: true) { _, an in
            guard an else { return }
            AppNavigation.shared.kameraOeffnen = false
            let warten = profilOffen
            profilOffen = false
            Task {
                if warten { try? await Task.sleep(for: .milliseconds(500)) }
                kameraOffen = true
            }
        }
        // Profile → "Im Chat suchen": close the profile, open the conversation in search mode.
        .onChange(of: AppNavigation.shared.chatSuche, initial: true) { _, an in
            guard an else { return }
            AppNavigation.shared.chatSuche = false
            profilOffen = false
            sucheAktiv = true
            offen = true
        }
    }
}

// MARK: - Chats screen

private struct ChatsListe: View {
    let ich: Person
    @Binding var offen: Bool
    @Binding var profilOffen: Bool
    @Binding var kameraOffen: Bool

    var body: some View {
        List {
            ChatPartnerKarte(ich: ich, partner: ich.partner, modell: ChatModell.shared) {
                ChatHaptik.leicht()
                offen = true
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button { kameraOffen = true } label: { Label("Snap", systemImage: "camera.fill") }
                    .tint(Color.loveaRose)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { profilOffen = true } label: { Label("Profil", systemImage: "person.crop.circle") }
                    .tint(.gray)
            }
            .contextMenu {
                Button("Chat öffnen", systemImage: "bubble.left.and.bubble.right") { offen = true }
                Button("Snap senden", systemImage: "camera") { kameraOffen = true }
                Button("Profil ansehen", systemImage: "person.crop.circle") { profilOffen = true }
                Button("Im Chat suchen", systemImage: "magnifyingglass") { AppNavigation.shared.chatSuche = true }
            }
            // Block 27: "Heute vor …", Zeitkapseln, Briefbox – nur wenn vorhanden (Spec 2), sonst nichts.
            HeuteVorCard(onOeffnen: { offen = true })
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            KapselnUndBriefeSektion(modell: ChatModell.shared, ich: ich, offen: $offen)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top, spacing: 0) { SyncStatusZeile() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { kameraOffen = true } label: { Image(systemName: "camera") }
                    .accessibilityLabel("Snap aufnehmen")
            }
        }
    }
}

/// Chat-Tab-Startbildschirm (Z-19.2, Spec 2): große Partner-Karte statt leerer Liste, Antippen
/// öffnet die Unterhaltung. Der Spiele-Knopf ist ein eigener Button, nicht in `oeffnen` verschachtelt.
private struct ChatPartnerKarte: View {
    let ich: Person
    let partner: Person
    let modell: ChatModell
    let oeffnen: () -> Void
    @State private var spieleOffen = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: oeffnen) {
                TimelineView(.everyMinute) { _ in kopfUndVorschau }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Chat öffnen")

            spieleKnopf
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $spieleOffen) { SpieleStarter() }
    }

    /// Figur, Name, Streak, Status und die letzte-Nachricht-Vorschau – getrennt vom `Button` und
    /// vom `spieleKnopf`, damit der Compiler nicht einen einzigen, tief verschachtelten Ausdruck
    /// mit mehreren Ternaries auf einmal prüfen muss (Regel aus common.md, Runde-1-CI-Fehler).
    private var kopfUndVorschau: some View {
        let anzeige = FigurenModell.shared.anzeige(partner)
        let vorschau = vorschauZeile(anzeige.haupt)
        return VStack(alignment: .leading, spacing: 14) {
            figurUndName(anzeige.haupt)
            HStack(spacing: 5) {
                Image(systemName: vorschau.symbol)
                    .foregroundStyle(vorschau.neu ? Color.person(partner) : Color.secondary)
                Text(vorschau.text).lineLimit(1)
            }
            .font(.subheadline.weight(vorschau.neu ? .semibold : .regular))
            .foregroundStyle(vorschau.neu ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.secondary)
        }
    }

    private func figurUndName(_ zustand: FigurZustand) -> some View {
        HStack(spacing: 14) {
            FigurView(FigurenModell.shared.aussehen(partner), zustand: zustand, groesse: 76)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(partner.name).font(.title3.bold()).foregroundStyle(ChatFarbe.farbe(partner))
                    ChatStreakAnzeige(modell: modell)
                }
                Text(statusText(zustand))
                    .font(.subheadline)
                    .foregroundStyle(zustand == .tippt ? Color.person(partner) : Color.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var spieleKnopf: some View {
        Button { spieleOffen = true } label: {
            Label("Spiele", systemImage: "gamecontroller.fill")
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(Color.loveaRose)
    }

    private func vorschauZeile(_ zustand: FigurZustand) -> ChatVorschau.Zeile {
        let nachrichten = modell.nachrichten.filter { ChatModell.sichtbar($0) }
        return ChatVorschau.zeile(
            nachrichten: nachrichten, ich: ich,
            gelesenVonPartner: modell.gelesenBis[partner], gelesenVonMir: modell.gelesenBis[ich],
            partnerTippt: zustand == .tippt
        )
    }

    /// Wie `ChatPartnerKopf.statusText` (Konversations-Header), hier dupliziert – ein eigenes,
    /// kleines Property statt der geteilten Header-Datei, die Block 26 parallel anfasst.
    private func statusText(_ zustand: FigurZustand) -> String {
        if zustand == .tippt { return "tippt …" }
        if Raum.shared.partnerDa { return "online" }
        guard let zuletzt = modell.letzteAktivitaet[partner] else { return "offline" }
        return "zuletzt \(zuletzt.formatted(.relative(presentation: .named)))"
    }
}

// MARK: - Conversation

private struct Unterhaltung: View {
    let ich: Person
    let partner: Person
    @Binding var sucheAktiv: Bool
    @Binding var profilOffen: Bool

    private let modell = ChatModell.shared
    @State private var zielID: String?
    @State private var antwortAuf: ChatModell.Nachricht?
    @State private var bearbeitenNachricht: ChatModell.Nachricht?
    @State private var bearbeitenText = ""
    @State private var loeschenIDs: [String] = []
    @State private var sichtbar = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            NachrichtenListe(
                modell: modell, ich: ich, zielID: $zielID,
                onAntworten: { ChatHaptik.leicht(); antwortAuf = $0 },
                onBearbeiten: { bearbeitenNachricht = $0; bearbeitenText = $0.text ?? "" },
                onLoeschen: { loeschenIDs = $0 }
            )
            VStack(spacing: 0) {
                PartnerFigurLeiste(partner: partner)
                ChatEingabeleiste(ich: ich, antwortAuf: $antwortAuf)
            }
            .tastaturWischen()
        }
        .background { ChatHintergrundAnsicht(ich: ich) }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if sucheAktiv {
                    ChatSuchleiste(modell: modell, onSpringeZu: { zielID = $0 }) {
                        withAnimation { sucheAktiv = false }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                ChatAngeheftetLeiste(modell: modell) { zielID = $0 }
                SyncStatusZeile()
            }
            .tastaturWischen()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ChatPartnerKopf(partner: partner, modell: modell) { profilOffen = true }
                    .tastaturWischen()
            }
            if modell.streak.tage > 0 {
                ToolbarItem(placement: .topBarTrailing) { ChatStreakAnzeige(modell: modell) }
            }
        }
        .alert("Nachricht bearbeiten", isPresented: Binding(get: { bearbeitenNachricht != nil }, set: { if !$0 { bearbeitenNachricht = nil } })) {
            TextField("Text", text: $bearbeitenText)
            Button("Speichern") {
                if let id = bearbeitenNachricht?.id { modell.bearbeiten(id, text: bearbeitenText) }
                bearbeitenNachricht = nil
            }
            Button("Abbrechen", role: .cancel) { bearbeitenNachricht = nil }
        }
        .confirmationDialog(
            loeschenIDs.count > 1 ? "\(loeschenIDs.count) Nachrichten für beide löschen?" : "Nachricht für beide löschen?",
            isPresented: Binding(get: { !loeschenIDs.isEmpty }, set: { if !$0 { loeschenIDs = [] } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                for id in loeschenIDs { modell.loeschen(id) }
                loeschenIDs = []
            }
            Button("Abbrechen", role: .cancel) { loeschenIDs = [] }
        }
        // Read receipts and the "im Chat" figure belong to the open conversation, not to the list.
        .onAppear {
            sichtbar = true
            leseBestaetigen()
            FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
        }
        .onDisappear { sichtbar = false }
        .onChange(of: scenePhase) { _, _ in leseBestaetigen() }
        .onChange(of: modell.nachrichten.count) { _, _ in
            leseBestaetigen()
            // Only a fresh partner message while looking at it, not a reconnect backlog or own send.
            if sichtbar, scenePhase == .active, let letzte = modell.nachrichten.last, letzte.von == partner,
               Date().timeIntervalSince(letzte.zeit) < 10 {
                ChatHaptik.weich()
            }
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

/// Search mode (Block 18): replaces the old always-visible search field. Newest hit first, arrows
/// step through older/newer hits, the list scrolls there and highlights the bubble.
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
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())

            Button { springe(-1) } label: { Image(systemName: "chevron.up").frame(width: 36, height: 44) }
                .disabled(treffer.count < 2)
                .accessibilityLabel("Älterer Treffer")
            Button { springe(1) } label: { Image(systemName: "chevron.down").frame(width: 36, height: 44) }
                .disabled(treffer.count < 2)
                .accessibilityLabel("Neuerer Treffer")
            Button("Fertig") { onFertig() }
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .onChange(of: text) { _, _ in suchen() }
        // Focus set right away is dropped while the profile sheet is still closing or the push runs.
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            fokus = true
        }
    }

    private func suchen() {
        let begriff = text.trimmingCharacters(in: .whitespaces)
        treffer = begriff.isEmpty ? [] : modell.nachrichten
            // Z-27.2: eine verschlossene Zeitkapsel darf nicht über die Suche verraten werden.
            .filter { !$0.geloescht && !ChatModell.verschlossen($0) && ($0.text ?? "").localizedCaseInsensitiveContains(begriff) }
            .map(\.id)
        index = max(treffer.count - 1, 0)
        if let id = treffer.last { onSpringeZu(id) }
    }

    private func springe(_ richtung: Int) {
        guard !treffer.isEmpty else { return }
        index = (index + richtung + treffer.count) % treffer.count
        ChatHaptik.auswahl()
        onSpringeZu(treffer[index])
    }
}

/// Message history (Z-4.2): date separators, time groups, photo stacks, anchored to the bottom.
/// Shows the newest `anzahl` messages; pulling down at the top (or the button there) loads older ones.
private struct NachrichtenListe: View {
    let modell: ChatModell
    let ich: Person
    @Binding var zielID: String?
    let onAntworten: (ChatModell.Nachricht) -> Void
    let onBearbeiten: (ChatModell.Nachricht) -> Void
    let onLoeschen: ([String]) -> Void

    @State private var fenster = ChatListenFenster()
    @State private var hervorID: String?
    private var anzahl: Int { fenster.anzahl }

    var body: some View {
        let alle = modell.nachrichten
        let sichtbar = Array(alle.suffix(anzahl))
        let vorFenster = alle.count > sichtbar.count ? alle[alle.count - sichtbar.count - 1] : nil
        let gruppen = ChatStapel.gruppieren(sichtbar)
        // Once per render, not one backwards scan per built row (Z-16.2, 10,000 messages).
        let letzteEigeneID = alle.last(where: { $0.von == ich })?.id
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if alle.count > sichtbar.count {
                        Button { fenster.mehr(modell) } label: {
                            Label("Ältere Nachrichten", systemImage: "arrow.down")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(gruppen.enumerated()), id: \.element.id) { eintrag in
                        let gruppe = eintrag.element
                        let erste = gruppe.nachrichten[0]
                        let vorher = eintrag.offset > 0 ? gruppen[eintrag.offset - 1].letzte : vorFenster
                        if let spiel = erste.spiel {
                            if SpieleModell.shared.sichtbar(spiel.id) {
                                SpielKarte(nachricht: erste).id(gruppe.id)
                            }
                        } else {
                            ChatNachrichtRow(
                                nachricht: erste, ich: ich, stapel: gruppe.nachrichten,
                                zeigeDatumstrenner: vorher.map { !Calendar.berlin.isDate(erste.zeit, inSameDayAs: $0.zeit) } ?? true,
                                zeigeZeitstempel: vorher.map { erste.zeit.timeIntervalSince($0.zeit) > 900 } ?? true,
                                zustellStatus: gruppe.nachrichten.contains { $0.id == letzteEigeneID } ? zustellStatus(gruppe.letzte) : nil,
                                onAntworten: onAntworten, onBearbeiten: onBearbeiten, onLoeschen: onLoeschen,
                                onSpringeZu: { zielID = $0 }
                            )
                            .background(hervorID == gruppe.id ? Color.loveaRose.opacity(0.18) : Color.clear)
                            .id(gruppe.id)
                        }
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
                withAnimation(.snappy) { proxy.scrollTo(ziel, anchor: .bottom) }
            }
        }
    }

    /// Target may sit inside a stack (keyed by its first message) or above the loaded window.
    private func springen(zu id: String, proxy: ScrollViewProxy) {
        let alle = modell.nachrichten
        guard let index = alle.firstIndex(where: { $0.id == id }) else { return }
        if index < alle.count - anzahl { fenster.anzahl = alle.count - index + 30 }
        Task {
            try? await Task.sleep(for: .milliseconds(60)) // let the widened window lay out first
            let ziel = gruppeID(fuer: id)
            withAnimation { proxy.scrollTo(ziel, anchor: .center) }
            hervorID = ziel
            try? await Task.sleep(for: .seconds(1.4))
            if hervorID == ziel { withAnimation { hervorID = nil } }
        }
    }

    private func gruppeID(fuer id: String) -> String {
        ChatStapel.gruppieren(Array(modell.nachrichten.suffix(anzahl))).first { gruppe in gruppe.nachrichten.contains { $0.id == id } }?.id ?? id
    }

    /// "Zugestellt"/"Gelesen HH:mm" unter der letzten eigenen Nachricht (Spec 5.1).
    private func zustellStatus(_ nachricht: ChatModell.Nachricht) -> String {
        if let gelesen = modell.gelesenBis[ich.partner], gelesen >= nachricht.zeit {
            return "Gelesen " + gelesen.formatted(date: .omitted, time: .shortened)
        }
        return "Zugestellt"
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
        ChatHaptik.leicht()
    }
}
