import Observation
import SwiftUI

private enum AppTab: String, Hashable {
    case home, chat, drawing, health, profile
    case heute, koerper, training, verlauf, zurueck
}

/// Deep links across tabs. The banner "… zeichnet gerade an ‚X' – zuschauen?" sets
/// `geteilteZeichnung`; `DrawingView` pushes that drawing and clears it again.
@MainActor
@Observable
final class AppNavigation {
    static let shared = AppNavigation()
    var geteilteZeichnung: String?
    /// Profile → "Im Chat suchen": ChatTab opens the conversation with search active and clears it.
    var chatSuche = false
    /// Switch tab from anywhere ("home", "chat", "drawing", "health", "profile"); AppRootView clears it.
    /// "training", "koerper", "verlauf" open Health and that page (`healthSeite`).
    var tabWunsch: String?
    /// Page inside Health to open ("training", "koerper", "verlauf"); the Health tab clears it.
    var healthSeite: String?
    /// Live Activity, Mahlzeiten-Zeile angetippt: `Mahlzeit.rawValue` aus `lovea://essen?mahlzeit=…`.
    /// `ErnaehrungView` öffnet direkt das Hinzufügen-Blatt dafür und löscht den Wunsch wieder.
    var essenMahlzeitWunsch: String?
    /// Profile → "Kamera": ChatTab opens the snap camera and clears it.
    var kameraOeffnen = false
    /// Profile → "Chat": the Chat tab skips its list and opens the conversation.
    var gespraechOeffnen = false
    /// Z-32.1: message the chat tab scrolls to and highlights (notification tap, "Heute vor …").
    /// Stays set until that message has arrived; the conversation clears it.
    var chatZiel: String?
    /// 25.09.: Kuss/Anstupsen/Herz-Push angetippt -> die Unterhaltung öffnet das Partnerprofil.
    var partnerProfilOeffnen = false
    /// Contexts on screen right now, for screenshot/recording notices (`ScreenshotKontext`).
    var bildschirm: [ScreenshotKontext] = []
    private init() {}

    /// Notification tap: chat pushes carry `art` (op kind) and `nachrichtId` (Z-32.1).
    /// 25.09.: Kuss/Anstupsen/Herz (`art == "geste"`) öffnen statt der Nachricht das Partnerprofil.
    func mitteilungGeoeffnet(nachrichtId: String?, art: String?) {
        if art == "geste" {
            tabWunsch = "chat"
            partnerProfilOeffnen = true
            return
        }
        let chat = nachrichtId != nil || art.map { $0.hasPrefix("nachricht.") || $0.hasPrefix("snap.") } == true
        guard chat else { return }
        chatZiel = nachrichtId
        tabWunsch = "chat"
    }
}

struct AppRootView: View {
    @ObservedObject var session: PersonSession
    let person: Person
    @SceneStorage("app.selectedTab") private var selectedTab: AppTab = .drawing

    init(session: PersonSession, person: Person) {
        self.session = session
        self.person = person
        StartProtokoll.marke("approotview.init")
    }

    var body: some View {
        return hauptLeiste
        .onAppear {
            StartProtokoll.marke("approotview.onAppear")
            // Alte Werte aus der früheren Health-Leiste (SceneStorage): jetzt ein Health-Tab.
            if [.heute, .koerper, .training, .verlauf, .zurueck].contains(selectedTab) { selectedTab = .health }
        }
        .onChange(of: selectedTab, initial: true) { _, tab in StartProtokoll.marke("tab.\(tab.rawValue)") }
        .spieleBuehne()
        // Screenshot/recording notices for whatever chat context is on screen (`ScreenshotKontext`).
        .modifier(ChatAufnahmeHinweise())
        .onChange(of: AppNavigation.shared.tabWunsch) { _, wunsch in
            if wunsch == "gym" { // Live Activity: zurück ins laufende Training
                AppNavigation.shared.tabWunsch = nil
                AppNavigation.shared.healthSeite = "gym"
                selectedTab = .health
                return
            }
            if wunsch == "essen" { // Live Activity: zurück ins Ernährungstagebuch
                AppNavigation.shared.tabWunsch = nil
                AppNavigation.shared.healthSeite = "ernaehrung"
                selectedTab = .health
                return
            }
            guard let wunsch, let tab = AppTab(rawValue: wunsch) else { return }
            AppNavigation.shared.tabWunsch = nil
            if [.heute, .koerper, .training, .verlauf].contains(tab) {
                if tab != .heute { AppNavigation.shared.healthSeite = wunsch }
                selectedTab = .health
            } else if tab != .zurueck {
                // R6: animiert wie bei Snapchat/Instagram, auch wenn der Wunsch von einem
                // Deep-Link statt der Wisch-Geste kommt — stört dort nicht.
                withAnimation(Feder.weich) { selectedTab = tab }
            }
        }
        // audit-chat #2: voice round (app-wide voice playback outside the conversation) and the
        // Z-7.3 in-app banner (partner online / drawing invite / Anstupsen & Kuss) both dock to the
        // top — stacked in one overlay so a banner pushes the player down instead of covering it.
        // Those two are meant to float briefly over content (capsules with their own top padding).
        .overlay(alignment: .top) { topOverlay }
        // R7 (Review): die Gym-Leiste ist dagegen dauerhaft/oft sichtbar und soll Navigationstitel
        // (Home, Chat, …) nicht verdecken — darum `safeAreaInset` statt `overlay`, wie
        // `SyncStatusZeile` in `ChatTab.swift`: verdrängt den Inhalt, statt ihn zu überdecken, und
        // bleibt leer (keine Höhe), wenn `GymLeisteView` gerade nichts zeigt.
        .safeAreaInset(edge: .top, spacing: 0) { GymLeisteView() }
        // Eingeklappt (seitlich weggewischt): kleiner Knopf am Rand, mittig in der Höhe.
        .overlay(alignment: .center) { GymLeisteKnopf() }
    }
}


private extension AppRootView {
    var spieleBilanz: [(spiel: String, ahmed: Int, annika: Int)] {
        SpielArt.allCases.compactMap { art in
            guard let p = SpieleModell.shared.bilanz[art] else { return nil }
            return (art.titel, p.ahmed, p.annika)
        }
    }

    var hauptLeiste: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView(person: person).onAppear { StartProtokoll.marke("tab.home.onAppear") }
            }
            Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: AppTab.chat) {
                ChatTab().onAppear { StartProtokoll.marke("tab.chat.onAppear") }
            }
            .badge(ChatModell.shared.ungelesen(fuer: person))
            Tab("Zeichnen", systemImage: "paintbrush.pointed", value: AppTab.drawing) {
                DrawingView(person: person).onAppear { StartProtokoll.marke("tab.zeichnen.onAppear") }
            }
            Tab("Health", systemImage: "heart.text.square", value: AppTab.health) {
                HeuteView().onAppear { StartProtokoll.marke("tab.health.onAppear") }
            }
            Tab("Profil", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView(person: person, session: session, bilanz: spieleBilanz)
                    .onAppear { StartProtokoll.marke("tab.profil.onAppear") }
            }
        }
        .leiste()
    }

    var topOverlay: some View {
        VStack(spacing: 0) {
            SprachMiniPlayer()
            InAppBannerView(aufZeichnungGetippt: { id in
                AppNavigation.shared.geteilteZeichnung = id
                selectedTab = .drawing
            })
        }
    }
}

private extension View {
    /// Spec 2.1: die Leiste bleibt und schrumpft beim Scrollen.
    func leiste() -> some View {
        tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
            .tint(Color.loveaRose)
    }
}
