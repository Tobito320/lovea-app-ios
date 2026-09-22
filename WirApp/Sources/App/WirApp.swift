import SwiftUI

@main
struct WirApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

enum AppConfiguration {
    static let title = "Wir"
}
