import SwiftUI

struct ProfileView: View {
    let person: LoveaPerson
    let onChangePerson: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.secondary)

                Text(person.rawValue)
                    .font(.largeTitle.bold())

                VStack(spacing: 0) {
                    LabeledContent("Partner", value: person.partner.rawValue)
                        .frame(minHeight: 52)
                    Divider()
                    Button("Person wechseln", action: onChangePerson)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Profil")
        }
    }
}
