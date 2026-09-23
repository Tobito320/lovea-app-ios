import SwiftUI

/// Placeholder for the partner profile, opened from the chat header (Z-4.4).
/// Block 15 replaces this with the real `ProfileView(person:session:)` for the partner.
struct PartnerProfilKarte: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                FigurView(FigurenModell.shared.aussehen(person), zustand: FigurenModell.shared.anzeige(person).haupt, groesse: 120)
                Text(person.name).font(.title2.bold())
                Text(FigurenModell.shared.anzeige(person).haupt.titel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
