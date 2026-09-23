import SwiftUI

struct ProfileView: View {
    let person: Person
    @ObservedObject var session: PersonSession
    @AppStorage("profile.performanceHUD") private var showsHUD = false
    @State private var zeigtEntwickler = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Color.person(person))

                Text(person.name)
                    .font(.largeTitle.bold())
                    .onTapGesture(count: 7) { zeigtEntwickler = true }

                VStack(spacing: 0) {
                    LabeledContent("Partner", value: person.partner.name)
                        .frame(minHeight: 52)
                    Divider()
                    Toggle("Leistungsanzeige", isOn: $showsHUD)
                        .frame(minHeight: 52)

                    if zeigtEntwickler {
                        Divider()
                        Menu {
                            ForEach(Person.allCases, id: \.self) { kandidat in
                                Button(kandidat.name) { session.waehlen(kandidat) }
                            }
                        } label: {
                            Text("Person wechseln")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 52)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Profil")
        }
    }
}
