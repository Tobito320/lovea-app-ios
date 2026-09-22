import SwiftUI

private enum AppTab: Hashable {
    case home
    case drawing
    case profile
}

struct AppRootView: View {
    let person: LoveaPerson
    let onChangePerson: () -> Void
    @State private var selectedTab: AppTab = .drawing

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(person: person)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            DrawingView(person: person)
                .tabItem { Label("Zeichnen", systemImage: "paintbrush.pointed") }
                .tag(AppTab.drawing)

            ProfileView(person: person, onChangePerson: onChangePerson)
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(.blue)
    }
}
