import Observation
import SwiftUI

private enum AppTab: String, Hashable {
    case home, chat, drawing, map, profile
}

/// Deep links across tabs. The banner "… zeichnet gerade an ‚X' – zuschauen?" sets
/// `geteilteZeichnung`; `DrawingView` pushes that drawing and clears it again.
@MainActor
@Observable
final class AppNavigation {
    static let shared = AppNavigation()
    var geteilteZeichnung: String?
    private init() {}
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
            Tab("Zeichnen", systemImage: "paintbrush.pointed", value: AppTab.drawing) {
                DrawingView(person: person)
            }
            Tab("Karte", systemImage: "map", value: AppTab.map) {
                KarteTab()
            }
            Tab("Profil", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView(person: person, session: session, bilanz: spieleBilanz)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.loveaRose)
        .spieleBuehne()
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
