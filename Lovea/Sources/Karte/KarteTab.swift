import SwiftUI

struct KarteTab: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Karte", systemImage: "map")
                .navigationTitle("Karte")
        }
    }
}
