import SwiftUI

/// The one conversation (Spec 5). Ties together header, history, partner figure and input.
struct ChatTab: View {
    private let modell = ChatModell.shared
    @State private var suche = ""
    @State private var zielID: String?
    @State private var antwortAuf: ChatModell.Nachricht?
    @State private var bearbeitenNachricht: ChatModell.Nachricht?
    @State private var bearbeitenText = ""
    @State private var loeschenID: String?
    @State private var profilOffen = false
    @State private var chatSichtbar = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if let ich = Raum.shared.ich {
                    inhalt(ich: ich, partner: ich.partner)
                } else {
                    ContentUnavailableView("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            }
            // ponytail: the system bar stays (empty, inline) instead of being hidden, so
            // `.searchable` below keeps its normal drawer placement; ChatKopfzeile is the visible header.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func inhalt(ich: Person, partner: Person) -> some View {
        ZStack {
            ChatHintergrundAnsicht(ich: ich) // Z-5.4

            VStack(spacing: 0) {
                ChatKopfzeile(ich: ich, partner: partner, modell: modell, onSpringeZu: { zielID = $0 }, profilOffen: $profilOffen)

                NachrichtenListe(
                    modell: modell, ich: ich, zielID: $zielID,
                    onAntworten: { antwortAuf = $0 },
                    onBearbeiten: { bearbeitenNachricht = $0; bearbeitenText = $0.text ?? "" },
                    onLoeschen: { loeschenID = $0 }
                )
                .searchable(text: $suche, prompt: "Suchen")
                .onSubmit(of: .search) { sucheSpringen() }

                PartnerFigurLeiste(partner: partner)
                ChatEingabeleiste(ich: ich, antwortAuf: $antwortAuf)
            }
        }
        .sheet(isPresented: $profilOffen) { PartnerProfilView(person: partner) }
        .alert("Nachricht bearbeiten", isPresented: Binding(get: { bearbeitenNachricht != nil }, set: { if !$0 { bearbeitenNachricht = nil } })) {
            TextField("Text", text: $bearbeitenText)
            Button("Speichern") {
                if let id = bearbeitenNachricht?.id { modell.bearbeiten(id, text: bearbeitenText) }
                bearbeitenNachricht = nil
            }
            Button("Abbrechen", role: .cancel) { bearbeitenNachricht = nil }
        }
        .confirmationDialog(
            "Nachricht für beide löschen?", isPresented: Binding(get: { loeschenID != nil }, set: { if !$0 { loeschenID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let id = loeschenID { modell.loeschen(id) }
                loeschenID = nil
            }
            Button("Abbrechen", role: .cancel) { loeschenID = nil }
        }
        .onAppear { chatWurdeSichtbar(ich: ich) }
        .onDisappear { chatSichtbar = false }
        .onChange(of: modell.nachrichten.count) { _, _ in leseBestaetigen(ich: ich) }
    }

    private func chatWurdeSichtbar(ich: Person) {
        chatSichtbar = true
        leseBestaetigen(ich: ich)
        FigurenModell.shared.zustandSenden(.init(haupt: .imChat))
    }

    /// Sends `nachricht.gelesen` only while the chat is actually on screen and the app is active,
    /// and only up to the newest partner message — not `Date()`, which a clock-skewed partner
    /// device could read as "not yet sent" and leave the badge stuck forever (Z-4.6).
    private func leseBestaetigen(ich: Person) {
        guard chatSichtbar, scenePhase == .active, modell.ungelesen(fuer: ich) > 0 else { return }
        guard let letztePartnerZeit = modell.nachrichten.last(where: { $0.von != ich })?.zeit else { return }
        modell.gelesenSenden(bis: letztePartnerZeit)
    }

    private func sucheSpringen() {
        guard !suche.isEmpty else { return }
        zielID = modell.nachrichten.first { ($0.text ?? "").localizedCaseInsensitiveContains(suche) }?.id
    }
}

/// Message history (Z-4.2): date separators, time groups, anchored to the bottom, jump-to-id.
private struct NachrichtenListe: View {
    let modell: ChatModell
    let ich: Person
    @Binding var zielID: String?
    let onAntworten: (ChatModell.Nachricht) -> Void
    let onBearbeiten: (ChatModell.Nachricht) -> Void
    let onLoeschen: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(modell.nachrichten.enumerated()), id: \.element.id) { eintrag in
                        if let spiel = eintrag.element.spiel {
                            if SpieleModell.shared.sichtbar(spiel.id) {
                                SpielKarte(nachricht: eintrag.element).id(eintrag.element.id)
                            }
                        } else {
                        ChatNachrichtRow(
                            nachricht: eintrag.element, ich: ich,
                            zeigeDatumstrenner: zeigtDatumstrenner(eintrag.offset),
                            zeigeZeitstempel: zeigtZeitstempel(eintrag.offset),
                            zustellStatus: zustellStatus(eintrag.element),
                            onAntworten: onAntworten, onBearbeiten: onBearbeiten, onLoeschen: onLoeschen,
                            onSpringeZu: { zielID = $0 }
                        )
                        .id(eintrag.element.id)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: zielID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
                zielID = nil
            }
        }
    }

    private func zeigtDatumstrenner(_ index: Int) -> Bool {
        guard index > 0 else { return true }
        return !Calendar.berlin.isDate(modell.nachrichten[index].zeit, inSameDayAs: modell.nachrichten[index - 1].zeit)
    }

    private func zeigtZeitstempel(_ index: Int) -> Bool {
        guard index > 0 else { return true }
        return modell.nachrichten[index].zeit.timeIntervalSince(modell.nachrichten[index - 1].zeit) > 900
    }

    /// "Zugestellt"/"Gelesen HH:mm" unter der letzten eigenen Nachricht (Spec 5.1).
    private func zustellStatus(_ nachricht: ChatModell.Nachricht) -> String? {
        guard nachricht.von == ich, modell.nachrichten.last(where: { $0.von == ich })?.id == nachricht.id else { return nil }
        if let gelesen = modell.gelesenBis[ich.partner], gelesen >= nachricht.zeit {
            return "Gelesen " + gelesen.formatted(date: .omitted, time: .shortened)
        }
        return "Zugestellt"
    }
}
