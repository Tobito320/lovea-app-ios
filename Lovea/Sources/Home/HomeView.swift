import SwiftUI

struct HomeView: View {
    let person: Person

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ahmed & Annika")
                    .font(.system(size: 44, weight: .bold))
                Text("Heute gehört die Fläche euch.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Divider()
                    .padding(.top, 12)
                Text("Du bist als \(person.name) drin.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .navigationTitle("Home")
        }
    }
}
