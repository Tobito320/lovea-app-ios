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
    var tabWunsch: String?
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

    @State private var letzterHauptTab: AppTab = .drawing

    private var imHealth: Bool { [.heute, .koerper, .training, .verlauf].contains(selectedTab) }

    var body: some View {
        Group {
            if imHealth { healthLeiste } else { hauptLeiste }
        }
        .animation(.spring(duration: 0.4), value: imHealth)
        .onAppear {
            // Alter Wert "health" aus SceneStorage: direkt in den Health-Modus.
            if selectedTab == .health { selectedTab = .heute } else if !imHealth { letzterHauptTab = selectedTab }
        }
        .onChange(of: selectedTab) { _, tab in
            switch tab {
            case .health: selectedTab = .heute
            case .zurueck: selectedTab = letzterHauptTab
            case .home, .chat, .drawing, .profile: letzterHauptTab = tab
            case .heute, .koerper, .training, .verlauf: break
            }
        }
        .spieleBuehne()
        // Screenshot/recording notices for whatever chat context is on screen (`ScreenshotKontext`).
        .modifier(ChatAufnahmeHinweise())
        .onChange(of: AppNavigation.shared.tabWunsch) { _, wunsch in
            guard let wunsch, let tab = AppTab(rawValue: wunsch) else { return }
            selectedTab = tab
            AppNavigation.shared.tabWunsch = nil
        }
        // audit-chat #2: voice round (app-wide voice playback outside the conversation) and the
        // Z-7.3 in-app banner (partner online / drawing invite / Anstupsen & Kuss) both dock to the
        // top — stacked in one overlay so a banner pushes the player down instead of covering it.
        .overlay(alignment: .top) { topOverlay }
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
                HomeView(person: person)
            }
            Tab("Chat", systemImage: "bubble.left.and.bubble.right", value: AppTab.chat) {
                ChatTab()
            }
            .badge(ChatModell.shared.ungelesen(fuer: person))
            Tab("Zeichnen", systemImage: "paintbrush.pointed", value: AppTab.drawing) {
                DrawingView(person: person)
            }
            Tab("Health", systemImage: "heart.text.square", value: AppTab.health) {
                HealthTab()
            }
            Tab("Profil", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView(person: person, session: session, bilanz: spieleBilanz)
            }
        }
        .leiste()
    }

    var healthLeiste: some View {
        TabView(selection: $selectedTab) {
            Tab("Heute", systemImage: "sun.max", value: AppTab.heute) { HeuteView() }
            Tab("Körper", systemImage: "figure.stand", value: AppTab.koerper) { KoerperView() }
            Tab("Training", systemImage: "dumbbell", value: AppTab.training) { HealthTab() }
            Tab("Verlauf", systemImage: "chart.bar", value: AppTab.verlauf) { VerlaufView() }
            // ponytail: role .search gibt iOS 26 den abgesetzten runden Knopf, hier als "Zurück" benutzt.
            Tab("Zurück", systemImage: "chevron.left", value: AppTab.zurueck, role: .search) { Color.clear }
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
    /// Gemeinsame Optik beider Leisten. Spec 2.1: die Leiste bleibt und schrumpft beim Scrollen.
    func leiste() -> some View {
        tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
            .tint(Color.loveaRose)
    }
}
