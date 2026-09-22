import SwiftUI

@main
struct WirApp: App {
    var body: some Scene {
        WindowGroup {
            Text(AppConfiguration.title)
        }
    }
}

enum AppConfiguration {
    static let title = "Wir"
}
