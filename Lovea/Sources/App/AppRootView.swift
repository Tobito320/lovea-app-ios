import Observation
import SwiftUI

private enum AppTab: String, Hashable {
    case home, chat, drawing, health, profile
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
    /// Contexts on screen right now, for screenshot/recording notices (`ScreenshotKontext`).
    var bildschirm: [ScreenshotKontext] = []
    private init() {}

    /// Notification tap: chat pushes carry `art` (op kind) and `nachrichtId` (Z-32.1).
    func mitteilungGeoeffnet(nachrichtId: String?, art: String?) {
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

    var body: some View {
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
        .tabViewStyle(.sidebarAdaptable)
        // Spec 2.1: the bar stays, and shrinks while scrolling (the chat is a tab, not a pushed screen).
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.loveaRose)
        .spieleBuehne()
        // Screenshot/recording notices for whatever chat context is on screen (`ScreenshotKontext`).
        .modifier(ChatAufnahmeHinweise())
        .onChange(of: AppNavigation.shared.tabWunsch) { _, wunsch in
            guard let wunsch, let tab = AppTab(rawValue: wunsch) else { return }
            selectedTab = tab
            AppNavigation.shared.tabWunsch = nil
        }
        // Voice round: app-wide voice playback outside the conversation. ponytail: shares the top
        // with in-app banners (a banner briefly covers it), push content down if that bothers.
        .overlay(alignment: .top) { SprachMiniPlayer() }
        // Z-7.3: partner online / drawing invite / Anstupsen & Kuss, glass capsule on top.
        .overlay(alignment: .top) {
            InAppBannerView(aufZeichnungGetippt: { id in
                AppNavigation.shared.geteilteZeichnung = id
                selectedTab = .drawing
            })
        }
    }
}


private extension AppRootView {
    var spieleBilanz: [(spiel: String, ahmed: Int, annika: Int)] {
        SpielArt.allCases.compactMap { art in
            guard let p = SpieleModell.shared.bilanz[art] else { return nil }
            return (art.titel, p.ahmed, p.annika)
        }
    }
}
