import SwiftUI

@main
struct LoveaApp: App {
    @StateObject private var session = UserSelectionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let person = session.selectedPerson {
                    AppRootView(person: person) {
                        session.reset()
                    }
                } else {
                    PersonSelectionView { person in
                        session.select(person)
                    }
                }
            }
        }
    }
}
