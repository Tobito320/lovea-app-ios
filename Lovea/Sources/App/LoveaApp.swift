import SwiftUI

@main
struct LoveaApp: App {
    @StateObject private var session = UserSelectionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-uiTestStudio") {
                    UITestStudio()
                } else if let person = session.selectedPerson {
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

/// UI tests start straight in an empty studio with a throwaway library.
private struct UITestStudio: View {
    @State private var library: ArtworkLibrary
    @State private var artworkID: UUID

    init() {
        let library = ArtworkLibrary(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-\(UUID().uuidString)"))
        _library = State(initialValue: library)
        _artworkID = State(initialValue: library.createArtwork(name: "Test", projectID: nil, format: .square).id)
    }

    var body: some View {
        NavigationStack {
            DrawingStudioView(
                artworkID: artworkID,
                library: library,
                sharing: LoveaSharingService(person: .annika)
            )
        }
    }
}
